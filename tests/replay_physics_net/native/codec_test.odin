package replay_physics_native_net_test

import "core:testing"
import "core:mem"
import "core:fmt"
import "core:os"
import b "godot:box3d"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import v "godot:replay/view"
import bd "godot:box3d/diagnostics"
import tr "godot:replay/transport"
import f "../fixture"

TRACE_OUTPUT :: #config(REPLAY_PHYSICS_TRACE_OUTPUT, "")

network_rules :: proc() -> bd.Digest {
    fixture := f.game_rules()
    adapter := bd.hash_bytes(transmute([]u8)#load("codec_test.odin"))
    result, error := bd.hash_descriptors(
        "replay-physics-test-rules.v1",
        []bd.Descriptor{{tag = "adapter", bytes = adapter[:]}, {tag = "fixture", bytes = fixture[:]}},
    )
    assert(error == .None)
    return result
}

ops :: proc(execution: ^r.Execution) -> f.Operations {
    return {execution = execution, impulse = proc(pointer: rawptr, key: b.Body_Key, value: b.Vec3) -> bool {
            error := ph.body_impulse((cast(^r.Execution)pointer)^, key, value)

            if error != .None {
                fmt.printf("OPS_IMPULSE error=%v key=%v\n", error, key)
            }

            return error == .None
        }, spawn = proc(pointer: rawptr, position: b.Vec3) -> (b.Body_Key, bool) {
            def := b.body_def_default()
            def.type = .Dynamic
            def.pose.position = position
            key, error := ph.spawn((cast(^r.Execution)pointer)^, 4, def)
            return key, error == .None
        }, remove = proc(pointer: rawptr, key: b.Body_Key) -> bool {
            return ph.body_destroy((cast(^r.Execution)pointer)^, key) == .None
        }, motor = proc(pointer: rawptr, key: b.Joint_Key, speed: f32) -> bool {
            return ph.hinge_motor((cast(^r.Execution)pointer)^, key, true, speed, 2) == .None
        }, step = proc(pointer: rawptr) -> bool {
            error := ph.step((cast(^r.Execution)pointer)^)

            if error != .None {
                fmt.printf("OPS_STEP error=%v\n", error)
            }

            return error == .None
        }, observations = proc(pointer: rawptr, out: []f.Observation) -> (int, bool) {
            events: [70]ph.Sensor_Event
            count, error := ph.sensor_events((cast(^r.Execution)pointer)^, events[:])

            if error != .None || int(count) > len(out) {
                return 0, false
            }

            for event, index in events[:count] {
                out[index] = {event.sensor, event.visitor, event.began}
            }

            return int(count), true
        }}
}

model_step :: proc(game: ^f.Game, controls: [2]f.Control, joins, leaves: u64, ctx: ^r.Step(f.Event)) {
    execution := ctx.execution
    events: [70]f.Event
    count, success := f.advance(game, controls, ops(&execution), events[:])

    if !success {
        r.abort(ctx)
        return
    }

    for event in events[:count] {
        r.emit(ctx, u64(event.source), event.key, event)
    }
}

model_action :: proc(game: ^f.Game, seat: u16, action: f.Action, ctx: ^r.Step(f.Event)) -> bool {
    execution := ctx.execution
    return f.apply_action(game, seat, action, ops(&execution))
}

network_model :: proc(
    codec: ^ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2),
) -> net.Model(f.Game, f.Control, f.Action, f.Event, 2) {
    return {
        complete_state = true,
        complete_codec = codec.value,
        step = model_step,
        action = model_action,
        control_valid = f.control_valid,
        action_valid = f.action_valid,
        hold = f.hold,
        state_valid = proc(game: f.Game) -> bool {
            return game.initial >= 2 && game.initial <= 32
        },
    }
}

