package snapshot_signature_reuse_test

import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import net "godot:replay/net"
import ph "godot:replay/physics"
import tr "godot:replay/transport"
import f "godot:tests/replay_physics_net/fixture"
import n "godot:tests/replay_physics_net/native"

original_diagnostic: proc(
    _: rawptr,
    _: ^r.Complete_Checkpoint(f.Game, net.Net_Event(f.Event)),
    _: bd.Part,
    _: []u8,
) -> (
    int,
    net.Error,
)
counting: bool
fail_solver: bool
solver_fills: u64

counted_diagnostic :: proc(
    catalog: rawptr,
    checkpoint: ^r.Complete_Checkpoint(f.Game, net.Net_Event(f.Event)),
    part: bd.Part,
    dst: []u8,
) -> (
    int,
    net.Error,
) {
    if counting && part == .Solver && len(dst) > 0 {
        solver_fills += 1
    }

    if fail_solver && part == .Solver {
        return 0, .Capacity
    }

    return original_diagnostic(catalog, checkpoint, part, dst)
}

@(test)
facts_reuse_current_owned_snapshot_signature_without_extra_checkpoint :: proc(t: ^testing.T) {
    before, bs := b.engine_allocation_stats()
    wrapper_before, ws := b.snapshot_allocation_stats()
    owned_before := ph.allocation_stats()
    testing.expect(t, bs == .Ok && ws == .Ok)
    exercise(t, false)
    exercise(t, true)
    exercise(t, false, 2)
    after, as := b.engine_allocation_stats()
    wrapper_after, was := b.snapshot_allocation_stats()
    owned_after := ph.allocation_stats()
    testing.expect(t, as == .Ok && was == .Ok)
    testing.expect_value(t, after.live_bytes, before.live_bytes)
    testing.expect_value(t, wrapper_after.live_bytes, wrapper_before.live_bytes)
    testing.expect_value(t, owned_after.live_bytes, owned_before.live_bytes)
}

