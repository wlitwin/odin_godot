package replay_net_test

import "core:reflect"
import "core:fmt"
import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import view "godot:replay/view"
import sc "godot:replay/schema"

Player :: struct {
    active: bool,
    x:      i32,
    bag:    u32,
}

World :: struct {
    players: [2]Player,
    chest:   u32,
}

Control :: struct {
    move: i8,
}

Action :: struct {
    take:                bool,
    fail_after_mutation: bool,
}

Event :: struct {
    seat:  u16,
    value: u32,
}

Server :: net.Server(World, Control, Action, Event, 2)
Client :: net.Client(World, Control, Action, Event, 2)

model_step :: proc(w: ^World, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
    for &player, i in w.players {
        if joins & (u64(1) << uint(i)) != 0 {
            player.active = true
        }

        if leaves & (u64(1) << uint(i)) != 0 {
            player.active = false
        }

        if player.active {
            player.x += i32(controls[i].move)
        }
    }
}

model_action :: proc(w: ^World, seat: u16, action: Action, ctx: ^r.Step(Event)) -> bool {
    player := &w.players[seat - 1]

    if action.fail_after_mutation {
        player.x += 999
        r.emit(ctx, u64(seat), 1, Event{seat, 999})
        return false
    }

    if !player.active || !action.take || w.chest == 0 {
        return false
    }

    player.bag += w.chest
    w.chest = 0
    r.emit(ctx, u64(seat), 1, Event{seat, player.bag})
    return true
}

control_valid :: proc(c: Control) -> bool {
    return c.move >= -1 && c.move <= 1
}

action_valid :: proc(a: Action) -> bool {
    return a.take || a.fail_after_mutation
}

state_valid :: proc(w: World) -> bool {
    return w.chest + w.players[0].bag + w.players[1].bag == 5
}

hold :: proc(c: Control) -> Control {
    return c
}

model :: proc() -> net.Model(World, Control, Action, Event, 2) {
    return {
        step = model_step,
        action = model_action,
        control_valid = control_valid,
        action_valid = action_valid,
        state_valid = state_valid,
        hold = hold,
    }
}

Fixture :: struct {
    network:   tr.Memory,
    endpoints: [4]tr.Memory_Endpoint,
    server:    Server,
    clients:   [3]Client,
    clock:     u64,
}

fixture_init :: proc(
    f: ^Fixture,
    faults := tr.DEFAULT_FAULTS,
    config := net.DEFAULT_CONFIG,
    action_timing := net.Action_Timing.Scheduled,
    action_schedule := net.Action_Schedule(Action){},
) {
    ok := tr.memory_init(&f.network, seed = 123, cfg = {4, 512, 8192, 65536}, faults = faults)
    assert(ok)

    for &endpoint, i in f.endpoints {
        assert(tr.memory_open(&f.network, &endpoint, tr.Peer_Id(i + 1)))
    }

    cfg := config
    cfg.content = 0x54455354
    m := model()
    m.action_timing = action_timing
    m.action_schedule = action_schedule
    init_err := net.server_init(
        &f.server,
        r.Frame(World){state = {chest = 5}},
        m,
        tr.memory_transport(&f.endpoints[0]),
        cfg,
    )
    assert(init_err == .None, fmt.tprintf("server init: %v / %v", init_err, f.server.frame_error))

    for &client, i in f.clients {
        token: net.Token
        token[0] = u8(i + 1)
        assert(
            net.client_init(
                &client,
                m,
                tr.memory_transport(&f.endpoints[i + 1]),
                token,
                spectator = i == 2,
                cfg = cfg,
            ) ==
            .None,
        )
    }
}

fixture_destroy :: proc(f: ^Fixture) {
    for &client in f.clients {
        net.client_destroy(&client)
    }

    net.server_destroy(&f.server)

    for &endpoint in f.endpoints {
        wire := tr.memory_transport(&endpoint)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.network)
}

fixture_step :: proc(f: ^Fixture, moving := false) {
    assert(tr.memory_advance(&f.network, f.clock))
    now := f.clock * 1000 / 60
    assert(net.server_pump(&f.server, now) == .None)

    for &client in f.clients {
        assert(net.client_pump(&client, now) == .None)
    }

    assert(net.server_step(&f.server) == .None)

    for &client, i in f.clients {
        if client.phase == .Running && !client.spectator {
            control := Control {
                move = moving ? (i == 0 ? i8(1) : i8(-1)) : 0,
            }
            err := net.client_step(&client, control)
            assert(err == .None || err == .Capacity)
        }

        changes: [512]view.Change(net.Net_Event(Event))

        for view.drain(&client.journal, changes[:]) > 0 {}
    }

    f.clock += 1
}

