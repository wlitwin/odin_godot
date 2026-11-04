package replay_action_retire_test

// Generic four-body production-runner regression. Standalone Native/Memory,
// nil Owner/static linkage: NOT an actual-Core CPU/GateB/32-body result.
import "core:testing"
import "core:fmt"
import "core:mem"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import tr "godot:replay/transport"
import view "godot:replay/view"
import f "godot:tests/replay_physics_net/fixture"

Pair :: struct {
    catalog:   b.Recovery_Catalog,
    codec:     ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2),
    memory:    tr.Memory,
    endpoints: [2]tr.Memory_Endpoint,
    server:    net.Server(f.Game, f.Control, f.Action, f.Event, 2),
    client:    net.Client(f.Game, f.Control, f.Action, f.Event, 2),
}

ops :: proc(execution: ^r.Execution) -> f.Operations {
    return {execution = execution, impulse = proc(p: rawptr, key: b.Body_Key, v: b.Vec3) -> bool {
            return ph.body_impulse((cast(^r.Execution)p)^, key, v) == .None
        }, spawn = proc(p: rawptr, position: b.Vec3) -> (b.Body_Key, bool) {
            def := b.body_def_default()
            def.type = .Dynamic
            def.pose.position = position
            key, error := ph.spawn((cast(^r.Execution)p)^, 4, def)
            return key, error == .None
        }, remove = proc(p: rawptr, key: b.Body_Key) -> bool {
            return ph.body_destroy((cast(^r.Execution)p)^, key) == .None
        }, motor = proc(p: rawptr, key: b.Joint_Key, speed: f32) -> bool {
            return ph.hinge_motor((cast(^r.Execution)p)^, key, true, speed, 2) == .None
        }, step = proc(p: rawptr) -> bool {
            return ph.step((cast(^r.Execution)p)^) == .None
        }, observations = proc(p: rawptr, out: []f.Observation) -> (int, bool) {
            events: [70]ph.Sensor_Event
            count, error := ph.sensor_events((cast(^r.Execution)p)^, events[:])

            if error != .None || int(count) > len(out) {
                return 0, false
            }

            for event, index in events[:count] {
                out[index] = {event.sensor, event.visitor, event.began}
            }

            return int(count), true
        }}
}

step :: proc(game: ^f.Game, controls: [2]f.Control, joins, leaves: u64, ctx: ^r.Step(f.Event)) {
    execution := ctx.execution
    events: [70]f.Event
    count, ok := f.advance(game, controls, ops(&execution), events[:])

    if !ok {
        r.abort(ctx)
        return
    }

    for event in events[:count] {
        r.emit(ctx, u64(event.source), event.key, event)
    }
}

action :: proc(game: ^f.Game, seat: u16, value: f.Action, ctx: ^r.Step(f.Event)) -> bool {
    execution := ctx.execution
    return f.apply_action(game, seat, value, ops(&execution))
}

