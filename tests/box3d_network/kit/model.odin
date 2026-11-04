// Test-only fixture adapted from tests/kit_box3d_net/fixture.odin
// Original SHA256 4907d6464a75abadd8359ccd07f199a5d0a062c4115e5a209724d02ba286e258; production runtimes are reused unchanged.
package main

import comm "../common"
import "core:fmt"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import n "godot:kit/net"
import p "godot:kit/physics"
import s "godot:kit/session"
import k "godot:kit/sim"
import pf "godot:tests/replay_physics_net/fixture"

Control :: struct {
    axis: i32,
}

Action :: struct {
    kind, serial: u32,
}

Proxy :: struct {
    pose: b.Pose,
    tick: u64,
}

Side :: struct {
    tick:                                                u64,
    rng:                                                 u32,
    initial:                                             u32,
    keys:                                                [33]b.Body_Key,
    alive:                                               [33]bool,
    generation:                                          [33]u32,
    hinge:                                               b.Joint_Key,
    last_action:                                         [2]u32,
    births, deaths, begins, ends:                        u32,
    pending_destroy:                                     bool,
    extra_shape, retired_shape:                          b.Shape_Key,
    expected_end_tick, exact_extra_ends, last_extra_end: u64,
    last_decision:                                       [2]u8,
    applied_actions, rejected_actions:                   u32,
}

Box :: struct {
    peer:                            s.Peer_Id,
    ses:                             s.Session,
    lane:                            k.Lane,
    physics:                         p.Instance(Side),
    network:                         p.Network(Side),
    control:                         p.Typed_Codec(Control),
    control_v2:                      p.Typed_Codec(Control_V2),
    action:                          p.Typed_Codec(Action),
    proxy:                           p.Typed_Codec(Proxy),
    desc:                            n.Entity_Desc,
    proxies:                         [32]Proxy,
    fields:                          [32]k.World_Wire_Field,
    endpoint:                        comm.Endpoint,
    args:                            comm.Args,
    rule_scale:                      i32,
    input_variant:                   bool,
    effect_ids:                      [4096]Effect_Id,
    effect_count, duplicate_effects: int,
    last_confirmed, logged_epoch:    u64,
    trace_saved:                     bool,
    ready_seen:                      bool,
    reset_observed, source_released: bool,
    probe:                           k.World_Checkpoint,
    command_serial:                  u64,
    stale_bytes:                     [65536]u8,
    stale_count:                     int,
    stale_channel:                   u32,
    peak, last_counts:               b.World_Counters,
    active:                          bool,
    axis:                            i32,
    action_at:                       u64,
    action_kind:                     u32,
    effects:                         int,
    count:                           int,
    fail:                            bool,
    initial_gravity:                 bool,
    initial_side_delta:              bool,
}

check :: proc(status: b.Status) {
    assert(status == .Ok)
}

world :: proc(count: int) -> (b.World, Side) {
    w, source, status := pf.world(u32(count))
    check(status)
    game := Side {
        rng     = source.rng,
        initial = u32(count),
        hinge   = source.joint,
    }

    for i in 0 ..< count {
        game.keys[i] = source.bodies[i]
        game.alive[i] = source.alive[i]
        game.generation[i] = source.generation[i]
    }

    return w, game
}

catalog :: proc() -> b.Recovery_Catalog {
    config := b.recovery_config_default()
    config.profile = pf.PROFILE
    source := pf.assets()
    assets: [4]b.Recovery_Asset

    for a, i in source {
        assets[i] = {
            id     = a.id,
            kind   = b.Recovery_Asset_Kind(a.kind),
            a      = a.a,
            b      = a.b,
            radius = a.radius,
        }
    }

    result, status := b.recovery_catalog_create(config, assets[:])
    check(status)
    return result
}

