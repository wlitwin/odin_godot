//gd:extends Area2D
//gd:class Pickup
package barrage_powerups

// ----------------------------------------------------------------------------
// Pickup — a falling powerup (powerups MODULE). An Area2D whose `body_entered` is
// auto-wired to `collect` by @(gd_connect) — the declarative signal hookup (docs:
// signals). On contact with the player it reads its PowerupConfig (typed, same
// package) and applies the effect BY NAME: player buffs via Player.apply_powerup,
// the SlowEnemies debuff via every node in the "enemies" group — both cross-module
// engine calls.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

Pickup :: struct {
	owner: gd.Node2d, // base Area2D

	fall_speed: f32 `gd:"export,range=20:300:5"`,

	config: ^gd.Resource, // assigned by the manager right after instancing
}

pickup_ready :: proc(self: ^Pickup) {
	if self.fall_speed == 0 {self.fall_speed = 90}
}

pickup_physics_process :: proc(self: ^Pickup, delta: f64) {
	pos := gd.node2d_get_position(self.owner)
	pos.y += self.fall_speed * f32(delta)
	if pos.y > 780 {
		gd.node_queue_free(cast(gd.Node)self.owner)
		return
	}
	gd.node2d_set_position(self.owner, pos)
}

@(gd_method)
pickup_set_config :: proc(self: ^Pickup, config: ^gd.Resource) {
	self.config = config
}

// collect — @(gd_connect): scriptgen wires owner.body_entered -> this method at _ready.
@(gd_method, gd_connect = "body_entered")
pickup_collect :: proc(self: ^Pickup, body: ^gd.Node2d) {
	if self.config == nil {
		gd.node_queue_free(cast(gd.Node)self.owner)
		return
	}
	// The config is OUR package's Resource class — read it TYPED (script_of).
	cfg := rt.script_of(cast(gd.Object)self.config, PowerupConfig)
	if cfg == nil {
		gd.node_queue_free(cast(gd.Node)self.owner)
		return
	}

	if Powerup_Kind(cfg.kind) == .SlowEnemies {
		// ONE cross-module engine call into the enemies module; the per-enemy fan-out
		// happens over there on a pure-Odin events.Event — the canonical split
		// (docs/events.md): engine calls cross the module boundary, direct typed
		// calls handle the one-to-many inside it.
		if tree := gd.node_get_tree(cast(gd.Node)self.owner); tree != nil {
			grp := gd.new_string_name_cstring("spawner", true)
			if sp := gd.scene_tree_get_first_node_in_group(tree, grp); sp != nil {
				m := gd.sname("slow_all_enemies")
				factor := f64(cfg.magnitude)
				fv := gd.variant_from(&factor)
				_ = gd.object_call(cast(gd.Object)sp, m, fv)
			}
		}
	} else {
		// Player buff: the colliding body IS the player (only body on this layer).
		m := gd.sname("apply_powerup")
		k := gd.Int(cfg.kind)
		kv := gd.variant_from(&k)
		mag := f64(cfg.magnitude)
		mv := gd.variant_from(&mag)
		_ = gd.object_call(cast(gd.Object)body, m, kv, mv)
	}
	gd.node_queue_free(cast(gd.Node)self.owner)
}
