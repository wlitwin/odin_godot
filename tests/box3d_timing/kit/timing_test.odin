package kit_box3d_timing_test

import "core:fmt"
import "core:testing"
import b "godot:box3d"
import a "godot:box3d/authoring"
import ar "godot:box3d/authoring/runtime"
import limits "godot:box3d/limits"
import d "godot:box3d/diagnostics"
import n "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"
import k "godot:kit/sim"
import f "godot:tests/box3d_authoring/frameworks"

Fixture :: struct {
    box:           f.Kit_Box,
    first_control: u8,
}

Large_Control :: [k.MAX_INPUT_SIZE]u8

sample :: proc(user: rawptr, tick: u64, dst: rawptr) {
    fixture := cast(^Fixture)user
    // Device-side sampling is outside replay. Tick rules read the retained
    // control below, so correction cannot reread this fixture setting.
    (cast(^u8)dst)^ = tick == 1 ? fixture.first_control : 0
}

step :: proc(user: rawptr, tick: u64) {
    fixture := cast(^Fixture)user
    box := &fixture.box
    control, ok := k.lane_input(&box.lane, 2)
    gravity := b.Vec3{}

    if ok && len(control) > 0 && control[0] != 0 {
        gravity.x = .25
    }

    world, error := p.world(&box.physics)
    assert(error == .Ok)

    if !p.require(&box.physics, b.world_set_gravity(world, gravity)) {
        return
    }

    p.state(&box.physics).tick = tick
}

scene_make :: proc(t: ^testing.T) -> a.Baked_Scene {
    input := f.scene_input()
    defer f.scene_input_destroy(&input)
    scene, problem := a.bake(input)
    testing.expect_value(t, problem.error, a.Error.None)
    return scene
}

setup :: proc(
    t: ^testing.T,
    fixture: ^Fixture,
    scene: ^a.Baked_Scene,
    network := false,
    cfg := k.Lane_Config{},
    large_input := false,
) -> k.World_Error {
    box := &fixture.box
    built, problem := ar.build(scene, f.PROFILE)
    testing.expect_value(t, problem.error, a.Error.None)

    if problem.error != .None {
        return .Invalid
    }

    box.built = built
    selected := cfg

    if selected.hz == 0 && selected.slots == 0 {
        selected = k.world_lane_config_default()
    }

    input_size := large_input ? size_of(Large_Control) : size_of(u8)
    k.lane_init(&box.lane, &box.ses, input_size, cfg = selected)
    k.lane_set_sim(&box.lane, fixture, sample, step)
    k.lane_class_set_type(&box.lane, 0, large_input ? typeid_of(Large_Control) : typeid_of(u8))
    error := p.authoring_attach(&box.physics, &box.lane, &box.built, f.State{}, nil, {})

    if error != .Ok || !network {
        return error
    }

    error = p.codec_init(&box.control)

    if error != .Ok {
        return error
    }

    inputs := []k.World_Wire_Input{{0, box.control.value, .Hold}}
    drivers := []k.World_Driver{{1, 0}, {2, 0}}
    rules := d.hash_bytes(transmute([]u8)string("box3d.timing.kit.gravity.v1"))
    return p.network_attach(&box.network, &box.physics, &box.built.catalog, nil, inputs, drivers, nil, rules)
}

close :: proc(t: ^testing.T, fixture: ^Fixture) {
    f.kit_destroy(t, &fixture.box)
}

advance :: proc(t: ^testing.T, fixture: ^Fixture, count: int) {
    for _ in 0 ..< count {
        testing.expect_value(t, k.lane_frame(&fixture.box.lane, 1.0 / f64(limits.TICK_HZ)), 1)
        testing.expect_value(t, k.lane_world_status(&fixture.box.lane), k.World_Error.Ok)
    }
}

checkpoint :: proc(t: ^testing.T, fixture: ^Fixture, tick: u64) -> k.World_Checkpoint {
    result, error := k.lane_world_checkpoint(&fixture.box.lane, tick)
    testing.expect_value(t, error, k.World_Error.Ok)
    return result
}

