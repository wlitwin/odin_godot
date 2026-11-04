package kit_box3d_test

import "core:testing"
import "core:time"
import b3 "godot:box3d"
import physics "godot:kit/physics"
import sim "godot:kit/sim"

TEST_LIBRARY :: #config(BOX3D_LIBRARY, "")
foreign import native_test_hooks {"system:" + TEST_LIBRARY}

foreign native_test_hooks {
    ogb3_snapshot_test_fail_stage :: proc "c" (stage: i32) ---
    ogb3_snapshot_test_fail_allocation_after :: proc "c" (after: i64) ---
}

slow_authorize :: proc(user: rawptr, tick: u64) -> bool {
    time.sleep(8 * time.Millisecond)
    return true
}

mutating_authorize :: proc(user: rawptr, tick: u64) -> bool {
    f := cast(^Fixture)user
    physics.state(&f.p).rng += 1
    return true
}

@(test)
real_native_failures_preserve_complete_pair_ledgers_and_effects :: proc(t: ^testing.T) {
    f: Fixture
    testing.expect_value(t, init(&f), sim.World_Error.Ok)
    defer destroy(&f)
    advance(t, &f, 4)
    before := checkpoint(t, &f, 4)
    defer sim.world_checkpoint_destroy(&before)
    effects := f.effects
    engine, _ := b3.engine_allocation_stats()
    wrapper, _ := b3.snapshot_allocation_stats()
    external := physics.owned_bytes()
    cp_bytes := sim.world_checkpoint_owned_bytes()
    stamps: [3][sim.WORLD_HISTORY_FRAMES]u64

    for e, i in f.lane.entries {
        copy(stamps[i][:], e.hist.tick)
    }

    for stage in i32(1) ..= 3 {
        ogb3_snapshot_test_fail_stage(stage)
        testing.expect_value(t, sim.lane_frame(&f.lane, 1.0 / 60), 0)
        ogb3_snapshot_test_fail_stage(0)
        testing.expect_value(t, sim.lane_world_status(&f.lane), sim.World_Error.Allocation_Failed)
        testing.expect_value(t, f.lane.ticker.tick, u64(4))
        testing.expect_value(t, f.effects, effects)
        now := checkpoint(t, &f, 4)
        same(t, &before, &now)
        sim.world_checkpoint_destroy(&now)
        es, _ := b3.engine_allocation_stats()
        ws, _ := b3.snapshot_allocation_stats()
        testing.expect_value(t, es.live_bytes, engine.live_bytes)
        testing.expect_value(t, ws.live_bytes, wrapper.live_bytes)
        testing.expect_value(t, physics.owned_bytes(), external)
        testing.expect_value(t, sim.world_checkpoint_owned_bytes(), cp_bytes)
    }

    // Tick5 creates a native body and changes Side+registered fields before the
    // actual snapshot allocator fails. None of that future may be published.
    f.fail_capture = true
    testing.expect_value(t, sim.lane_frame(&f.lane, 1.0 / 60), 0)
    ogb3_snapshot_test_fail_allocation_after(-1)
    f.fail_capture = false
    testing.expect_value(t, sim.lane_world_status(&f.lane), sim.World_Error.Allocation_Failed)
    testing.expect_value(t, f.actors[0].tick, u64(4))
    testing.expect_value(t, f.effects, effects)
    side, ok := physics.read(&f.p)
    testing.expect(t, ok)
    testing.expect_value(t, side.births, u32(0))
    testing.expect_value(t, f.lane.inputs[0].ring.head, u64(4))

    for e, i in f.lane.entries {
        for stamp, j in e.hist.tick {
            testing.expect_value(t, stamp, stamps[i][j])
        }
    }

    now := checkpoint(t, &f, 4)
    same(t, &before, &now)
    sim.world_checkpoint_destroy(&now)
    es, _ := b3.engine_allocation_stats()
    ws, _ := b3.snapshot_allocation_stats()
    testing.expect_value(t, es.live_bytes, engine.live_bytes)
    testing.expect_value(t, ws.live_bytes, wrapper.live_bytes)
    advance(t, &f, 1)
    side, ok = physics.read(&f.p)
    testing.expect(t, ok)
    testing.expect_value(t, side.births, u32(1))
}