catalog_make :: proc(t: ^testing.T) -> b.Recovery_Catalog {
    config := b.recovery_config_default()
    config.profile = f.PROFILE
    assets: [4]b.Recovery_Asset

    for asset, index in f.assets() {
        assets[index] = {
            id     = asset.id,
            kind   = b.Recovery_Asset_Kind(asset.kind),
            a      = asset.a,
            b      = asset.b,
            radius = asset.radius,
        }
    }

    catalog, status := b.recovery_catalog_create(config, assets[:])
    testing.expect_value(t, status, b.Status.Ok)
    return catalog
}

config_make :: proc(catalog: ^b.Recovery_Catalog, count: u32) -> ph.Config {
    id, status := b.recovery_catalog_identity(catalog)
    assert(status == .Ok)
    build: u64

    for byte, index in id.build_target[:8] {
        build |= u64(byte) << uint(index * 8)
    }

    config := ph.config_default(f.ASSET_DECLARATION, build)
    config.initial_dynamic_bodies = count
    config.assets[0].id = 3
    config.assets[1].id = 4
    return config
}

@(test)
actual_canonical_attachment_roundtrips_primitive_profile_complete_image :: proc(t: ^testing.T) {
    catalog := catalog_make(t)
    defer b.recovery_catalog_destroy(&catalog)
    config := config_make(&catalog, 4)
    world, game, status := f.world(4)
    testing.expect_value(t, status, b.Status.Ok)
    checkpoint, error := ph.checkpoint_make(r.Frame(f.Game){state = game}, net.Net_Event(f.Event), world, config)
    testing.expect_value(t, error, r.Error.None)
    testing.expect_value(t, b.world_destroy(&world), b.Status.Ok)
    defer r.complete_checkpoint_destroy(&checkpoint)
    codec: ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(t, ph.network_codec_init(&codec, &catalog, config, network_rules()), net.Error.None)
    defer ph.network_codec_destroy(&codec)
    data, encode_error := net.complete_encode(
        codec.value,
        &checkpoint,
        .Snapshot,
        nil,
        &codec.state,
        &codec.occurrence,
    )
    testing.expect_value(t, encode_error, net.Error.None)

    if encode_error != .None {
        fmt.printf(
            "NATIVE_CODEC_REJECTION status=%v diagnostic=%v\n",
            codec.last_native_status,
            codec.last_native_diagnostic,
        )
        return
    }

    defer net.complete_data_destroy(&data)
    inspection, inspect_error := net.complete_inspect(data.bytes, codec.value.identity, 1)
    testing.expect_value(t, inspect_error, net.Error.None)
    decoded, decode_error := net.complete_decode_image(
        codec.value,
        inspection,
        checkpoint.frame,
        &codec.state,
        &codec.occurrence,
    )
    testing.expect_value(t, decode_error, net.Error.None)
    defer r.complete_checkpoint_destroy(&decoded)
    n, ne := ph.dump(&checkpoint, nil)
    testing.expect_value(t, ne, r.Error.None)
    m, me := ph.dump(&decoded, nil)
    testing.expect_value(t, me, r.Error.None)
    testing.expect_value(t, n, m)
    left, right := make([]u8, int(n)), make([]u8, int(m))
    defer delete(left)
    defer delete(right)
    _, le := ph.dump(&checkpoint, left)
    _, re := ph.dump(&decoded, right)
    testing.expect(t, le == .None && re == .None && mem.compare(left, right) == 0)
}