rules :: proc() -> bd.Digest {
    fixture := f.game_rules()
    callbacks := bd.hash_bytes(transmute([]u8)#load("action_retire_test.odin"))
    digest, error := bd.hash_descriptors(
        "replay-physical-action-retire-regression.v1",
        []bd.Descriptor{{tag = "callbacks", bytes = callbacks[:]}, {tag = "fixture", bytes = fixture[:]}},
    )
    assert(error == .None)
    return digest
}

none :: proc(t: ^testing.T, error: net.Error, label: string) -> bool {
    testing.expect_value(t, error, net.Error.None)

    if error != .None {
        fmt.printf("ACTION_RETIRE_SETUP label=%s error=%v\n", label, error)
        return false
    }

    return true
}

open :: proc(t: ^testing.T, p: ^Pair) -> bool {
    cfg := b.recovery_config_default()
    cfg.profile = f.PROFILE
    assets: [4]b.Recovery_Asset

    for a, index in f.assets() {
        assets[index] = {
            id     = a.id,
            kind   = b.Recovery_Asset_Kind(a.kind),
            a      = a.a,
            b      = a.b,
            radius = a.radius,
        }
    }

    status: b.Status
    p.catalog, status = b.recovery_catalog_create(cfg, assets[:])
    testing.expect_value(t, status, b.Status.Ok)

    if status != .Ok {
        return false
    }

    identity, is := b.recovery_catalog_identity(&p.catalog)

    if is != .Ok {
        return false
    }

    build: u64

    for byte, index in identity.build_target[:8] {
        build |= u64(byte) << uint(index * 8)
    }

    config := ph.config_default(f.ASSET_DECLARATION, build)
    config.initial_dynamic_bodies = 4
    config.assets[0].id = 3
    config.assets[1].id = 4
    world, game, ws := f.world(4)
    testing.expect_value(t, ws, b.Status.Ok)

    if ws != .Ok {
        return false
    }

    initial, error := ph.checkpoint_make(r.Frame(f.Game){state = game}, net.Net_Event(f.Event), world, config)
    b.world_destroy(&world)
    testing.expect_value(t, error, r.Error.None)

    if error != .None {
        return false
    }

    defer r.complete_checkpoint_destroy(&initial)

    if !none(t, ph.network_codec_init(&p.codec, &p.catalog, config, rules()), "codec") {
        return false
    }

    if !tr.memory_init(&p.memory, cfg = {2, 64, tr.MAX_PACKET_BYTES, 4096}) {
        return false
    }

    for &endpoint, index in p.endpoints {
        if !tr.memory_open(&p.memory, &endpoint, tr.Peer_Id(index + 1)) {
            return false
        }
    }

    model := net.Model(f.Game, f.Control, f.Action, f.Event, 2) {
        complete_state = true,
        complete_codec = p.codec.value,
        step = step,
        action = action,
        control_valid = f.control_valid,
        action_valid = f.action_valid,
        hold = f.hold,
        action_timing = .Receipt,
        state_valid = proc(game: f.Game) -> bool {
            return game.initial == 4
        },
    }
    network := net.physics_config_default()
    network.snapshot_every = 1

    if !none(
        t,
        net.server_init_complete(
            &p.server,
            &initial,
            model,
            tr.memory_transport(&p.endpoints[0]),
            network,
            local_seat = 1,
        ),
        "server",
    ) {
        return false
    }

    if !none(t, net.server_set_local_token(&p.server, net.Token{0 = 1}), "local token") {
        return false
    }

    if !none(
        t,
        net.client_init(&p.client, model, tr.memory_transport(&p.endpoints[1]), net.Token{0 = 2}, cfg = network),
        "client",
    ) {
        return false
    }

    if !none(t, net.client_pump(&p.client, 0), "Hello") {
        return false
    }

    tr.memory_advance(&p.memory, 0)

    if !none(t, net.server_pump(&p.server, 0), "receive Hello") || !none(t, net.server_step(&p.server), "membership") {
        return false
    }

    tr.memory_advance(&p.memory, 0)

    if !none(t, net.client_pump(&p.client, 0), "Welcome") {
        return false
    }

    tr.memory_advance(&p.memory, 0)

    if !none(t, net.server_pump(&p.server, 0), "real Welcome ACK") {
        return false
    }

    testing.expect_value(t, p.client.phase, net.Phase.Running)
    return p.client.phase == .Running
}

close :: proc(t: ^testing.T, p: ^Pair) {
    testing.expect_value(t, net.client_destroy(&p.client), net.Error.None)
    testing.expect_value(t, net.server_destroy(&p.server), net.Error.None)

    if len(p.memory.packets) != 0 {
        tr.memory_destroy(&p.memory)
    }

    if p.codec.ready {
        testing.expect_value(t, ph.network_codec_destroy(&p.codec), net.Error.None)
    }

    testing.expect_value(t, b.recovery_catalog_destroy(&p.catalog), b.Status.Ok)
    engine, es := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    owned := ph.allocation_stats()
    testing.expect(
        t,
        es == .Ok && ws == .Ok && engine.live_bytes == 0 && wrapper.live_bytes == 0 && owned.live_bytes == 0,
    )
    fmt.printf(
        "ACTION_RETIRE_CLEANUP native=%d wrapper=%d provider=%d owner_mode=nil_owner statuses=%v/%v\n",
        engine.live_bytes,
        wrapper.live_bytes,
        owned.live_bytes,
        es,
        ws,
    )
}

full_pair :: proc(t: ^testing.T, p: ^Pair, tick: u64) -> bool {
    a, ae := r.capture_complete(&p.server.timeline, tick)

    if ae != .None {
        return false
    }

    defer r.complete_checkpoint_destroy(&a)
    z, ze := r.capture_complete(&p.client.timeline, tick)

    if ze != .None {
        return false
    }

    defer r.complete_checkpoint_destroy(&z)
    av, ave := net.complete_view(
        p.codec.value,
        &a,
        &p.server.physics.schemas.state,
        &p.server.physics.schemas.occurrence,
    )

    if ave != .None {
        return false
    }

    defer net.complete_view_destroy(&av)
    zv, zve := net.complete_view(
        p.codec.value,
        &z,
        &p.client.physics.schemas.state,
        &p.client.physics.schemas.occurrence,
    )

    if zve != .None {
        return false
    }

    defer net.complete_view_destroy(&zv)
    asig, ase := bd.sign(av.frame)
    zsig, zse := bd.sign(zv.frame)
    equal := ase == .None && zse == .None && bd.compare(asig, zsig) == .Match

    for part in bd.Part {
        equal = equal && mem.compare(av.frame.parts[part], zv.frame.parts[part]) == 0
    }

    testing.expect(t, equal)
    return equal
}

@(test)
seventeenth_receipt_action_is_admitted_after_sixteen_settled_full_physics_snapshots :: proc(t: ^testing.T) {
    p := new(Pair)
    defer free(p)
    defer close(t, p)

    if !open(t, p) {
        return
    }

    fmt.println(
        "ACTION_RETIRE_META bodies=4 history=128 hz=60 substeps=4 native=real core=none ownership=nil_owner linkage=static_diagnostic authority=real_public_Server transport=Memory timing=NOT_MEASURED",
    )
    generation, serial := p.client.generation, p.client.serial
    changes: [512]view.Change(net.Net_Event(f.Event))
    view.drain(&p.client.journal, changes[:])

    for index in 1 ..= 40 {
        fmt.printf(
            "ACTION_RETIRE_BEFORE attempt=%d action_count=%d outcome_count=%d next_action=%d confirmed=%d generation=%d serial=%d\n",
            index,
            p.client.action_count,
            p.client.outcome_count,
            p.client.next_action,
            p.client.timeline.confirmed,
            p.client.generation,
            p.client.serial,
        )
        sequence, error := net.client_issue(&p.client, f.Action{kind = .Motor})
        // Original RED was here at17; continue40 without a new Welcome or resync.
        testing.expect_value(t, error, net.Error.None)
        fmt.printf(
            "ACTION_RETIRE_ISSUE attempt=%d sequence=%d status=%v action_count=%d outcome_count=%d\n",
            index,
            sequence,
            error,
            p.client.action_count,
            p.client.outcome_count,
        )

        if error != .None {
            return
        }

        if !none(t, net.client_step(&p.client, f.Control{}), "predict action") {
            return
        }

        now := u64(index) * 17
        tr.memory_advance(&p.memory, now)

        if !none(t, net.server_pump(&p.server, now), "receive Receipt action") ||
           !none(t, net.server_step(&p.server), "authoritative action") {
            return
        }

        tick := p.server.timeline.head
        entry, found := net.server_accepted_input(&p.server, tick)
        testing.expect(
            t,
            found && entry.batch.has_action[1] && entry.batch.sequences[1] == sequence && entry.decisions.applied[1],
        )

        if !found {
            return
        }

        compared := p.client.physics.verified_compares + p.client.physics.full_compares
        tr.memory_advance(&p.memory, now)

        if !none(t, net.client_pump(&p.client, now), "full physics confirmation") {
            return
        }

        testing.expect(
            t,
            p.client.timeline.confirmed >= tick &&
            p.client.pending.action_settled >= sequence &&
            p.client.physics.verified_compares + p.client.physics.full_compares > compared,
        )
        testing.expect_value(t, p.client.generation, generation)
        testing.expect_value(t, p.client.serial, serial)

        if !full_pair(t, p, tick) {
            return
        }

        view.drain(&p.client.journal, changes[:])
        outcomes: [net.ACTION_CAPACITY]net.Action_Outcome
        recovered: [net.ACTION_CAPACITY]bool
        drained := 0
        settled := false

        for {
            n := net.client_outcomes(&p.client, outcomes[:], recovered[:])

            if n == 0 {
                break
            }

            for outcome in outcomes[:n] {
                if outcome.sequence == sequence && outcome.applied && outcome.reason == .None {
                    settled = true
                }
            }

            drained += n
        }

        testing.expect(t, settled && drained > 0)
        testing.expect_value(t, p.client.outcome_count, 0)
        fmt.printf(
            "ACTION_RETIRE_SETTLED attempt=%d sequence=%d authority_tick=%d confirmed=%d header_action_settled=%d drained=%d action_count=%d outcome_count=%d full_pair=true generation=%d serial=%d\n",
            index,
            sequence,
            tick,
            p.client.timeline.confirmed,
            p.client.pending.action_settled,
            drained,
            p.client.action_count,
            p.client.outcome_count,
            p.client.generation,
            p.client.serial,
        )
        tr.memory_advance(&p.memory, now)

        if !none(t, net.server_pump(&p.server, now), "real Snapshot ACK") {
            return
        }
    }
}
