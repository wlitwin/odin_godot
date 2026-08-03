//gd:extends Node2D
//gd:class PowerupManager
//gd:group powerup_manager
package barrage_powerups

// ----------------------------------------------------------------------------
// PowerupManager — spawns pickups (powerups MODULE). Holds the drop TABLE as a typed
// array of PowerupConfig resources (the `array=` export: the Inspector edits a real
// list of .tres slots) and spawns pickup.tscn on request — `spawn_drop` is called by
// name (gd.vcall) from the enemies module. Pickup is THIS module's class, so the
// spawn itself is typed: rt.spawn_as_deferred hands back a ^Pickup and the config is
// poked as a plain field. Drops cycle round-robin so the suite can predict what falls.
// Group membership ("powerup_manager") is declared by the `//gd:group` marker up top.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

PowerupManager :: struct {
	owner: gd.Node2d,

	pickup_scene: ^gd.Resource `gd:"export,resource=PackedScene"`,
	// The drop table: a TYPED-ARRAY export (`array=`) — one Inspector-editable list of
	// PowerupConfig .tres slots, assigned in game.tscn. (Element type is Resource: the
	// engine validates elements against native classes; the pickup reads each entry
	// TYPED via rt.script_of.)
	drop_table: gd.Array `gd:"export,array=Resource"`,

	next: int,
}

@(gd_method)
powerup_manager_spawn_drop :: proc(self: ^PowerupManager, pos: gd.Vector2) {
	n := int(gd.array_size(&self.drop_table))
	if n == 0 {return}
	// Typed spawn, deferred: spawn_drop arrives mid-physics, so parenting waits for
	// idle time — which also makes the pokes below visible to the pickup's _ready.
	p := rt.spawn_as_deferred(self.owner, cast(gd.Packed_Scene)self.pickup_scene, Pickup)
	if p == nil {return}
	gd.node2d_set_position(p.owner, pos)

	// Hand the pickup its config (round-robin through the drop table) — a direct typed
	// field poke: manager and pickup share this dll, no engine call needed.
	cv := gd.array_get(&self.drop_table, gd.Int(self.next % n))
	defer gd.variant_destroy(&cv)
	self.next += 1
	p.config = cast(^gd.Resource)gd.variant_to_object(&cv)
}
