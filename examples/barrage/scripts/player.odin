//gd:extends CharacterBody2D
//gd:class Player
package barrage_main

// ----------------------------------------------------------------------------
// Player — a CharacterBody2D in the MAIN module. Moves on the ui_* axes, auto-fires
// at the nearest enemy, takes hits from the BulletField (its `player_hit` signal is
// wired to `take_damage` in game.tscn — a SCENE-declared cross-module connection),
// and is the target of powerup effects (`apply_powerup`, called by name from the
// powerups module).
//
// FEATURES: exports w/ range+group, node-group discovery, engine calls INTO an
// isolated module (BulletField), signal target of a scene [connection], invulnerability
// windows, every stat a powerup mutates.
// ----------------------------------------------------------------------------

import gd "godot:godot"

Player :: struct {
	owner: gd.Node2d,

	move_speed: f32 `gd:"export,range=100:600:10,group=Stats"`,
	fire_rate:  f32 `gd:"export,range=1:30:0.5"`, // shots/second (powerups raise it)
	shot_count: int `gd:"export,range=1:9:1"`, // bullets per volley (spread powerup)

	// runtime
	fire_cd:     f32,
	invuln:      f32, // seconds of post-hit / shield invulnerability left
	slow_factor: f32, // enemies module reads nothing here; kept by powerups on enemies
	field:       gd.Object, // BulletField, resolved from its group
}

@(private = "file")
axis_names_ready: bool
@(private = "file")
left_n, right_n, up_n, down_n: gd.String_Name

player_ready :: proc(self: ^Player) {
	if self.move_speed == 0 {self.move_speed = 320}
	if self.fire_rate == 0 {self.fire_rate = 6}
	if self.shot_count == 0 {self.shot_count = 1}
	grp := gd.new_string_name_cstring("player", true)
	gd.node_add_to_group(cast(gd.Node)self.owner, grp, false)
	gd.node2d_set_position(self.owner, gd.Vector2{480, 560})
}

player_physics_process :: proc(self: ^Player, delta: f64) {
	dt := f32(delta)
	if !axis_names_ready {
		axis_names_ready = true
		left_n = gd.new_string_name_cstring("ui_left", true)
		right_n = gd.new_string_name_cstring("ui_right", true)
		up_n = gd.new_string_name_cstring("ui_up", true)
		down_n = gd.new_string_name_cstring("ui_down", true)
	}
	input := gd.singleton_input()
	dir := gd.Vector2 {
		f32(gd.input_get_axis(input, left_n, right_n)),
		f32(gd.input_get_axis(input, up_n, down_n)),
	}
	pos := gd.node2d_get_position(self.owner)
	pos += dir * self.move_speed * dt
	pos.x = clamp(pos.x, 16, 944)
	pos.y = clamp(pos.y, 16, 704)
	gd.node2d_set_position(self.owner, pos)

	if self.invuln > 0 {self.invuln -= dt}

	// Auto-fire at the nearest enemy (bullet-hell convention: you always shoot).
	self.fire_cd -= dt
	if self.fire_cd <= 0 {
		self.fire_cd = 1.0 / self.fire_rate
		player_fire(self, pos)
	}
}

@(private = "file")
player_field :: proc(self: ^Player) -> gd.Object {
	if self.field == nil {
		tree := gd.node_get_tree(cast(gd.Node)self.owner)
		if tree == nil {return nil}
		grp := gd.new_string_name_cstring("bullet_field", true)
		n := gd.scene_tree_get_first_node_in_group(tree, grp)
		self.field = cast(gd.Object)n
	}
	return self.field
}

@(private = "file")
player_fire :: proc(self: ^Player, pos: gd.Vector2) {
	pos := pos
	field := player_field(self)
	if field == nil {return}
	// Aim at the nearest node in the "enemies" group; straight up when the field is clear.
	target := gd.Vector2{pos.x, pos.y - 100}
	tree := gd.node_get_tree(cast(gd.Node)self.owner)
	if tree != nil {
		grp := gd.new_string_name_cstring("enemies", true)
		if e := gd.scene_tree_get_first_node_in_group(tree, grp); e != nil {
			target = gd.node2d_get_position(cast(gd.Node2d)e)
		}
	}
	// Cross-module call by NAME through the engine — the modules contract.
	m := gd.sname("spawn_aimed")
	p := gd.variant_from(&pos)
	t := gd.variant_from(&target)
	n := gd.Int(self.shot_count)
	nv := gd.variant_from(&n)
	spd := f64(520)
	sv := gd.variant_from(&spd)
	spread := f64(0.35)
	spv := gd.variant_from(&spread)
	hostile := gd.Bool(false)
	hv := gd.variant_from(&hostile)
	dmg := gd.Int(1)
	dv := gd.variant_from(&dmg)
	_ = gd.object_call(field, m, p, t, nv, sv, spv, hv, dv)
}

// take_damage — the game.tscn [connection] target for BulletField.player_hit. Also the
// enemies' contact-damage entry. Routes through the GameState autoload so score/hp stay
// in ONE place, whatever module dealt the hit.
@(gd_method)
player_take_damage :: proc(self: ^Player, amount: gd.Int) {
	if self.invuln > 0 {return}
	self.invuln = 1.0
	gs := player_game_state(self)
	if gs == nil {return}
	m := gd.sname("damage_player")
	a := amount
	av := gd.variant_from(&a)
	_ = gd.object_call(gs, m, av)
}

// apply_powerup — called by NAME from the powerups module (see pickup.odin).
// kind: 0=RapidFire 1=Spread 2=Shield (matches PowerupConfig's enum export).
@(gd_method)
player_apply_powerup :: proc(self: ^Player, kind: gd.Int, magnitude: f64) {
	switch int(kind) {
	case 0:
		self.fire_rate = min(self.fire_rate + f32(magnitude), 30)
	case 1:
		self.shot_count = min(self.shot_count + int(magnitude), 9)
	case 2:
		self.invuln = f32(magnitude) // shield: a fat invulnerability window...
		if field := player_field(self); field != nil { // ...plus a screen wipe
			m := gd.sname("clear_hostile")
			_ = gd.object_call(field, m)
		}
	}
}

@(gd_method)
player_get_fire_rate :: proc(self: ^Player) -> f64 {return f64(self.fire_rate)}

@(private = "file")
player_game_state :: proc(self: ^Player) -> gd.Object {
	root := gd.node_get_node(cast(gd.Node)self.owner, gd.new_node_path_cstring("/root/GameState"))
	return cast(gd.Object)root
}