expect_same :: proc(t: ^testing.T, left, right: ^k.World_Checkpoint) {
    same, error := k.world_checkpoint_equal(left, right)
    testing.expect_value(t, error, k.World_Error.Ok)
    testing.expect(t, same, "complete native solver, typed Side, and field state must agree")
}

drop_proposals :: proc(box: ^f.Kit_Box) {
    // Drop only actual transport-owned packets. The authority will record held
    // zero input, while the client has already predicted its sampled one.
    for parcel in box.out {
        delete(parcel.bytes)
    }

    delete(box.out)
    box.out = nil
}

pair_open :: proc(t: ^testing.T, host, client: ^Fixture, scene: ^a.Baked_Scene) -> bool {
    host.box.peer = s.HOST_PEER
    client.box.peer = 100

    for box in ([]^f.Kit_Box{&host.box, &client.box}) {
        box.ses.send = f.kit_send
        box.ses.send_user = box
    }

    s.session_host_start(&host.box.ses, "authority")
    s.session_client_start(&client.box.ses, 0x74696d696e67, "client")
    s.session_client_join(&client.box.ses)
    f.kit_pump({&host.box, &client.box})
    testing.expect_value(t, host.box.ses.me, n.Player_Id(1))
    testing.expect_value(t, client.box.ses.me, n.Player_Id(2))
    he := setup(t, host, scene, true)
    ce := setup(t, client, scene, true)
    testing.expect_value(t, he, k.World_Error.Ok)
    testing.expect_value(t, ce, k.World_Error.Ok)

    if he != .Ok || ce != .Ok {
        return false
    }

    testing.expect_value(t, k.lane_world_send_checkpoint(&host.box.lane, client.box.peer, .Welcome), k.World_Error.Ok)
    f.kit_pump({&host.box, &client.box})
    _ = k.lane_frame(&client.box.lane, 0)
    return f.kit_same(t, &host.box, &client.box, 0)
}

@(test)
selected_lane_configuration_and_mismatches_are_explicit :: proc(t: ^testing.T) {
    cfg := k.world_lane_config_default()
    testing.expect_value(t, cfg.hz, limits.TICK_HZ)
    testing.expect_value(t, cfg.slots, limits.HISTORY_FRAMES)
    testing.expect(t, cfg.snap_every <= limits.KIT_REPAIR_TICKS)
    testing.expect(t, cfg.margin <= limits.KIT_REPAIR_TICKS)
    scene := scene_make(t)
    defer a.destroy(&scene)

    for mode in 0 ..< 4 {
        fixture := new(Fixture)
        fixture.box.ses.is_host = true
        fixture.box.ses.me = 2
        wrong := cfg

        switch mode {
        case 0:
            wrong.hz += 1
        case 1:
            wrong.slots *= 2
        case 2:
            wrong.snap_every = limits.KIT_REPAIR_TICKS + 1
        case 3:
            wrong.margin = limits.KIT_REPAIR_TICKS + 1
        }

        testing.expect_value(t, setup(t, fixture, &scene, cfg = wrong), k.World_Error.Unsupported)
        testing.expect(t, fixture.box.lane.world == nil)
        valid, status := b.world_valid(fixture.box.built.world)
        testing.expect(t, status == .Ok && valid)
        close(t, fixture)
        free(fixture)
    }
}