@(test)
counts_memory_missing_attachment_and_gate_purity :: proc(t: ^testing.T) {
    f: Fixture
    testing.expect_value(t, init(&f), sim.World_Error.Ok)
    defer destroy(&f)
    cp0 := checkpoint(t, &f, 0)
    defer sim.world_checkpoint_destroy(&cp0)
    f.extra_bodies = 33
    testing.expect_value(t, sim.lane_frame(&f.lane, 1.0 / 60), 0)
    testing.expect_value(t, sim.lane_world_status(&f.lane), sim.World_Error.Budget)
    testing.expect_value(t, f.lane.ticker.tick, u64(0))
    testing.expect_value(t, f.effects, 0)
    f.extra_bodies = 0
    testing.expect_value(t, sim.lane_world_reset(&f.lane, &cp0).error, sim.World_Error.Ok)
    advance(t, &f, 4)
    before := checkpoint(t, &f, 4)
    defer sim.world_checkpoint_destroy(&before)
    testing.expect_value(
        t,
        sim.lane_world_reset(&f.lane, &before, {user = &f, allow = mutating_authorize}).error,
        sim.World_Error.Unsupported,
    )
    now := checkpoint(t, &f, 4)
    same(t, &before, &now)
    sim.world_checkpoint_destroy(&now)
    testing.expect_value(t, sim.lane_world_reset(&f.lane, &before).error, sim.World_Error.Ok)
    append(&f.lane.pending, u8(0)) // legacy packet body without complete attachment
    testing.expect_value(t, sim.lane_frame(&f.lane, 1.0 / 60), 0)
    testing.expect_value(t, sim.lane_world_status(&f.lane), sim.World_Error.Missing_Attachment)
    testing.expect(t, sim.lane_world_needs_resync(&f.lane))
    testing.expect_value(t, f.lane.ticker.tick, u64(4))
    testing.expect_value(t, sim.lane_world_reset(&f.lane, &before).error, sim.World_Error.Ok)
    testing.expect_value(t, len(f.lane.pending), 0)
    // Registered histories cannot be independently rewritten while paired.
    sim.history_note(f.lane.entries[0].hist, 4, &f.actors[0])
    testing.expect_value(t, sim.lane_world_status(&f.lane), sim.World_Error.Unsupported)
    testing.expect_value(t, sim.lane_world_reset(&f.lane, &before).error, sim.World_Error.Ok)
    // Deliberately delayed authorization records a missed timing target, without
    // making clock scheduling an input, rejection or sticky resync condition.
    testing.expect_value(t, sim.lane_world_reset(&f.lane, &before, {allow = slow_authorize}).error, sim.World_Error.Ok)
    testing.expect(t, sim.lane_world_work_stats(&f.lane).correction_latest_ns > sim.WORLD_WORK_NS)
    testing.expect(t, !sim.lane_world_needs_resync(&f.lane))
    bad: Fixture
    testing.expect_value(
        t,
        init(&bad, cfg = {asset_id = 123, additional_owned_bytes = max(u64)}),
        sim.World_Error.Budget,
    )
    destroy(&bad)
}

@(test)
all_owned_domains_return_to_zero :: proc(t: ^testing.T) {
    f: Fixture
    testing.expect_value(t, init(&f), sim.World_Error.Ok)
    advance(t, &f, 10)
    cp := checkpoint(t, &f, 10)
    clone, error := sim.world_checkpoint_clone(&cp)
    testing.expect_value(t, error, sim.World_Error.Ok)
    destroy(&f)
    sim.world_checkpoint_destroy(&cp)
    sim.world_checkpoint_destroy(&clone)
    engine, es := b3.engine_allocation_stats()
    wrapper, ws := b3.snapshot_allocation_stats()
    testing.expect_value(t, es, b3.Status.Ok)
    testing.expect_value(t, ws, b3.Status.Ok)
    testing.expect_value(t, engine.live_bytes, u64(0))
    testing.expect_value(t, wrapper.live_bytes, u64(0))
    testing.expect_value(t, physics.owned_bytes(), u64(0))
    testing.expect_value(t, sim.world_checkpoint_owned_bytes(), u64(0))
}

