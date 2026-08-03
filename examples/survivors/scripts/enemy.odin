//gd:extends Area2D
//gd:class Enemy
//gd:group enemies
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
//   * groups                          — "enemies" membership (for targeting/area-damage
//                                       queries) is DECLARED with //gd:group above; the core
//                                       joins it at READY.
//   * lifecycle _physics_process      — chases the player each physics tick AND, while it is
//                                       touching the player, deals its contact damage on a
//                                       rate-limited per-enemy cooldown (continuous bleed —
//                                       standing in a crowd stacks each enemy's DPS and kills).
//   * custom @(gd_method) take_damage — weapons call this TYPED.
//   * typed cross-script WRITE        — calls the player's take_damage; sets the gem's value.
//   * a script-declared signal — the `died` signal FIELD.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

// How long (seconds) between an enemy's contact hits while it overlaps the player. Each enemy
// runs its OWN cooldown, so a crowd lands many independent hits per second — the classic
// survivors "you bleed while touching enemies".
ENEMY_ATTACK_COOLDOWN :: f32(0.6)
// Slack added to the enemy's body radius for the contact test (~the player's body half-extent),
// so a touch registers a little before the centres exactly coincide.
PLAYER_CONTACT_SLACK :: f32(12)

Enemy :: struct {
	owner:     gd.Area2d,
	died:      gd.Signal0, // signal field: emitted on lethal damage (the Game listens)
	config:    ^gd.Resource `gd:"export,resource=EnemyConfig"`, // an EnemyConfig .tres slot
	gem_scene: ^gd.Resource `gd:"export,resource=PackedScene"`, // xp_gem.tscn

	// runtime state, copied from `config` on _ready:
	hp:        int,
	speed:     f32,
	damage:    int,
	xp_value:  int,
	points:    int,
	radius:    f32, // body radius (px) — used for the contact test
	attack_cd: f32, // counts down to this enemy's next contact hit
	dead:      bool,
}

enemy_ready :: proc(self: ^Enemy) {
	// Defaults if no config was assigned.
	self.hp = 3
	self.speed = 70
	self.damage = 8
	self.xp_value = 1
	self.points = 1
	self.radius = 13

	cfg := rt.script_of(cast(gd.Object)self.config, EnemyConfig)
	if cfg != nil {
		self.hp = int(cfg.hp)
		self.speed = cfg.speed
		self.damage = int(cfg.damage)
		self.xp_value = int(cfg.xp_value)
		self.points = int(cfg.points)
		self.radius = cfg.radius
		// Restyle the body to this config: scale to its radius (base polygon ~13px) + recolor.
		s := cfg.radius / 13.0
		if s <= 0 {s = 1}
		gd.node2d_set_scale(self.owner, gd.Vector2{s, s})
		body := gd.get_node(self.owner, "Body")
		if body != nil {
			gd.polygon2d_set_color(cast(gd.Polygon2d)body, cfg.color)
		}
	}
}

enemy_physics_process :: proc(self: ^Enemy, delta: f64) {
	if self.dead {return}
	player := find_player(self.owner)
	if player == nil {return}
	me := gd.node2d_get_global_position(self.owner)
	target := gd.node2d_get_global_position(player)
	dir := gd.normalized(gd.Vector2{target.x - me.x, target.y - me.y})
	me.x += dir.x * self.speed * f32(delta)
	me.y += dir.y * self.speed * f32(delta)
	gd.node2d_set_global_position(self.owner, me)

	// CONTINUOUS contact damage: while we overlap the player, deal our damage on a per-enemy
	// cooldown. This (not a one-shot body_entered) is what makes standing in a crowd lethal —
	// every overlapping enemy runs its own cooldown, so the hits stack into real DPS.
	if self.attack_cd > 0 {self.attack_cd -= f32(delta)}
	dx := target.x - me.x
	dy := target.y - me.y
	reach := self.radius + PLAYER_CONTACT_SLACK
	if dx * dx + dy * dy <= reach * reach && self.attack_cd <= 0 {
		ps := rt.script_of(cast(gd.Object)player, Player)
		if ps != nil {
			player_take_damage(ps, self.damage)
			self.attack_cd = ENEMY_ATTACK_COOLDOWN
		}
	}
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

// enemy_drop_gem spawns gem_scene at our position and seeds its XP value TYPED.
@(private = "file")
enemy_drop_gem :: proc(self: ^Enemy) {
	if self.gem_scene == nil {return}
	arena := find_game(self.owner)
	if arena == nil {return}
	// DEFERRED typed spawn: a death often happens inside a bullet's area_entered (physics
	// flush), where adding a monitoring Area2D immediately is illegal — rt.spawn_as_deferred
	// parents at idle time instead, which also makes the pokes below ready-visible by
	// construction (the gem's _ready runs after this proc returns).
	gs := rt.spawn_as_deferred(arena, cast(gd.Packed_Scene)self.gem_scene, XpGem)
	if gs == nil {return}
	gs.value = self.xp_value // typed WRITE before _ready
	// Set the gem's LOCAL position (the arena/Game root sits at the origin, so local == world).
	gd.node2d_set_position(gs.owner, gd.node2d_get_global_position(self.owner))
}
