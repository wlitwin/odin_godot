package main

// Run against a retained older logical-state archive. This intentionally expects
// an ABI-compatible but logically incompatible library and never creates a world.
import "core:fmt"
import b "godot:box3d"

main :: proc() {
	actual := b.state_version()
	assert(
		actual != u32(b.STATE_DUMP_VERSION),
		"negative control requires an older/different logical-state library",
	)
	assert(b.abi_check() == .Incompatible)
	def := b.World_Def {
		gravity           = {0, -10, 0},
		enable_sleep      = 1,
		enable_continuous = 1,
	}
	world, status := b.world_create(def); assert(status == .Incompatible && world == 0)
	_, count_status := b.world_counters(b.World(1)); assert(count_status == .Incompatible)
	assert(b.world_step_fixed(b.World(1)) == .Incompatible)
	snapshot, capture_status := b.snapshot_capture(
		b.World(1),
	); assert(capture_status == .Incompatible && b.snapshot_is_empty(&snapshot))
	_, dump_status := b.world_dump(b.World(1), nil); assert(dump_status == .Incompatible)
	_, memory_status := b.alpha_memory_check(); assert(memory_status == .Incompatible)
	engine, engine_status := b.engine_allocation_stats(
		
	); assert(engine_status == .Ok && engine.total_calls == 0 && engine.live_bytes == 0)
	owned, owned_status := b.snapshot_allocation_stats(
		
	); assert(owned_status == .Ok && owned.total_calls == 0 && owned.live_bytes == 0)
	fmt.printf(
		"logical_version_negative native=%d compiled=%d incompatible_before_world_use=1 native_allocations=0 wrapper_allocations=0 PASS\n",
		actual,
		b.STATE_DUMP_VERSION,
	)
}