Bad_Pointer_Side :: struct {
    pointer: rawptr,
}

Bad_Handle_Side :: struct {
    body: b3.Body,
}

@(test)
side_requires_owned_values_and_world_independent_keys :: proc(t: ^testing.T) {
    f: Fixture
    f.ses.is_host = true
    f.ses.me = 1
    sim.lane_init(&f.lane, &f.ses, 0)
    world, status := b3.world_create(b3.world_def_default())
    testing.expect_value(t, status, b3.Status.Ok)
    pointers: physics.Instance(Bad_Pointer_Side)
    testing.expect_value(
        t,
        physics.attach(&pointers, &f.lane, &world, Bad_Pointer_Side{}, nil, {asset_id = 123}),
        sim.World_Error.Unsupported,
    )
    handles: physics.Instance(Bad_Handle_Side)
    testing.expect_value(
        t,
        physics.attach(&handles, &f.lane, &world, Bad_Handle_Side{}, nil, {asset_id = 123}),
        sim.World_Error.Unsupported,
    )
    testing.expect(t, world != 0)
    testing.expect_value(t, b3.world_destroy(&world), b3.Status.Ok)
    sim.lane_destroy(&f.lane)
}

@(test)
settle_despawn_preserves_future_end_once_through_checkpoint :: proc(t: ^testing.T) {
    a, b: Fixture
    testing.expect_value(t, init(&a, with_sensor = true, post_destroy = 6), sim.World_Error.Ok)
    defer destroy(&a)
    testing.expect_value(t, init(&b, with_sensor = true, post_destroy = 6), sim.World_Error.Ok)
    defer destroy(&b)
    advance(t, &a, 6)
    advance(t, &b, 6)
    cp6 := checkpoint(t, &a, 6)
    defer sim.world_checkpoint_destroy(&cp6)
    s6, _ := physics.checkpoint_side(&cp6, Side)
    testing.expect_value(t, s6.sensor_begins, u32(1))
    testing.expect_value(t, s6.sensor_ends, u32(0))
    testing.expect(t, !s6.alive[3])
    advance(t, &a, 2)
    advance(t, &b, 2)
    s8, _ := physics.read(&a.p)
    testing.expect_value(t, s8.sensor_ends, u32(1))
    testing.expect(t, s8.last_end_visitor != 0)
    fx := b.effects
    testing.expect_value(t, sim.lane_world_reconcile(&b.lane, &cp6).error, sim.World_Error.Ok)
    corrected, _ := physics.read(&b.p)
    testing.expect_value(t, corrected.sensor_ends, u32(1))
    testing.expect_value(t, b.effects, fx)
    expected := checkpoint(t, &a, 8)
    defer sim.world_checkpoint_destroy(&expected)
    actual := checkpoint(t, &b, 8)
    defer sim.world_checkpoint_destroy(&actual)
    same(t, &expected, &actual)
    count, error := physics.checkpoint_dump(&actual, nil, Side)
    testing.expect_value(t, error, sim.World_Error.Ok)
    tiny: [1]u8 = {0xa5}
    required, small := physics.checkpoint_dump(&actual, tiny[:], Side)
    testing.expect_value(t, small, sim.World_Error.Capacity)
    testing.expect_value(t, required, count)
    testing.expect_value(t, tiny[0], u8(0xa5))
    _, wrong := physics.checkpoint_dump(&actual, nil, Bad_Handle_Side)
    testing.expect_value(t, wrong, sim.World_Error.Incompatible)
}
