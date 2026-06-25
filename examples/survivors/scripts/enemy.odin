//gd:extends Area2D
//gd:class Enemy
//gd:signal died()
package survivors_scripts

// ----------------------------------------------------------------------------
// Enemy — an Area2D that reads its stats from an EnemyConfig resource, chases the player,
// takes damage from weapons, and damages the player on contact. On death it drops an XP gem
// and banks a kill.
//
// The densest feature showcase in the project:
//   * @export of a CUSTOM RESOURCE  — `config` is an EnemyConfig picker slot (the spawner can
//                                      also reassign it TYPED before _ready to vary the type).
//   * @export of a PackedScene       — `gem_scene` (xp_gem.tscn) dropped on death.
//   * typed cross-script READ         — rt.script_of(config, EnemyConfig).
//   * runtime restyling               — scales the body + recolors the Polygon2D from config.
//   * groups                          — joins "enemies" for targeting/area-damage queries.
//   * lifecycle _physics_process      — chases the player each physics tick.
//   * custom @(gd_method) take_damage — weapons call this TYPED.
//   * @(gd_connect) signal wiring     — body_entered -> on_body (contact damage).
//   * typed cross-script WRITE        — calls the player's take_damage; sets the gem's value.
//   * script-declared signal `died()`.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

Enemy :: struct {
	owner:     gd.Area2d,
	config:    ^gd.Resource `gd:"export,resource=EnemyConfig"`, // an EnemyConfig .tres slot
	gem_scene: ^gd.Resource `gd:"export,resource=PackedScene"`, // xp_gem.tscn

	// runtime state, copied from `config` on _ready:
	hp:       int,
	speed:    f32,
	damage:   int,
	xp_value: int,
	points:   int,
	dead:     bool,
}

enemy_ready :: proc(self: ^Enemy) {
	// Defaults if no config was assigned.
	self.hp = 3
	self.speed = 70
	self.damage = 8
	self.xp_value = 1
	self.points = 1

	cfg := rt.script_of(cast(gd.Object)self.config, EnemyConfig)
	if cfg != nil {
		self.hp = int(cfg.hp)
		self.speed = cfg.speed
		self.damage = int(cfg.damage)
		self.xp_value = int(cfg.xp_value)
		self.points = int(cfg.points)
		// Restyle the body to this config: scale to its radius (base polygon ~13px) + recolor.
		s := cfg.radius / 13.0
		if s <= 0 {s = 1}
		gd.node2d_set_scale(self.owner, gd.Vector2{s, s})
		body := gd.get_node(self.owner, "Body")
		if body != nil {
			gd.polygon2d_set_color(cast(gd.Polygon2d)body, cfg.color)
		}
	}

	gd.add_to_group(self.owner, GROUP_ENEMIES)
}

enemy_physics_process :: proc(self: ^Enemy, delta: f64) {
	if self.dead {return}
	player := find_player(self.owner)
	if player == nil {return}
	me := gd.node2d_get_global_position(self.owner)
	target := gd.node2d_get_global_position(player)
	dir := normalized(gd.Vector2{target.x - me.x, target.y - me.y})
	me.x += dir.x * self.speed * f32(delta)
	me.y += dir.y * self.speed * f32(delta)
	gd.node2d_set_global_position(self.owner, me)
}

// take_damage — weapons call this TYPED. On lethal damage it banks a kill, drops an XP gem,
// emits `died`, and frees itself.
@(gd_method)
enemy_take_damage :: proc(self: ^Enemy, amount: int) {
	if self.dead {return}
	self.hp -= amount
	if self.hp <= 0 {
		self.dead = true
		game_state_add_kill(self.points)
		enemy_drop_gem(self)
		enemy_emit_died(self)
		gd.node_queue_free(self.owner)
	}
}

// enemy_drop_gem instantiates gem_scene at our position and seeds its XP value TYPED.
@(private = "file")
enemy_drop_gem :: proc(self: ^Enemy) {
	if self.gem_scene == nil {return}
	arena := find_game(self.owner)
	if arena == nil {return}
	gem := gd.instantiate(cast(gd.Packed_Scene)self.gem_scene)
	if gem == nil {return}
	gs := rt.script_of(gem, XpGem)
	if gs != nil {gs.value = self.xp_value} // typed WRITE before _ready
	// Set the gem's LOCAL position (the arena/Game root sits at the origin, so local == world)
	// and DEFER the tree insertion: a death often happens inside a bullet's area_entered
	// (physics flush), where adding a monitoring Area2D immediately is illegal.
	gd.node2d_set_position(cast(gd.Node2d)gem, gd.node2d_get_global_position(self.owner))
	gd.add_child_deferred(arena, gem)
}

// on_body — wired to our own `body_entered`. When the player's body overlaps us, deal our
// contact damage through a TYPED ^Player reference.
@(gd_method, gd_connect = "body_entered")
enemy_on_body :: proc(self: ^Enemy, body: gd.Node2d) {
	if self.dead {return}
	player := rt.script_of(body, Player)
	if player != nil {
		player_take_damage(player, self.damage)
	}
}
