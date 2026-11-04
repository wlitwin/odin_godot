package kit_box3d_test

import "core:mem"
import "core:testing"
import b3 "godot:box3d"
import net "godot:kit/net"
import physics "godot:kit/physics"
import session "godot:kit/session"
import sim "godot:kit/sim"

Input :: struct {
    gravity:   u32,
    gravity_y: f32,
}

Actor :: struct {
    pose: b3.Pose,
    tick: u64,
}

Side :: struct {
    tick:                              u64,
    rng:                               u32,
    previous:                          u32,
    births, deaths:                    u32,
    keys:                              [4]b3.Body_Key,
    alive:                             [4]bool,
    sensor_begins, sensor_ends:        u32,
    last_end_sensor, last_end_visitor: b3.Shape_Key,
}

Fixture :: struct {
    lane:          sim.Lane,
    ses:           session.Session,
    p:             physics.Instance(Side),
    actors:        [3]Actor,
    desc:          net.Entity_Desc,
    gravity_tick:  u64,
    gravity_value: f32,
    effects:       int,
    unsupported:   u32,
    fail_capture:  bool,
    extra_bodies:  int,
    with_sensor:   bool,
    post_destroy:  u64,
}

actor_desc :: proc() -> net.Entity_Desc {
    @(static) fields := [?]net.Field_Desc {
        {offset = offset_of(Actor, pose), size = size_of(b3.Pose), flags = {.Predicted}},
        {offset = offset_of(Actor, tick), size = size_of(u64), flags = {.Predicted}},
    }
    return {fields = fields[:]}
}

sample :: proc(user: rawptr, tick: u64, dst: rawptr) {
    f := cast(^Fixture)user
    (cast(^Input)dst)^ = {
        gravity   = tick == f.gravity_tick ? 1 : 0,
        gravity_y = f.gravity_value,
    }
}

effect :: proc(user: rawptr, tick, key: u64, args: []u8) {
    f := cast(^Fixture)user
    assert(f.lane.world.presenting && sim.lane_live(&f.lane))
    f.effects += 1
}

step :: proc(user: rawptr, tick: u64) {
    f := cast(^Fixture)user
    s := physics.state(&f.p)
    assert(s != nil)
    world, error := physics.world(&f.p)
    assert(error == .Ok)
    s.tick = tick
    s.rng = s.rng * 1664525 + 1013904223

    if tick % 20 == 5 {
        d := b3.body_def_default()
        d.type = .Dynamic
        d.pose.position = {0, 4, 0}
        body, status := b3.body_create(world, d)
        assert(status == .Ok)
        shape_def := b3.shape_def_default()
        shape_def.enable_sensor_events = 1
        _, status = b3.shape_sphere(body, shape_def, .15)
        assert(status == .Ok)
        s.keys[3], status = b3.body_key(body)
        assert(status == .Ok)
        s.alive[3] = true
        s.births += 1
    }

    if tick % 20 == 10 && s.alive[3] {
        body, status := b3.body_resolve(world, s.keys[3])
        assert(status == .Ok)
        assert(b3.body_destroy(&body) == .Ok)
        s.alive[3] = false
        s.deaths += 1
    }

    for i in 0 ..< f.extra_bodies {
        d := b3.body_def_default()
        d.type = .Dynamic
        d.pose.position = {f32(i) * 2, 12, 0}
        body, status := b3.body_create(world, d)
        assert(status == .Ok)
        _, status = b3.shape_box(body, b3.shape_def_default(), {.1, .1, .1})
        assert(status == .Ok)
    }

    if tick % 3 == 0 {
        body, status := b3.body_resolve(world, s.keys[0])
        assert(status == .Ok)
        assert(b3.body_apply_impulse(body, {.01, .03, 0}) == .Ok)
    }

    if f.unsupported == 1 {
        sim.lane_untrack(&f.lane, 1)
    }

    if f.unsupported == 2 {
        _ = sim.lane_command(&f.lane, 1, 1, nil)
    }

    if f.unsupported == 3 {
        _ = sim.lane_spawn_cancel(&f.lane, sim.Net_Id(0x80000001))
    }

    assert(!sim.lane_live(&f.lane))
    assert(sim.lane_world_emit(&f.lane, 1, effect, f) == .Ok)
}