exercise :: proc(t: ^testing.T, with_observer: bool, cadence: u32 = 1) {
    defer {
        counting = false
        fail_solver = false
        original_diagnostic = nil
    }

    catalog := n.catalog_make(t)
    defer b.recovery_catalog_destroy(&catalog)
    config := n.config_make(&catalog, 4)
    world, game, status := f.world(4)

    if !testing.expect_value(t, status, b.Status.Ok) {
        return
    }

    checkpoint, error := ph.checkpoint_make(r.Frame(f.Game){state = game}, net.Net_Event(f.Event), world, config)
    testing.expect_value(t, b.world_destroy(&world), b.Status.Ok)

    if !testing.expect_value(t, error, r.Error.None) {
        return
    }

    defer r.complete_checkpoint_destroy(&checkpoint)
    codec: ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2)

    if !testing.expect_value(t, ph.network_codec_init(&codec, &catalog, config, n.network_rules()), net.Error.None) {
        return
    }

    defer ph.network_codec_destroy(&codec)
    original_diagnostic = codec.value.diagnostic_part
    model := n.network_model(&codec)
    model.complete_codec.diagnostic_part = counted_diagnostic
    cfg := net.physics_config_default()
    cfg.snapshot_every = cadence
    memory: tr.Memory

    if !testing.expect(t, tr.memory_init(&memory, cfg = {3, 64, tr.MAX_PACKET_BYTES, 2048})) {
        return
    }

    defer tr.memory_destroy(&memory)
    a, z, w: tr.Memory_Endpoint

    if !testing.expect(t, tr.memory_open(&memory, &a, 1) && tr.memory_open(&memory, &z, 2)) {
        return
    }

    server: net.Server(f.Game, f.Control, f.Action, f.Event, 2)
    client: net.Client(f.Game, f.Control, f.Action, f.Event, 2)

    if !testing.expect_value(
        t,
        net.server_init_complete(&server, &checkpoint, model, tr.memory_transport(&a), cfg, local_seat = 1),
        net.Error.None,
    ) {
        return
    }

    defer net.server_destroy(&server)
    host_token, guest_token: net.Token
    host_token[0] = 1
    guest_token[0] = 2

    if !testing.expect_value(t, net.server_set_local_token(&server, host_token), net.Error.None) {
        return
    }

    if !testing.expect_value(
        t,
        net.client_init(&client, model, tr.memory_transport(&z), guest_token, cfg = cfg),
        net.Error.None,
    ) {
        return
    }

    defer net.client_destroy(&client)

    if !testing.expect_value(t, net.client_pump(&client, 0), net.Error.None) ||
       !testing.expect(t, tr.memory_advance(&memory, 0)) ||
       !testing.expect_value(t, net.server_pump(&server, 0), net.Error.None) ||
       !testing.expect_value(t, net.server_step(&server), net.Error.None) {
        return
    }

    for _ in 0 ..< 8 {
        if !testing.expect(t, tr.memory_advance(&memory, 0)) ||
           !testing.expect_value(t, net.client_pump(&client, 0), net.Error.None) ||
           !testing.expect(t, tr.memory_advance(&memory, 0)) ||
           !testing.expect_value(t, net.server_pump(&server, 0), net.Error.None) {
            return
        }
    }

    if !testing.expect(t, client.phase == .Running && server.timeline.head == 1 && client.timeline.confirmed == 1) {
        return
    }

    observer: net.Client(f.Game, f.Control, f.Action, f.Event, 2)

    defer if observer.initialized {
        net.client_destroy(&observer)
    }

    if with_observer {
        if !testing.expect(t, tr.memory_open(&memory, &w, 3)) {
            return
        }

        token: net.Token
        token[0] = 3

        if !testing.expect_value(
            t,
            net.client_init(&observer, model, tr.memory_transport(&w), token, spectator = true, cfg = cfg),
            net.Error.None,
        ) {
            return
        }

        if !testing.expect_value(t, net.client_pump(&observer, 0), net.Error.None) ||
           !testing.expect(t, tr.memory_advance(&memory, 0)) ||
           !testing.expect_value(t, net.server_pump(&server, 0), net.Error.None) ||
           !testing.expect_value(t, net.server_step(&server), net.Error.None) {
            return
        }

        for _ in 0 ..< 8 {
            if !testing.expect(t, tr.memory_advance(&memory, 0)) ||
               !testing.expect_value(t, net.client_pump(&client, 0), net.Error.None) ||
               !testing.expect_value(t, net.client_pump(&observer, 0), net.Error.None) ||
               !testing.expect(t, tr.memory_advance(&memory, 0)) ||
               !testing.expect_value(t, net.server_pump(&server, 0), net.Error.None) {
                return
            }
        }

        if !testing.expect(
            t,
            observer.phase == .Running && observer.spectator && observer.timeline.confirmed == server.timeline.head,
        ) {
            return
        }
    }

    tick := server.timeline.head + 1
    expected_snapshots := 0

    for peer in server.peers {
        if !peer.local && peer.phase == .Running && tick - peer.snapshot_sent >= u64(cadence) {
            expected_snapshots += 1
        }
    }

    if !testing.expect_value(t, net.client_step(&client, f.Control{}), net.Error.None) ||
       !testing.expect_value(t, net.server_local(&server, f.Control{x = 20}), net.Error.None) {
        return
    }

    solver_fills = 0
    counting = true
    step_error := net.server_step(&server)
    counting = false

    if !testing.expect_value(t, step_error, net.Error.None) {
        return
    }

    testing.expect_value(t, solver_fills, with_observer ? u64(2) : u64(1))
    found := 0
    first_signature: bd.Signature

    for tx in server.physics.tx {
        if tx.tick != tick || tx.purpose != .Snapshot || len(tx.data.bytes) == 0 {
            continue
        }

        found += 1
        inspection, inspect_error := net.complete_inspect(tx.data.bytes, codec.value.identity, 1)

        if !testing.expect_value(t, inspect_error, net.Error.None) {
            return
        }

        truth, capture_error := r.capture_complete(&server.timeline, tick)

        if !testing.expect_value(t, capture_error, r.Error.None) {
            return
        }

        defer r.complete_checkpoint_destroy(&truth)
        view, view_error := net.complete_view(
            codec.value,
            &truth,
            &server.physics.schemas.state,
            &server.physics.schemas.occurrence,
        )

        if !testing.expect_value(t, view_error, net.Error.None) {
            return
        }

        defer net.complete_view_destroy(&view)
        signature, sign_error := bd.sign(view.frame)
        first_signature = signature
        testing.expect_value(t, sign_error, bd.Error.None)
        testing.expect(t, bd.compare(inspection.signature, signature) == .Match)

        for part in bd.Part {
            testing.expect_value(t, string(inspection.frame.parts[part]), string(view.frame.parts[part]))
        }

        fresh, fresh_error := net.complete_encode(
            codec.value,
            &truth,
            .Snapshot,
            inspection.metadata,
            &server.physics.schemas.state,
            &server.physics.schemas.occurrence,
        )

        if !testing.expect_value(t, fresh_error, net.Error.None) {
            return
        }

        defer net.complete_data_destroy(&fresh)
        testing.expect_value(t, string(tx.data.bytes), string(fresh.bytes))
    }

    testing.expect_value(t, found, expected_snapshots)

    // Corrupt only the saved local signature after valid snapshot chunks were
    // copied into the real transport. Re-emitting its fact must fall back to a
    // fresh normative signature, never trust the corrupted header.
    if found > 0 {
        for &tx, index in server.physics.tx {
            if tx.tick == tick && len(tx.data.bytes) >= net.COMPLETE_HEADER_BYTES {
                tx.data.bytes[32] = 0
                server.peers[index].facts_sent = tick - 1
            }
        }

        solver_fills = 0
        counting = true
        fallback_error := net.server_pump(&server, 0)
        counting = false

        if !testing.expect_value(t, fallback_error, net.Error.None) {
            return
        }

        testing.expect_value(t, solver_fills, with_observer ? u64(2) : u64(1))
    }

    for _ in 0 ..< 8 {
        if !testing.expect(t, tr.memory_advance(&memory, 0)) ||
           !testing.expect_value(t, net.client_pump(&client, 0), net.Error.None) ||
           !testing.expect(t, tr.memory_advance(&memory, 0)) ||
           !testing.expect_value(t, net.server_pump(&server, 0), net.Error.None) {
            return
        }

        if with_observer {
            if !testing.expect_value(t, net.client_pump(&observer, 0), net.Error.None) {
                return
            }
        }
    }

    testing.expect(t, client.timeline.confirmed >= tick, "actual public receiver confirms the signed state")

    if with_observer {
        testing.expect(t, observer.timeline.confirmed >= tick, "actual observer confirms the same signed state")
    }

    // A failure in the next tick cannot publish an unfinished or stale view.
    fail_solver = true

    if !testing.expect_value(t, net.server_local(&server, f.Control{x = -20}), net.Error.None) ||
       !testing.expect_value(t, net.server_step(&server), net.Error.None) {
        return
    }

    for tx in server.physics.tx {
        testing.expect_value(t, len(tx.data.bytes), 0)
    }

    fail_solver = false
    solver_fills = 0
    counting = true
    pump_error := net.server_pump(&server, 1)
    counting = false

    if !testing.expect_value(t, pump_error, net.Error.None) {
        return
    }

    testing.expect_value(t, solver_fills, with_observer ? u64(2) : u64(1))
    resumed := false

    for tx in server.physics.tx {
        if tx.tick != tick + 1 || tx.purpose != .Snapshot || len(tx.data.bytes) == 0 {
            continue
        }

        resumed = true
        inspection, error := net.complete_inspect(tx.data.bytes, codec.value.identity, 1)
        testing.expect_value(t, error, net.Error.None)
        testing.expect_value(t, inspection.signature.tick, tick + 1)
        testing.expect(
            t,
            inspection.signature.complete != first_signature.complete,
            "new flush must encode the actual next tick",
        )
    }

    testing.expect(t, resumed, "valid next-tick publication resumes after refused serialization")
}