@(test)
wide_input_batches_must_fit_the_app_message_bound :: proc(t: ^testing.T) {
    scene := scene_make(t)
    defer a.destroy(&scene)
    fixture := new(Fixture)
    defer free(fixture)
    codec: p.Typed_Codec(Large_Control)
    defer p.codec_destroy(&codec)
    defer close(t, fixture)
    fixture.box.ses.is_host = true
    fixture.box.ses.me = 2
    testing.expect_value(t, setup(t, fixture, &scene, large_input = true), k.World_Error.Ok)
    testing.expect_value(t, p.codec_init(&codec), k.World_Error.Ok)
    inputs := []k.World_Wire_Input{{0, codec.value, .Hold}}
    drivers: [k.WORLD_NETWORK_DRIVERS]k.World_Driver

    for &driver, i in drivers {
        driver = {n.Player_Id(i + 1), 0}
    }

    rules := d.hash_bytes(transmute([]u8)string("box3d.timing.kit.wide-input.v1"))
    expected_bytes := 64 + 25 * len(drivers) + limits.KIT_REPAIR_TICKS * len(drivers) * (10 + codec.value.wire_bytes)
    error := p.network_attach(
        &fixture.box.network,
        &fixture.box.physics,
        &fixture.box.built.catalog,
        nil,
        inputs,
        drivers[:],
        nil,
        rules,
    )
    expected := expected_bytes > k.WORLD_PACKET_BYTES ? k.World_Error.Capacity : k.World_Error.Ok
    testing.expect_value(t, error, expected)

    if expected == .Capacity {
        testing.expect(t, fixture.box.lane.world.network == nil)
    }
}

@(test)
accepted_input_repairs_the_entire_selected_window :: proc(t: ^testing.T) {
    scene := scene_make(t)
    defer a.destroy(&scene)
    host, client := new(Fixture), new(Fixture)
    defer free(host)
    defer free(client)
    defer close(t, host)
    defer close(t, client)
    client.first_control = 1

    if !pair_open(t, host, client, &scene) {
        return
    }

    advance(t, client, limits.KIT_REPAIR_TICKS)
    drop_proposals(&client.box)
    advance(t, host, limits.KIT_REPAIR_TICKS)
    tick := u64(limits.KIT_REPAIR_TICKS)
    before := checkpoint(t, client, tick)
    truth := checkpoint(t, host, tick)
    different, error := k.world_checkpoint_equal(&before, &truth)
    testing.expect_value(t, error, k.World_Error.Ok)
    testing.expect(t, !different, "the sampled control must produce a real predicted native difference")
    resims := client.box.lane.stat_resims
    f.kit_pump({&host.box, &client.box})
    _ = k.lane_frame(&client.box.lane, 0)
    testing.expect_value(t, k.lane_world_status(&client.box.lane), k.World_Error.Ok)
    testing.expect_value(t, client.box.lane.stat_resims - resims, limits.KIT_REPAIR_TICKS)
    corrected := checkpoint(t, client, tick)
    defer k.world_checkpoint_destroy(&corrected)
    expect_same(t, &truth, &corrected)
    settled := k.lane_world_confirmed(&client.box.lane)
    testing.expect(t, settled > 0 && settled <= tick)
    testing.expect(t, f.kit_same(t, &host.box, &client.box, settled))
    testing.expect_value(t, k.world_checkpoint_destroy(&before), k.World_Error.Ok)
    testing.expect_value(t, k.world_checkpoint_destroy(&truth), k.World_Error.Ok)
    fmt.printf(
        "KIT_TIMING_ACCEPTED_REPAIR_OK history=%d repair=%d hz=%d substeps=%d\n",
        limits.HISTORY_FRAMES,
        limits.KIT_REPAIR_TICKS,
        limits.TICK_HZ,
        limits.SUBSTEPS,
    )
}

@(test)
prediction_one_past_window_preserves_complete_publication :: proc(t: ^testing.T) {
    scene := scene_make(t)
    defer a.destroy(&scene)
    host, client := new(Fixture), new(Fixture)
    defer free(host)
    defer free(client)
    defer close(t, host)
    defer close(t, client)

    if !pair_open(t, host, client, &scene) {
        return
    }

    client.first_control = 1
    advance(t, client, limits.KIT_REPAIR_TICKS)
    tick := u64(limits.KIT_REPAIR_TICKS)
    before := checkpoint(t, client, tick)
    defer k.world_checkpoint_destroy(&before)
    testing.expect_value(t, k.lane_frame(&client.box.lane, 1.0 / f64(limits.TICK_HZ)), 0)
    testing.expect_value(t, k.lane_world_status(&client.box.lane), k.World_Error.Prediction_Limit)
    testing.expect_value(t, k.lane_now(&client.box.lane), tick)
    testing.expect(t, k.lane_world_needs_resync(&client.box.lane))
    after := checkpoint(t, client, tick)
    defer k.world_checkpoint_destroy(&after)
    expect_same(t, &before, &after)
}