settle :: proc(user: rawptr, tick: u64) {
    f := cast(^Fixture)user
    s := physics.state(&f.p)
    world, error := physics.world(&f.p)
    assert(error == .Ok)
    input, ok := sim.lane_input_of(&f.lane, f.ses.me, Input)
    assert(ok)

    if input.gravity != 0 {
        assert(b3.world_set_gravity(world, {0, input.gravity_y, 0}) == .Ok)
    }

    events: [128]b3.Sensor_Event
    event_count, event_status := b3.world_sensor_events(world, events[:])
    assert(event_status == .Ok)

    for e in events[:event_count] {
        if e.began != 0 {
            s.sensor_begins += 1
        } else {
            s.sensor_ends += 1
            s.last_end_sensor, _ = b3.shape_key_from_handle(e.sensor)
            s.last_end_visitor, _ = b3.shape_key_from_handle(e.visitor)
        }
    }

    s.previous = input.gravity

    for i in 0 ..< 3 {
        body, status := b3.body_resolve(world, s.keys[i])
        assert(status == .Ok)
        f.actors[i].pose, status = b3.body_get_pose(body)
        assert(status == .Ok)
        f.actors[i].tick = tick
    }

    if tick == f.post_destroy && s.alive[3] {
        body, status := b3.body_resolve(world, s.keys[3])
        assert(status == .Ok)
        assert(b3.body_destroy(&body) == .Ok)
        s.alive[3] = false
        s.deaths += 1
    }

    if f.fail_capture {
        ogb3_snapshot_test_fail_allocation_after(0)
    }
}

init :: proc(
    f: ^Fixture,
    gravity_tick: u64 = 0,
    gravity_value: f32 = -7,
    cfg := physics.Config{asset_id = 123},
    with_sensor := false,
    post_destroy: u64 = 0,
) -> sim.World_Error {
    f.ses.is_host = true
    f.ses.me = 1
    f.desc = actor_desc()
    f.gravity_tick = gravity_tick
    f.gravity_value = gravity_value
    f.with_sensor = with_sensor
    f.post_destroy = post_destroy
    sim.lane_init(&f.lane, &f.ses, size_of(Input))
    sim.lane_set_sim(&f.lane, f, sample, step)
    types: [3]sim.World_Field_Type

    for &actor, i in f.actors {
        sim.lane_track(&f.lane, sim.Net_Id(i + 1), &actor, &f.desc, f.ses.me)
        types[i] = sim.world_field_type(sim.Net_Id(i + 1), Actor)
    }

    world, status := b3.world_create(b3.world_def_default())
    assert(status == .Ok)
    bd := b3.body_def_default()
    bd.pose.position.y = -1
    floor, sf := b3.body_create(world, bd)
    assert(sf == .Ok)
    _, status = b3.shape_box(floor, b3.shape_def_default(), {8, 1, 8})
    assert(status == .Ok)

    if with_sensor {
        sensor_def := b3.body_def_default()
        sensor_def.pose.position = {0, 4, 0}
        sensor, status := b3.body_create(world, sensor_def)
        assert(status == .Ok)
        shape_def := b3.shape_def_default()
        shape_def.is_sensor = 1
        shape_def.enable_sensor_events = 1
        _, status = b3.shape_box(sensor, shape_def, {.5, .5, .5})
        assert(status == .Ok)
    }

    side := Side {
        rng = 7,
    }

    for i in 0 ..< 3 {
        bd.type = .Dynamic
        bd.pose.position = {f32(i) * .7, 2, 0}
        body, st := b3.body_create(world, bd)
        assert(st == .Ok)
        shape_def := b3.shape_def_default()
        shape_def.enable_sensor_events = 1
        _, st = b3.shape_box(body, shape_def, {.2, .2, .2})
        assert(st == .Ok)
        side.keys[i], st = b3.body_key(body)
        assert(st == .Ok)
        side.alive[i] = true
        f.actors[i].pose, st = b3.body_get_pose(body)
        assert(st == .Ok)
    }

    cfg := cfg

    if with_sensor && cfg.asset_id == 123 {
        cfg.asset_id = 124
    }

    error := physics.attach(&f.p, &f.lane, &world, side, types[:], cfg, settle)

    if error != .Ok {
        b3.world_destroy(&world)
    }

    return error
}