@(test)
server_clients_and_observer_join_move_and_converge :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, tr.Faults{latency_ticks = 3, retry_ticks = 3})
    defer fixture_destroy(&f)

    for _ in 0 ..< 100 {
        fixture_step(&f, true)
    }

    for client, i in f.clients {
        testing.expect_value(t, client.phase, net.Phase.Running)
        testing.expect_value(t, client.seat, i == 2 ? u16(0) : u16(i + 1))
    }

    for _ in 0 ..< 100 {
        fixture_step(&f)
    }

    truth, _ := r.current(&f.server.timeline)
    testing.expect(t, truth.state.players[0].x > 40 && truth.state.players[1].x < -40)

    for &client in f.clients {
        frame, _ := r.current(&client.timeline)
        testing.expect(t, reflect.equal(frame.state, truth.state))
    }

    testing.expect(t, f.clients[0].stats.corrections > 0)
    testing.expect_value(t, f.server.stats.rejected_inputs, u64(0))
}

@(test)
contested_actions_predict_then_settle_once :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, tr.Faults{latency_ticks = 3, retry_ticks = 3})
    defer fixture_destroy(&f)

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    for &client in f.clients[:2] {
        seq, err := net.client_issue(&client, Action{take = true})
        testing.expect_value(t, err, net.Error.None)
        testing.expect_value(t, seq, u64(1))
    }

    fixture_step(&f)

    for &client in f.clients[:2] {
        frame, _ := r.current(&client.timeline)
        testing.expect_value(t, frame.state.players[client.seat - 1].bag, u32(5))
    }

    for _ in 0 ..< 100 {
        fixture_step(&f)
    }

    truth, _ := r.current(&f.server.timeline)
    testing.expect_value(t, truth.state.players[0].bag + truth.state.players[1].bag, u32(5))
    applied := 0

    for &client in f.clients[:2] {
        outcomes: [4]net.Action_Outcome
        n := net.client_outcomes(&client, outcomes[:])
        testing.expect_value(t, n, 1)

        if outcomes[0].applied {
            applied += 1
        } else {
            testing.expect_value(t, outcomes[0].reason, net.Action_Reason.Predicate)
        }

        testing.expect_value(t, client.action_count, 0)
    }

    testing.expect_value(t, applied, 1)
}

@(test)
failed_action_restores_all_mutation_and_gameplay_events :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    _, err := net.client_issue(&f.clients[0], Action{fail_after_mutation = true})
    testing.expect_value(t, err, net.Error.None)

    for _ in 0 ..< 80 {
        fixture_step(&f)
    }

    truth, _ := r.current(&f.server.timeline)
    testing.expect_value(t, truth.state.players[0].x, i32(0))
    results: [2]net.Action_Outcome
    testing.expect_value(t, net.client_outcomes(&f.clients[0], results[:]), 1)
    testing.expect(t, !results[0].applied)
}

@(test)
loss_jitter_and_long_blackout_recover_through_explicit_resync :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(
        &f,
        tr.Faults {
            latency_ticks = 2,
            jitter_ticks = 2,
            loss_permyriad = 1000,
            duplicate_permyriad = 1000,
            retry_ticks = 3,
        },
    )
    defer fixture_destroy(&f)

    for _ in 0 ..< 180 {
        fixture_step(&f, true)
    }

    for client in f.clients {
        testing.expect_value(t, client.phase, net.Phase.Running)
    }

    tr.memory_set_faults(&f.network, tr.Faults{loss_permyriad = 10000, retry_ticks = 3})

    for _ in 0 ..< 180 {
        fixture_step(&f, true)
    }

    testing.expect(t, f.clients[0].stats.resyncs > 0 || f.clients[0].stats.stalls > 0)
    tr.memory_set_faults(&f.network, tr.DEFAULT_FAULTS)

    for _ in 0 ..< 240 {
        fixture_step(&f)
    }

    truth, _ := r.current(&f.server.timeline)

    for &client in f.clients {
        testing.expect_value(t, client.phase, net.Phase.Running)
        frame, _ := r.current(&client.timeline)
        testing.expect(t, reflect.equal(truth.state, frame.state))
    }
}

@(test)
reconnect_preserves_seat_state_and_action_sequence :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    seq, _ := net.client_issue(&f.clients[0], Action{take = true})

    for _ in 0 ..< 60 {
        fixture_step(&f)
    }

    seat, generation := f.clients[0].seat, f.clients[0].generation
    tr.close(&f.clients[0].wire)

    for _ in 0 ..< 620 {
        fixture_step(&f)
    }

    truth, _ := r.current(&f.server.timeline)
    testing.expect(t, !truth.state.players[seat - 1].active)
    testing.expect(t, tr.memory_open(&f.network, &f.endpoints[1], 2))
    testing.expect_value(t, net.client_reconnect(&f.clients[0], tr.memory_transport(&f.endpoints[1])), net.Error.None)

    for _ in 0 ..< 90 {
        fixture_step(&f)
    }

    testing.expect_value(t, f.clients[0].phase, net.Phase.Running)
    testing.expect_value(t, f.clients[0].seat, seat)
    testing.expect(t, f.clients[0].generation > generation)
    frame, _ := r.current(&f.clients[0].timeline)
    testing.expect_value(t, frame.state.players[seat - 1].bag, u32(5))
    next, err := net.client_issue(&f.clients[0], Action{take = true})
    testing.expect_value(t, err, net.Error.None)
    testing.expect_value(t, next, seq + 1)
}