@(test)
existing_server_initializes_and_steps_actual_complete_model :: proc(t: ^testing.T) {
    catalog := catalog_make(t)
    defer b.recovery_catalog_destroy(&catalog)
    config := config_make(&catalog, 4)
    world, game, status := f.world(4)
    testing.expect_value(t, status, b.Status.Ok)
    checkpoint, error := ph.checkpoint_make(r.Frame(f.Game){state = game}, net.Net_Event(f.Event), world, config)
    testing.expect_value(t, error, r.Error.None)
    defer r.complete_checkpoint_destroy(&checkpoint)
    testing.expect_value(t, b.world_destroy(&world), b.Status.Ok)
    codec: ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(t, ph.network_codec_init(&codec, &catalog, config, network_rules()), net.Error.None)
    defer ph.network_codec_destroy(&codec)
    server: net.Server(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(
        t,
        net.server_init_complete(&server, &checkpoint, network_model(&codec), {}, net.physics_config_default()),
        net.Error.None,
    )
    defer net.server_destroy(&server)
    testing.expect_value(t, net.server_step(&server), net.Error.None)
    current, found := r.current_values(&server.timeline)
    testing.expect(t, found && current.tick == 1 && current.state.tick == 1)
}

@(test)
actual_existing_server_client_join_and_accepted_history_converge :: proc(t: ^testing.T) {
    catalog := catalog_make(t)
    defer b.recovery_catalog_destroy(&catalog)
    config := config_make(&catalog, 4)
    world, game, status := f.world(4)
    testing.expect_value(t, status, b.Status.Ok)
    checkpoint, error := ph.checkpoint_make(r.Frame(f.Game){state = game}, net.Net_Event(f.Event), world, config)
    testing.expect_value(t, error, r.Error.None)
    defer r.complete_checkpoint_destroy(&checkpoint)
    testing.expect_value(t, b.world_destroy(&world), b.Status.Ok)
    codec: ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(t, ph.network_codec_init(&codec, &catalog, config, network_rules()), net.Error.None)
    defer ph.network_codec_destroy(&codec)
    m := network_model(&codec)
    cfg := net.physics_config_default()
    memory: tr.Memory
    testing.expect(t, tr.memory_init(&memory, cfg = {2, 64, tr.MAX_PACKET_BYTES, 2048}))
    defer tr.memory_destroy(&memory)
    a, z: tr.Memory_Endpoint
    testing.expect(t, tr.memory_open(&memory, &a, 1))
    testing.expect(t, tr.memory_open(&memory, &z, 2))
    server: net.Server(f.Game, f.Control, f.Action, f.Event, 2)
    client: net.Client(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(
        t,
        net.server_init_complete(&server, &checkpoint, m, tr.memory_transport(&a), cfg, local_seat = 1),
        net.Error.None,
    )
    defer net.server_destroy(&server)
    server_token, client_token: net.Token
    server_token[0] = 1
    client_token[0] = 2
    testing.expect_value(t, net.server_set_local_token(&server, server_token), net.Error.None)
    testing.expect_value(
        t,
        net.client_init(&client, m, tr.memory_transport(&z), client_token, cfg = cfg),
        net.Error.None,
    )
    defer net.client_destroy(&client)
    testing.expect_value(t, net.client_pump(&client, 0), net.Error.None)
    tr.memory_advance(&memory, 0)
    testing.expect_value(t, net.server_pump(&server, 0), net.Error.None)
    testing.expect_value(t, net.server_step(&server), net.Error.None)
    testing.expect_value(t, net.server_pump(&server, 0), net.Error.None)
    tr.memory_advance(&memory, 0)
    testing.expect_value(t, net.client_pump(&client, 0), net.Error.None)
    fmt.printf(
        "PHYSICS_JOIN phase=%v head=%d server=%d rejected=%d\n",
        client.phase,
        client.timeline.head,
        server.timeline.head,
        client.stats.rejected_packets,
    )
    testing.expect_value(t, client.phase, net.Phase.Running)

    for tick in 2 ..= 30 {
        testing.expect_value(t, net.client_step(&client, f.Control{x = tick % 2 == 0 ? 20 : -20}), net.Error.None)
        now := u64(tick * 16)
        tr.memory_advance(&memory, u64(tick))
        testing.expect_value(t, net.server_pump(&server, now), net.Error.None)
        testing.expect_value(t, net.server_step(&server), net.Error.None)
        testing.expect_value(t, net.server_pump(&server, now), net.Error.None)
        tr.memory_advance(&memory, u64(tick))
        testing.expect_value(t, net.client_pump(&client, now), net.Error.None)

        if client.phase != .Running {
            fmt.printf(
                "PHYSICS_STOP tick=%d phase=%v waiting=%d rejected=%d inputs=%d head=%d confirmed=%d server=%d\n",
                tick,
                client.phase,
                client.physics.waiting_tick,
                client.stats.rejected_packets,
                client.stats.rejected_inputs,
                client.timeline.head,
                client.timeline.confirmed,
                server.timeline.head,
            )
            break
        }
    }

    testing.expect(t, client.phase == .Running && client.timeline.confirmed > 20)
    confirmed := client.timeline.confirmed
    left, le := r.capture_complete(&server.timeline, confirmed)
    testing.expect_value(t, le, r.Error.None)
    defer r.complete_checkpoint_destroy(&left)
    right, re := r.capture_complete(&client.timeline, confirmed)
    testing.expect_value(t, re, r.Error.None)
    defer r.complete_checkpoint_destroy(&right)
    ln, _ := ph.dump(&left, nil)
    rn, _ := ph.dump(&right, nil)
    testing.expect_value(t, ln, rn)
    lbytes, rbytes := make([]u8, int(ln)), make([]u8, int(rn))
    defer delete(lbytes)
    defer delete(rbytes)
    _, ld := ph.dump(&left, lbytes)
    _, rd := ph.dump(&right, rbytes)
    testing.expect(t, ld == .None && rd == .None && mem.compare(lbytes, rbytes) == 0)
}

@(test)
complete_archive_detaches_and_resumes_existing_authority :: proc(t: ^testing.T) {
    catalog := catalog_make(t)
    defer b.recovery_catalog_destroy(&catalog)
    config := config_make(&catalog, 4)
    world, game, status := f.world(4)
    testing.expect_value(t, status, b.Status.Ok)
    initial, error := ph.checkpoint_make(r.Frame(f.Game){state = game}, net.Net_Event(f.Event), world, config)
    testing.expect_value(t, error, r.Error.None)
    defer r.complete_checkpoint_destroy(&initial)
    testing.expect_value(t, b.world_destroy(&world), b.Status.Ok)
    codec: ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(t, ph.network_codec_init(&codec, &catalog, config, network_rules()), net.Error.None)
    defer ph.network_codec_destroy(&codec)
    model := network_model(&codec)
    cfg := net.physics_config_default()
    source, resumed: net.Server(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(
        t,
        net.server_init_complete(&source, &initial, model, {}, cfg, local_seat = 1),
        net.Error.None,
    )
    defer net.server_destroy(&source)
    defer net.server_destroy(&resumed)
    testing.expect_value(t, net.server_set_local_token(&source, net.Token{0 = 9}), net.Error.None)

    for _ in 0 ..< 12 {
        testing.expect_value(t, net.server_step(&source), net.Error.None)
    }

    archive, decoded: net.Checkpoint(f.Game, f.Control, f.Action, 2)
    testing.expect_value(t, net.checkpoint_capture(&source, &archive), net.Error.None)
    defer net.checkpoint_destroy(&archive)
    defer net.checkpoint_destroy(&decoded)
    encoded, encode_error := net.checkpoint_encode_owned(&archive, model)
    testing.expect_value(t, encode_error, net.Error.None)
    defer net.complete_data_destroy(&encoded)
    testing.expect_value(t, net.checkpoint_decode(&decoded, encoded.bytes, model, cfg.content), net.Error.None)
    testing.expect_value(
        t,
        net.server_restore(
            &resumed,
            &decoded,
            model,
            {},
            {epoch = cfg.epoch + 1, local_seat = 1, retain_membership = true, preserve_pending = true},
        ),
        net.Error.None,
    )

    for _ in 0 ..< 24 {
        testing.expect_value(t, net.server_step(&source), net.Error.None)
        testing.expect_value(t, net.server_step(&resumed), net.Error.None)
        left, le := r.capture_complete(&source.timeline, source.timeline.head)
        right, re := r.capture_complete(&resumed.timeline, resumed.timeline.head)
        testing.expect(t, le == .None && re == .None)
        ln, _ := ph.dump(&left, nil)
        rn, _ := ph.dump(&right, nil)
        testing.expect_value(t, ln, rn)
        lb, rb := make([]u8, int(ln)), make([]u8, int(rn))
        ph.dump(&left, lb)
        ph.dump(&right, rb)
        testing.expect_value(t, mem.compare(lb, rb), 0)
        testing.expect_value(t, left.frame.state, right.frame.state)
        delete(lb)
        delete(rb)
        r.complete_checkpoint_destroy(&left)
        r.complete_checkpoint_destroy(&right)
    }
}

@(test)
eight_body_late_join_replays_shared_actions_under_bounded_network_faults :: proc(t: ^testing.T) {
    catalog := catalog_make(t)
    defer b.recovery_catalog_destroy(&catalog)
    config := config_make(&catalog, 8)
    world, game, status := f.world(8)
    testing.expect_value(t, status, b.Status.Ok)
    initial, error := ph.checkpoint_make(r.Frame(f.Game){state = game}, net.Net_Event(f.Event), world, config)
    testing.expect_value(t, error, r.Error.None)
    defer r.complete_checkpoint_destroy(&initial)
    testing.expect_value(t, b.world_destroy(&world), b.Status.Ok)
    codec: ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(t, ph.network_codec_init(&codec, &catalog, config, network_rules()), net.Error.None)
    defer ph.network_codec_destroy(&codec)
    model := network_model(&codec)
    cfg := net.physics_config_default()
    memory: tr.Memory
    testing.expect(t, tr.memory_init(&memory, cfg = {2, 128, tr.MAX_PACKET_BYTES, 8192}))
    defer tr.memory_destroy(&memory)
    a, z: tr.Memory_Endpoint
    testing.expect(t, tr.memory_open(&memory, &a, 1))
    testing.expect(t, tr.memory_open(&memory, &z, 2))
    server: net.Server(f.Game, f.Control, f.Action, f.Event, 2)
    client: net.Client(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(
        t,
        net.server_init_complete(&server, &initial, model, tr.memory_transport(&a), cfg, local_seat = 1),
        net.Error.None,
    )
    defer net.server_destroy(&server)
    defer net.client_destroy(&client)
    testing.expect_value(t, net.server_set_local_token(&server, net.Token{0 = 1}), net.Error.None)

    for _ in 0 ..< 40 {
        testing.expect_value(t, net.server_step(&server), net.Error.None)
    }

    testing.expect_value(
        t,
        net.client_init(&client, model, tr.memory_transport(&z), net.Token{0 = 2}, cfg = cfg),
        net.Error.None,
    )
    testing.expect(
        t,
        tr.memory_set_faults(
            &memory,
            {latency_ticks = 1, jitter_ticks = 1, loss_permyriad = 400, duplicate_permyriad = 1000, retry_ticks = 1},
        ),
    )
    running := 0

    for tick in 1 ..= 180 {
        tr.memory_advance(&memory, u64(tick))
        now := u64(tick) * 1000 / 60

        if client.phase == .Running {
            running += 1

            if running == 8 || running == 9 || running == 35 {
                _, issue_error := net.client_issue(&client, f.Action{kind = running == 35 ? .Remove : .Spawn})
                testing.expect_value(t, issue_error, net.Error.None)
            }

            step_error := net.client_step(&client, f.Control{x = tick % 2 == 0 ? 20 : -20, z = 10})
            testing.expect(t, step_error == .None || step_error == .Capacity)
        }

        if tick == 25 || tick == 26 || tick == 65 || tick == 85 {
            _, issue_error := net.server_issue(
                &server,
                f.Action{kind = tick == 65 ? .Remove : tick == 85 ? .Motor : .Spawn},
            )
            testing.expect_value(t, issue_error, net.Error.None)
        }

        testing.expect_value(t, net.server_local(&server, f.Control{x = tick % 3 == 0 ? 10 : -10}), net.Error.None)
        testing.expect_value(t, net.server_pump(&server, now), net.Error.None)
        testing.expect_value(t, net.server_step(&server), net.Error.None)
        testing.expect_value(t, net.server_pump(&server, now), net.Error.None)
        pump_error := net.client_pump(&client, now)
        testing.expect_value(t, pump_error, net.Error.None)

        if pump_error != .None {
            fmt.printf(
                "PHYSICS_OP_FAIL tick=%d error=%v client=%v server=%v provider=%v\n",
                tick,
                pump_error,
                client.physics.last_frame_error,
                server.frame_error,
                ph.allocation_stats(),
            )
            break
        }

        journal_changes: [2048]v.Change(net.Net_Event(f.Event))
        v.drain(&client.journal, journal_changes[:])

        if client.phase == .Failed || client.phase == .Rejected {
            fmt.printf(
                "PHYSICS_FAULT_FAIL tick=%d phase=%v waiting=%d confirmed=%d head=%d server=%d rejected=%d inputs=%d native=%v diag=%v\n",
                tick,
                client.phase,
                client.physics.waiting_tick,
                client.timeline.confirmed,
                client.timeline.head,
                server.timeline.head,
                client.stats.rejected_packets,
                server.stats.rejected_inputs,
                codec.last_native_status,
                codec.last_native_diagnostic,
            )
            break
        }
    }

    fmt.printf(
        "PHYSICS_FAULT_RESULT phase=%v running=%d repairs=%d confirmed=%d head=%d server=%d resync=%d trace=%v rejected=%d/%d\n",
        client.phase,
        running,
        client.physics.repairs,
        client.timeline.confirmed,
        client.timeline.head,
        server.timeline.head,
        client.stats.resyncs,
        client.physics.trace.ready,
        client.stats.rejected_packets,
        server.stats.rejected_inputs,
    )
    testing.expect(
        t,
        running > 100 &&
        client.phase == .Running &&
        client.timeline.confirmed > 160 &&
        client.physics.repairs > 10 &&
        !client.physics.trace.ready,
    )
    tick := client.timeline.confirmed
    left, le := r.capture_complete(&server.timeline, tick)
    right, re := r.capture_complete(&client.timeline, tick)
    testing.expect(t, le == .None && re == .None)
    defer r.complete_checkpoint_destroy(&left)
    defer r.complete_checkpoint_destroy(&right)
    lv, lve := net.complete_view(codec.value, &left, &codec.state, &codec.occurrence)
    rv, rve := net.complete_view(codec.value, &right, &codec.state, &codec.occurrence)
    testing.expect(t, lve == .None && rve == .None)
    defer net.complete_view_destroy(&lv)
    defer net.complete_view_destroy(&rv)
    ls, _ := bd.sign(lv.frame)
    rs, _ := bd.sign(rv.frame)
    testing.expect_value(t, bd.compare(ls, rs), bd.Difference.Match)
}

@(test)
true_same_history_solver_divergence_retains_first_full_trace :: proc(t: ^testing.T) {
    catalog := catalog_make(t)
    defer b.recovery_catalog_destroy(&catalog)
    config := config_make(&catalog, 4)
    world, game, status := f.world(4)
    testing.expect_value(t, status, b.Status.Ok)
    initial, error := ph.checkpoint_make(r.Frame(f.Game){state = game}, net.Net_Event(f.Event), world, config)
    testing.expect_value(t, error, r.Error.None)
    defer r.complete_checkpoint_destroy(&initial)
    b.world_destroy(&world)
    codec: ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(t, ph.network_codec_init(&codec, &catalog, config, network_rules()), net.Error.None)
    defer ph.network_codec_destroy(&codec)
    server_model := network_model(&codec)
    client_model := server_model
    // Deliberately violate the declared identical model contract after bootstrap.
    // Only solver state changes: Game/events/completed observations remain equal.
    fault := false
    server_model.user = &fault
    server_model.step = proc(game: ^f.Game, controls: [2]f.Control, joins, leaves: u64, ctx: ^r.Step(f.Event)) {
        model_step(game, controls, joins, leaves, ctx)

        if (cast(^bool)ctx.user)^ {
            ph.body_impulse(ctx.execution, game.bodies[3], {0.01, 0, 0})
        }
    }
    cfg := net.physics_config_default()
    cfg.snapshot_every = 8
    memory: tr.Memory
    testing.expect(t, tr.memory_init(&memory, cfg = {2, 64, tr.MAX_PACKET_BYTES, 2048}))
    defer tr.memory_destroy(&memory)
    a, z: tr.Memory_Endpoint
    tr.memory_open(&memory, &a, 1)
    tr.memory_open(&memory, &z, 2)
    server: net.Server(f.Game, f.Control, f.Action, f.Event, 2)
    client: net.Client(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(
        t,
        net.server_init_complete(&server, &initial, server_model, tr.memory_transport(&a), cfg, local_seat = 1),
        net.Error.None,
    )
    defer net.server_destroy(&server)
    testing.expect_value(t, net.server_set_local_token(&server, net.Token{0 = 1}), net.Error.None)
    testing.expect_value(
        t,
        net.client_init(&client, client_model, tr.memory_transport(&z), net.Token{0 = 2}, cfg = cfg),
        net.Error.None,
    )
    defer net.client_destroy(&client)

    for tick in 0 ..= 24 {
        tr.memory_advance(&memory, u64(tick))
        now := u64(tick) * 16

        if client.phase == .Running {
            step_error := net.client_step(&client, f.Control{})
            testing.expect(t, step_error == .None || step_error == .Capacity)
        }

        if tick == 8 {
            fault = true
        }

        testing.expect_value(t, net.server_pump(&server, now), net.Error.None)
        testing.expect_value(t, net.server_step(&server), net.Error.None)
        tr.memory_advance(&memory, u64(tick))
        testing.expect_value(t, net.client_pump(&client, now), net.Error.None)

        if client.physics.trace.ready {
            break
        }
    }

    trace := &client.physics.trace
    testing.expect(t, client.phase == .Failed && trace.ready)

    if !trace.ready {
        fmt.printf(
            "TRACE_MISSING phase=%v waiting=%d confirmed=%d rejected=%d\n",
            client.phase,
            client.physics.waiting_tick,
            client.timeline.confirmed,
            client.stats.rejected_packets,
        )
        return
    }

    testing.expect_value(t, trace.difference, bd.Difference.Solver)

    for part in ([?]bd.Part{.Game, .Side, .Observations, .Occurrences}) {
        testing.expect_value(t, mem.compare(trace.expected_frame.parts[part], trace.actual_frame.parts[part]), 0)
    }

    testing.expect(t, len(trace.input_context.accepted_inputs) > 4 && len(trace.input_context.predicted_inputs) > 4)
    n, encode_error := bd.trace_encode(trace, nil)
    testing.expect_value(t, encode_error, bd.Error.None)
    bytes := make([]u8, n)
    defer delete(bytes)
    _, encode_error = bd.trace_encode(trace, bytes)
    testing.expect_value(t, encode_error, bd.Error.None)

    if len(TRACE_OUTPUT) != 0 {
        testing.expect_value(t, os.write_entire_file(TRACE_OUTPUT, bytes), os.ERROR_NONE)
    }

    fmt.printf(
        "PHYSICS_FIRST_TRACE tick=%d difference=%v offset=%d bytes=%d\n",
        trace.expected.tick,
        trace.difference,
        trace.first_byte,
        n,
    )
}