destroy :: proc(f: ^Fixture) {
    sim.lane_destroy(&f.lane)
    assert(physics.detach(&f.p) == .Ok)
}

advance :: proc(t: ^testing.T, f: ^Fixture, count: int) {
    for _ in 0 ..< count {
        testing.expect_value(t, sim.lane_frame(&f.lane, 1.0 / 60), 1)
        testing.expect_value(t, sim.lane_world_status(&f.lane), sim.World_Error.Ok)
    }
}

checkpoint :: proc(t: ^testing.T, f: ^Fixture, tick: u64) -> sim.World_Checkpoint {
    cp, error := sim.lane_world_checkpoint(&f.lane, tick)
    testing.expect_value(t, error, sim.World_Error.Ok)
    return cp
}

same :: proc(t: ^testing.T, a, b: ^sim.World_Checkpoint) {
    equal, error := sim.world_checkpoint_equal(a, b)
    testing.expect_value(t, error, sim.World_Error.Ok)
    testing.expect(t, equal, "complete normalized solver+typedSide+fields equal")

}

reject :: proc(user: rawptr, tick: u64) -> bool {
    return false
}

@(test)
actual_lane_complete_correction_and_settled_frontier :: proc(t: ^testing.T) {
    a, b, c: Fixture
    testing.expect_value(t, init(&a, 4, -7), sim.World_Error.Ok)
    defer destroy(&a)
    testing.expect_value(t, init(&b), sim.World_Error.Ok)
    defer destroy(&b)
    testing.expect_value(t, init(&c, 4, -4), sim.World_Error.Ok)
    defer destroy(&c)
    advance(t, &a, 4)
    advance(t, &b, 4)
    advance(t, &c, 4)
    cp4 := checkpoint(t, &a, 4)
    defer sim.world_checkpoint_destroy(&cp4)
    bad4 := checkpoint(t, &c, 4)
    defer sim.world_checkpoint_destroy(&bad4)
    old2 := checkpoint(t, &b, 2)
    defer sim.world_checkpoint_destroy(&old2)
    own4 := checkpoint(t, &b, 4)
    defer sim.world_checkpoint_destroy(&own4)
    testing.expect(
        t,
        mem.compare(cp4.fields, own4.fields) == 0,
        "pose fields equal while complete native gravity/Side differ",
    )
    advance(t, &a, 4)
    advance(t, &b, 4)
    before := checkpoint(t, &b, 8)
    defer sim.world_checkpoint_destroy(&before)
    effects := b.effects
    failed := sim.lane_world_reconcile(&b.lane, &cp4, {allow = reject})
    testing.expect_value(t, failed.error, sim.World_Error.Rejected)
    after := checkpoint(t, &b, 8)
    defer sim.world_checkpoint_destroy(&after)
    same(t, &before, &after)
    testing.expect_value(t, b.effects, effects)
    result := sim.lane_world_reconcile(&b.lane, &cp4)
    testing.expect_value(t, result.error, sim.World_Error.Ok)
    testing.expect_value(t, result.steps, 4)
    testing.expect_value(t, sim.lane_world_confirmed(&b.lane), u64(4))
    testing.expect(t, b.effects == effects, "replay does not duplicate effects")
    expected := checkpoint(t, &a, 8)
    defer sim.world_checkpoint_destroy(&expected)
    corrected := checkpoint(t, &b, 8)
    defer sim.world_checkpoint_destroy(&corrected)
    same(t, &expected, &corrected)
    va, ea := physics.checkpoint_side(&expected, Side)
    vb, eb := physics.checkpoint_side(&corrected, Side)
    testing.expect_value(t, ea, sim.World_Error.Ok)
    testing.expect_value(t, eb, sim.World_Error.Ok)
    testing.expect_value(t, va.tick, vb.tick)
    testing.expect_value(t, va.rng, vb.rng)
    pa, sa := physics.checkpoint_body_state(&expected, va.keys[0], Side)
    pb, sb := physics.checkpoint_body_state(&corrected, vb.keys[0], Side)
    testing.expect_value(t, sa, sim.World_Error.Ok)
    testing.expect_value(t, sb, sim.World_Error.Ok)
    testing.expect_value(t, pa.pose.position.y, pb.pose.position.y)
    testing.expect_value(t, sim.lane_world_reconcile(&b.lane, &old2).error, sim.World_Error.Settled)
    testing.expect_value(t, sim.lane_world_reconcile(&b.lane, &cp4).steps, 0)
    testing.expect_value(t, sim.lane_world_reconcile(&b.lane, &bad4).error, sim.World_Error.Conflict)
    unchanged := checkpoint(t, &b, 8)
    defer sim.world_checkpoint_destroy(&unchanged)
    same(t, &corrected, &unchanged)
}

