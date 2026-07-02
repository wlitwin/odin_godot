//gd:extends Node2D
//gd:class PowerupManager
package barrage_powerups

// ----------------------------------------------------------------------------
// PowerupManager — spawns pickups (powerups MODULE). Holds the drop TABLE as a typed
// array of PowerupConfig resources (the `array=` export: the Inspector edits a real
// list of .tres slots) and instantiates pickup.tscn on request — `spawn_drop` is called
// by name from the enemies module. Drops cycle round-robin so the suite can predict
// what falls.
// ----------------------------------------------------------------------------

import gd "godot:godot"

PowerupManager :: struct {
	owner: gd.Node2d,

	pickup_scene: ^gd.Resource `gd:"export,resource=PackedScene"`,
	// The drop table: four .tres slots assigned in game.tscn. (A typed-array export
	// would be nicer; a scene-assigned array= property currently crashes the setter —
	// tracked as a core bug found by this example.)
	drop_a: ^gd.Resource `gd:"export,resource=PowerupConfig"`,
	drop_b: ^gd.Resource `gd:"export,resource=PowerupConfig"`,
	drop_c: ^gd.Resource `gd:"export,resource=PowerupConfig"`,
	drop_d: ^gd.Resource `gd:"export,resource=PowerupConfig"`,

	next: int,
}

powerup_manager_ready :: proc(self: ^PowerupManager) {
	grp := gd.new_string_name_cstring("powerup_manager", true)
	gd.node_add_to_group(cast(gd.Node)self.owner, grp, false)
}

@(gd_method)
powerup_manager_spawn_drop :: proc(self: ^PowerupManager, pos: gd.Vector2) {
	if self.pickup_scene == nil {return}
	table := [4]^gd.Resource{self.drop_a, self.drop_b, self.drop_c, self.drop_d}
	n := 0
	for r in table {if r != nil {n += 1}}
	if n == 0 {return}
	inst := gd.instantiate(cast(gd.Packed_Scene)self.pickup_scene)
	if inst == nil {return}
	gd.node2d_set_position(cast(gd.Node2d)inst, pos)
	gd.add_child_deferred(cast(gd.Node)self.owner, inst) // spawn_drop arrives mid-physics

	// Hand the pickup its config (round-robin through the assigned slots).
	pick := table[self.next % n]
	self.next += 1
	m := gd.sname("set_config")
	po := cast(gd.Object)pick
	cv := gd.variant_from(&po)
	_ = gd.object_call(cast(gd.Object)inst, m, cv)
}