@(test)
admission_rejects_contract_mismatch_and_live_token_takeover :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)
    f.clients[1].contract ~= 1
    f.clients[2].token = f.clients[0].token

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    testing.expect_value(t, f.clients[0].phase, net.Phase.Running)
    testing.expect_value(t, f.clients[1].phase, net.Phase.Rejected)
    testing.expect_value(t, f.clients[1].rejection, net.Reject.Contract)
    testing.expect_value(t, f.clients[2].phase, net.Phase.Rejected)
    testing.expect_value(t, f.clients[2].rejection, net.Reject.Token_In_Use)
    testing.expect_value(t, net.client_step(&f.clients[0], Control{move = 127}), net.Error.Invalid_Input)
    _, err := net.client_issue(&f.clients[2], Action{take = true})
    testing.expect_value(t, err, net.Error.Wrong_Phase)
}

@(test)
reliable_action_retries_are_deduplicated_before_gameplay :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    net.client_issue(&f.clients[0], Action{take = true})
    packet := capture_packet(&f, 2, 5, false)
    defer delete(packet)
    testing.expect(t, len(packet) > 0)

    for _ in 0 ..< 3 {
        tr.send(&f.clients[0].wire, 1, .Reliable, packet)
    }

    for _ in 0 ..< 90 {
        fixture_step(&f)
    }

    truth, _ := r.current(&f.server.timeline)
    testing.expect_value(t, truth.state.players[0].bag, u32(5))
    testing.expect(t, f.server.stats.duplicate_actions >= 3)
    results: [4]net.Action_Outcome
    testing.expect_value(t, net.client_outcomes(&f.clients[0], results[:]), 1)
    testing.expect(t, results[0].applied)
}

@(test)
ingress_checks_connection_binding_and_the_complete_input_window :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    tr.memory_advance(&f.network, f.clock)
    net.server_pump(&f.server, f.clock * 1000 / 60)
    net.client_step(&f.clients[0], Control{move = 1})
    // Preserve coverage of the full-format fallback even when the sender
    // chooses compact encoding for this particular control window.
    packet := make([]u8, sc.HEADER_BYTES + f.clients[0].codecs.inputs.wire_size)
    meta := sc.Envelope_Meta {
        kind    = 4,
        epoch   = f.clients[0].cfg.epoch,
        tick    = f.clients[0].timeline.head,
        content = f.clients[0].cfg.content,
    }
    testing.expect_value(
        t,
        sc.pack_bytes(f.clients[0].codecs.inputs.fingerprint, meta, f.clients[0].input_scratch, packet).error,
        sc.Error.None,
    )
    defer delete(packet)
    testing.expect(t, len(packet) > 0)
    before := f.server.stats.rejected_inputs
    // Valid bytes from player A, but delivered by B's connection.
    tr.send(&f.clients[1].wire, 1, .Unreliable, packet)
    tr.memory_advance(&f.network, f.clock)
    net.server_pump(&f.server, f.clock * 1000 / 60)
    testing.expect_value(t, f.server.stats.rejected_inputs, before + 1)
    newest := f.server.peers[0].input_newest
    // Keep schema/checksum valid while corrupting the LAST semantic value.
    found := false

    for field in f.server.codecs.inputs.fields {
        if field.path == "$.samples[7].value.move" {
            packet[sc.HEADER_BYTES + field.wire_offset] = 127
            found = true
        }
    }

    testing.expect(t, found)
    checksum := sc.digest(packet[sc.HEADER_BYTES:], sc.digest(packet[:44]))

    for i in 0 ..< 8 {
        packet[44 + i] = u8(checksum >> uint(i * 8))
    }

    tr.send(&f.clients[0].wire, 1, .Unreliable, packet)
    tr.memory_advance(&f.network, f.clock)
    net.server_pump(&f.server, f.clock * 1000 / 60)
    testing.expect_value(t, f.server.stats.rejected_inputs, before + 2)
    testing.expect_value(t, f.server.peers[0].input_newest, newest)
}

capture_packet :: proc(f: ^Fixture, from: tr.Peer_Id, kind: u16, remove: bool) -> []u8 {
    for &packet, i in f.network.packets {
        if !packet.active || packet.from != from {
            continue
        }

        bytes := f.network.bytes[i * f.network.config.packet_bytes:i * f.network.config.packet_bytes + packet.count]
        meta, _, report := sc.inspect(bytes)

        if report.error != .None || meta.kind != kind {
            continue
        }

        out := make([]u8, len(bytes))
        copy(out, bytes)

        if remove {
            packet.active = false
        }

        return out
    }

    return nil
}