@(test)
history_wrap_dynamic_keys_and_detached_checkpoint :: proc(t: ^testing.T) {
    source := new(Fixture)
    testing.expect_value(t, init(source), sim.World_Error.Ok)
    advance(t, source, 256)
    missing, error := sim.lane_world_checkpoint(&source.lane, 1)
    testing.expect_value(t, error, sim.World_Error.History_Missing)
    testing.expect(t, missing.image == nil)
    cp := checkpoint(t, source, 256)
    defer sim.world_checkpoint_destroy(&cp)
    side, side_error := physics.checkpoint_side(&cp, Side)
    testing.expect_value(t, side_error, sim.World_Error.Ok)
    testing.expect(t, side.births > 5 && side.deaths > 5)
    destroy(source)
    mem.zero(source, size_of(Fixture))
    free(source)
    detached, e := sim.world_checkpoint_clone(&cp)
    testing.expect_value(t, e, sim.World_Error.Ok)
    defer sim.world_checkpoint_destroy(&detached)
    pose, pe := physics.checkpoint_body_state(&detached, side.keys[0], Side)
    testing.expect_value(t, pe, sim.World_Error.Ok)
    testing.expect(t, pose.key == side.keys[0])
    resumed: Fixture
    testing.expect_value(t, init(&resumed), sim.World_Error.Ok)
    defer destroy(&resumed)
    testing.expect_value(t, sim.lane_world_reset(&resumed.lane, &detached).error, sim.World_Error.Ok)
    advance(t, &resumed, 1)
    testing.expect_value(t, resumed.actors[0].tick, u64(257))
}

@(test)
unsupported_mutation_and_prediction_repair_bounds :: proc(t: ^testing.T) {
    f: Fixture
    testing.expect_value(t, init(&f), sim.World_Error.Ok)
    defer destroy(&f)
    cp0 := checkpoint(t, &f, 0)
    defer sim.world_checkpoint_destroy(&cp0)

    for operation in u32(1) ..= 3 {
        f.unsupported = operation
        testing.expect_value(t, sim.lane_frame(&f.lane, 1.0 / 60), 0)
        testing.expect_value(t, sim.lane_world_status(&f.lane), sim.World_Error.Unsupported)
        testing.expect_value(t, len(f.lane.entries), 3)
        testing.expect_value(t, len(f.lane.cmd_in), 0)
        testing.expect_value(t, f.effects, 0)
        testing.expect_value(t, f.actors[0].tick, u64(0))
        f.unsupported = 0
        testing.expect_value(t, sim.lane_world_reset(&f.lane, &cp0).error, sim.World_Error.Ok)
    }

    advance(t, &f, 1)
    cp1 := checkpoint(t, &f, 1)
    defer sim.world_checkpoint_destroy(&cp1)
    advance(t, &f, 9)
    testing.expect_value(t, sim.lane_world_reconcile(&f.lane, &cp0).error, sim.World_Error.Ok) // settled identical = no-op, no rewind
    testing.expect_value(t, sim.lane_world_reconcile(&f.lane, &cp1).error, sim.World_Error.Repair_Limit)
    current := checkpoint(t, &f, 10)
    defer sim.world_checkpoint_destroy(&current)
    testing.expect_value(t, sim.lane_world_reset(&f.lane, &current).error, sim.World_Error.Ok)
    f.ses.is_host = false
    advance(t, &f, 8)
    testing.expect_value(t, sim.lane_frame(&f.lane, 1.0 / 60), 0)
    testing.expect_value(t, sim.lane_world_status(&f.lane), sim.World_Error.Prediction_Limit)
    testing.expect(t, sim.lane_world_needs_resync(&f.lane))
}