@(test)
repair_at_limit_succeeds_and_one_past_preserves_publication :: proc(t: ^testing.T) {
    scene := scene_make(t)
    defer a.destroy(&scene)
    truth, predicted := new(Fixture), new(Fixture)
    defer free(truth)
    defer free(predicted)
    defer close(t, truth)
    defer close(t, predicted)

    for fixture in ([]^Fixture{truth, predicted}) {
        fixture.box.ses.is_host = true
        fixture.box.ses.me = 2
        testing.expect_value(t, setup(t, fixture, &scene), k.World_Error.Ok)
    }

    truth.first_control = 1
    advance(t, truth, 1)
    cp1 := checkpoint(t, truth, 1)
    defer k.world_checkpoint_destroy(&cp1)
    advance(t, truth, 1)
    cp2 := checkpoint(t, truth, 2)
    defer k.world_checkpoint_destroy(&cp2)
    advance(t, truth, limits.KIT_REPAIR_TICKS)
    advance(t, predicted, limits.KIT_REPAIR_TICKS + 2)
    head := u64(limits.KIT_REPAIR_TICKS + 2)
    before := checkpoint(t, predicted, head)
    defer k.world_checkpoint_destroy(&before)
    too_deep := k.lane_world_reconcile(&predicted.box.lane, &cp1)
    testing.expect_value(t, too_deep.error, k.World_Error.Repair_Limit)
    testing.expect_value(t, too_deep.steps, 0)
    testing.expect_value(t, k.lane_now(&predicted.box.lane), head)
    after := checkpoint(t, predicted, head)
    defer k.world_checkpoint_destroy(&after)
    expect_same(t, &before, &after)
    repaired := k.lane_world_reconcile(&predicted.box.lane, &cp2)
    testing.expect_value(t, repaired.error, k.World_Error.Ok)
    testing.expect_value(t, repaired.steps, limits.KIT_REPAIR_TICKS)
    expected := checkpoint(t, truth, head)
    defer k.world_checkpoint_destroy(&expected)
    actual := checkpoint(t, predicted, head)
    defer k.world_checkpoint_destroy(&actual)
    expect_same(t, &expected, &actual)
}

@(test)
history_retention_tracks_the_selected_ring :: proc(t: ^testing.T) {
    scene := scene_make(t)
    defer a.destroy(&scene)
    fixture := new(Fixture)
    defer free(fixture)
    defer close(t, fixture)
    fixture.box.ses.is_host = true
    fixture.box.ses.me = 2
    testing.expect_value(t, setup(t, fixture, &scene), k.World_Error.Ok)
    advance(t, fixture, limits.HISTORY_FRAMES + 3)
    head := u64(limits.HISTORY_FRAMES + 3)
    oldest := head - u64(limits.HISTORY_FRAMES) + 1
    retained := checkpoint(t, fixture, oldest)
    defer k.world_checkpoint_destroy(&retained)
    missing, error := k.lane_world_checkpoint(&fixture.box.lane, oldest - 1)
    testing.expect_value(t, error, k.World_Error.History_Missing)
    testing.expect(t, missing.image == nil)
    testing.expect_value(t, k.world_checkpoint_destroy(&missing), k.World_Error.Ok)
    current := checkpoint(t, fixture, head)
    defer k.world_checkpoint_destroy(&current)
    side, se := p.checkpoint_side(&current, f.State)
    testing.expect_value(t, se, k.World_Error.Ok)
    testing.expect_value(t, side.tick, head)
    fmt.printf("KIT_TIMING_HISTORY_OK frames=%d oldest=%d head=%d\n", limits.HISTORY_FRAMES, oldest, head)
}