game_rules :: proc(box: ^Box) -> bd.Digest {
    parameters: [8]u8

    for i in 0 ..< 4 {
        parameters[i] = u8(u32(box.rule_scale) >> uint(8 * i))
    }

    parameters[4] = u8(box.input_variant)
    digest, status := bd.hash_descriptors(
        "kit-physics-network-test-rules-v1",
        []bd.Descriptor {
            {"kit", transmute([]u8)#load("model.odin")},
            {"parameters", parameters[:]},
            {"shared-world", transmute([]u8)#load("../../replay_physics_net/fixture/fixture.odin")},
        },
    )
    assert(status == .None)
    return digest
}

Control_V2 :: struct {
    axis: i32,
    mode: u32,
}

Effect_Id :: struct {
    epoch, tick, key: u64,
}

script_control :: proc(tick: u64, player: u16) -> i32 {
    return i32((tick / u64(7 + player)) % 5) - 2
}

script_action :: proc(tick: u64, player: u16) -> Action {
    if player != 1 {
        return {}
    }

    kind: u32

    switch tick {
    case 24, 40, 160, 176, 392, 408:
        kind = 1
    case 32, 48, 168, 184, 400, 416:
        kind = 2
    case 80, 260:
        kind = 3
    case 84, 264:
        kind = 4
    case 96:
        kind = 5
    case 104:
        kind = 6
    }

    return {kind, kind != 0 ? u32(tick) : 0}
}

sample_control :: proc(user: rawptr, tick: u64, dst: rawptr) {
    box := cast(^Box)user
    axis := script_control(tick, u16(box.ses.me))

    if box.input_variant {
        (cast(^Control_V2)dst)^ = {axis, 1}
    } else {
        (cast(^Control)dst)^ = {axis}
    }
}

sample_action :: proc(user: rawptr, tick: u64, dst: rawptr) {
    box := cast(^Box)user
    (cast(^Action)dst)^ = script_action(tick, u16(box.ses.me))
}

validate_control :: proc(_: rawptr, value: rawptr) -> bool {
    return abs((cast(^Control)value).axis) <= 2
}

validate_control_v2 :: proc(_: rawptr, value: rawptr) -> bool {
    return abs((cast(^Control_V2)value).axis) <= 2 && (cast(^Control_V2)value).mode == 1
}

validate_action :: proc(_: rawptr, value: rawptr) -> bool {
    return (cast(^Action)value).kind <= 6
}

effect :: proc(user: rawptr, tick, key: u64, args: []u8) {
    box := cast(^Box)user
    assert(box.lane.world.presenting)
    id := Effect_Id{box.lane.world.epoch, tick, key}

    for old in box.effect_ids[:box.effect_count] {
        if old == id {
            box.duplicate_effects += 1
            assert(false, "duplicate stable effect")
        }
    }

    assert(box.effect_count < len(box.effect_ids))
    box.effect_ids[box.effect_count] = id
    box.effect_count += 1
    comm.reply("{\"event\":\"effect\",\"epoch\":%d,\"tick\":%d,\"kind\":1,\"key\":%d}", id.epoch, id.tick, id.key)
    box.effects += 1
}

step :: proc(user: rawptr, tick: u64) {
    box := cast(^Box)user
    comm.reply(
        "{\"event\":\"simulated\",\"command_serial\":%d,\"epoch\":%d,\"tick\":%d,\"staged_before\":%d}",
        box.command_serial,
        k.lane_world_epoch(&box.lane),
        tick,
        box.lane.world.staged_count,
    )
    assert(box.lane.world.staged_count <= 8, "observed correction stage beyond8")
    game := p.state(&box.physics)
    w, error := p.world(&box.physics)
    assert(error == .Ok)
    game.tick = tick
    game.rng = game.rng * 1664525 + 1013904223

    // Explicit negative control: intentionally violates the declared model
    // identity to prove first-divergence capture, never used by positive cases.
    if box.args.variant == "fault" && tick == 35 {
        if !p.require(&box.physics, b.world_set_gravity(w, {0, -9.75, 0})) {
            return
        }
    }

    for player in ([]n.Player_Id{1, 2}) {
        input: Control
        control_known: bool

        if box.input_variant {
            value, known := k.lane_input_of(&box.lane, player, Control_V2)
            input.axis = value.axis
            control_known = known
        } else {
            input, control_known = k.lane_input_of(&box.lane, player, Control)
        }

        action, action_known := k.lane_input_of(&box.lane, player, Action)
        comm.reply(
            "{\"event\":\"used_input\",\"epoch\":%d,\"tick\":%d,\"player\":%d,\"axis\":%d,\"control_known\":%t,\"action_kind\":%d,\"action_serial\":%d,\"action_known\":%t}",
            k.lane_world_epoch(&box.lane),
            tick,
            player,
            input.axis,
            control_known,
            action.kind,
            action.serial,
            action_known,
        )
        game.last_decision[int(player) - 1] = 0
        body, status := b.body_resolve(w, game.keys[0])
        check(status)

        if input.axis != 0 {
            if !p.require(&box.physics, b.body_apply_impulse(body, {f32(input.axis * box.rule_scale) * .002, 0, 0})) {
                return
            }
        }

        if action.kind != 0 && action.serial > game.last_action[int(player) - 1] {
            game.last_action[int(player) - 1] = action.serial

            if action.kind == 1 && !game.alive[game.initial] {
                def := b.body_def_default()
                def.type = .Dynamic
                def.pose.position = {0.1, 1, 0.1}
                born, status := b.body_create(w, def)

                if !p.require(&box.physics, status) {
                    return
                }

                shape := b.shape_def_default()
                shape.enable_sensor_events = 1
                shape_handle: b.Shape
                shape_handle, status = b.shape_sphere(born, shape, .25)

                if !p.require(&box.physics, status) {
                    return
                }

                game.extra_shape, status = b.shape_key(shape_handle)
                check(status)
                game.last_decision[int(player) - 1] = 1
                game.keys[game.initial], status = b.body_key(born)
                check(status)
                game.alive[game.initial] = true
                game.generation[game.initial] += 1
                game.births += 1
            }

            if action.kind == 2 && game.alive[game.initial] {
                game.pending_destroy = true
                game.last_decision[int(player) - 1] = 1
            }

            if action.kind == 3 || action.kind == 4 {
                body, status := b.body_resolve(w, game.keys[31])
                check(status)

                if !p.require(&box.physics, b.body_set_awake(body, action.kind == 4)) {
                    return
                }

                game.last_decision[int(player) - 1] = 1
            }

            if action.kind == 5 || action.kind == 6 {
                joint, status := b.joint_resolve(w, game.hinge)
                check(status)

                if !p.require(
                    &box.physics,
                    b.joint_hinge_set_motor(joint, true, action.kind == 5 ? f32(.25) : f32(-.25), 2),
                ) {
                    return
                }

                game.last_decision[int(player) - 1] = 1
            }

            if game.last_decision[int(player) - 1] == 1 {
                game.applied_actions += 1
            } else {
                game.last_decision[int(player) - 1] = 2
                game.rejected_actions += 1
            }

            assert(k.lane_world_emit(&box.lane, 100 + u64(player), effect, box) == .Ok)
        }
    }

    if tick % 5 == 0 {
        assert(k.lane_world_emit(&box.lane, 1, effect, box) == .Ok)
    }

    if box.fail {
        assert(p.network_destroy(&box.network) == .Busy)
        k.lane_world_fail(&box.lane, .Step_Failed)
    }
}

settle :: proc(user: rawptr, tick: u64) {
    box := cast(^Box)user
    game := p.state(&box.physics)
    w, error := p.world(&box.physics)
    assert(error == .Ok)
    obs, oe := p.sensor_observations(&box.physics)
    assert(oe == .Ok)
    counts, counts_status := b.world_counters(w)
    check(counts_status)
    box.last_counts = counts
    box.peak.body_count = max(box.peak.body_count, counts.body_count)
    box.peak.shape_count = max(box.peak.shape_count, counts.shape_count)
    box.peak.contact_count = max(box.peak.contact_count, counts.contact_count)
    box.peak.joint_count = max(box.peak.joint_count, counts.joint_count)

    for event in obs.events[:obs.count] {
        if event.began != 0 {
            game.begins += 1
        } else {
            game.ends += 1
        }

        if event.began == 0 && event.visitor == game.retired_shape && game.expected_end_tick != 0 {
            assert(tick == game.expected_end_tick && game.last_extra_end != tick, "pending end delivery exactly once")
            game.exact_extra_ends += 1
            game.last_extra_end = tick
        }
    }

    if game.expected_end_tick == tick {
        assert(game.last_extra_end == tick, "expected pending end absent")
    }

    if game.pending_destroy {
        body, status := b.body_resolve(w, game.keys[game.initial])
        check(status)

        if !p.require(&box.physics, b.body_destroy(&body)) {
            return
        }

        after, after_error := p.sensor_observations(&box.physics)
        assert(after_error == .Ok && after == obs, "completed cache retained across post-step destruction")
        assert(
            game.expected_end_tick == 0 || game.last_extra_end == game.expected_end_tick,
            "unfulfilled prior pending end",
        )
        game.retired_shape = game.extra_shape
        game.expected_end_tick = tick + 1
        game.alive[game.initial] = false
        game.keys[game.initial] = 0
        game.pending_destroy = false
        game.deaths += 1
    }

    for &proxy, i in box.proxies[:box.count] {
        body, status := b.body_resolve(w, game.keys[i])
        check(status)
        proxy.pose, status = b.body_get_pose(body)
        check(status)
        proxy.tick = tick
    }
}

setup :: proc(box: ^Box, count: int, cat: ^b.Recovery_Catalog) {
    box.count = count
    @(static) fields := []n.Field_Desc {
        {offset = offset_of(Proxy, pose), size = size_of(b.Pose), name = "pose", flags = {.Predicted}},
        {offset = offset_of(Proxy, tick), size = size_of(u64), name = "tick", flags = {.Predicted}},
    }
    box.desc = {
        fields = fields,
    }
    k.lane_init(
        &box.lane,
        &box.ses,
        box.input_variant ? size_of(Control_V2) : size_of(Control),
        cfg = {slots = 128, snap_every = 3},
    )
    k.lane_set_sim(&box.lane, box, sample_control, step)

    if box.input_variant {
        k.lane_class_set_type(&box.lane, 0, Control_V2)
        k.lane_class_set_validate(&box.lane, 0, validate_control_v2)
    } else {
        k.lane_class_set_type(&box.lane, 0, Control)
        k.lane_class_set_validate(&box.lane, 0, validate_control)
    }

    k.lane_add_input_class(&box.lane, 1, size_of(Action), sample_action)
    k.lane_class_set_type(&box.lane, 1, Action)
    k.lane_class_set_validate(&box.lane, 1, validate_action)
    types := make([]k.World_Field_Type, count, context.temp_allocator)

    for i in 0 ..< count {
        k.lane_track(&box.lane, n.Net_Id(i + 1), &box.proxies[i], &box.desc, box.ses.me)
        types[i] = k.world_field_type(n.Net_Id(i + 1), Proxy)
    }

    w, game := world(count)

    if box.initial_gravity {
        check(b.world_set_gravity(w, {0, -2, 0}))
    }

    if box.initial_side_delta {
        game.rng ~= 1
    }

    probe, probe_status := b.snapshot_capture(w)
    check(probe_status)
    _, write_status, diagnostic := b.recovery_write_diagnostic(cat, &probe, nil)

    if write_status != .Ok {
        fmt.eprintf(
            "KIT_NATIVE_WRITE status=%v section=%d record=%d field=%d reason=%d offset=%d\n",
            write_status,
            diagnostic.section,
            diagnostic.record,
            diagnostic.field,
            diagnostic.reason,
            diagnostic.offset,
        )
    }

    check(b.snapshot_destroy(&probe))
    assert(
        p.attach(
            &box.physics,
            &box.lane,
            &w,
            game,
            types,
            {asset_id = pf.ASSET_DECLARATION, additional_owned_bytes = comm.owned_bytes() + u64(size_of(Box))},
            settle,
        ) ==
        .Ok,
    )
    assert(p.codec_init(&box.control) == .Ok)
    assert(p.codec_init(&box.action) == .Ok)
    assert(p.codec_init(&box.proxy, &box.desc) == .Ok)

    if box.input_variant {
        assert(p.codec_init(&box.control_v2) == .Ok)
    }

    for i in 0 ..< count {
        box.fields[i] = {n.Net_Id(i + 1), box.proxy.value}
    }

    control_codec := box.input_variant ? box.control_v2.value : box.control.value
    inputs := []k.World_Wire_Input{{0, control_codec, .Hold}, {1, box.action.value, .Neutral}}
    drivers := []k.World_Driver{{1, 0}, {1, 1}, {2, 0}, {2, 1}}
    effects := []k.World_Effect_Def{{1, effect, box, p.empty_codec()}}
    error := p.network_attach(
        &box.network,
        &box.physics,
        cat,
        box.fields[:count],
        inputs,
        drivers,
        effects,
        game_rules(box),
        epoch = box.args.epoch,
    )

    if error != .Ok {
        fmt.eprintf("KIT_NETWORK_ATTACH error=%v count=%d\n", error, count)
    }

    assert(error == .Ok)
}

destroy :: proc(box: ^Box) {
    assert(p.network_destroy(&box.network) == .Ok)
    assert(p.detach(&box.physics) == .Ok)
    p.codec_destroy(&box.control_v2)
    p.codec_destroy(&box.control)
    p.codec_destroy(&box.action)
    p.codec_destroy(&box.proxy)
    k.lane_destroy(&box.lane)
    s.session_destroy(&box.ses)
}
