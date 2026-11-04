package replay_net_test

import "core:testing"
import r "godot:replay"
import tr "godot:replay/transport"
import net "godot:replay/net"

event_fold :: proc(a, b: Event) -> (Event, bool) {
    return Event{a.seat, a.value + b.value}, true
}

@(test)
rejected_action_restores_prior_folded_events :: proc(t: ^testing.T) {
    m := model()
    m.step = proc(w: ^World, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
        r.emit(ctx, 1, 9, Event{1, 3})
    }
    m.action = proc(w: ^World, seat: u16, action: Action, ctx: ^r.Step(Event)) -> bool {
        w.players[0].x = 99
        r.emit_fold(ctx, 1, 9, Event{1, 7}, event_fold)
        return !action.fail_after_mutation
    }
    s: Server
    defer net.server_destroy(&s)
    testing.expect_value(
        t,
        net.server_init(&s, r.Frame(World){state = {chest = 5}}, m, {}, local_seat = 1),
        net.Error.None,
    )
    net.server_issue(&s, Action{fail_after_mutation = true})
    testing.expect_value(t, net.server_step(&s), net.Error.None)
    events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(Event))
    count, err := r.copy_events(&s.timeline, 1, events[:])
    testing.expect_value(t, err, r.Error.None)

    for event in events[:count] {
        if event.value.kind == .Gameplay {
            testing.expect_value(t, event.value.value.value, u32(3))
        }
    }

    frame, _ := r.current(&s.timeline)
    testing.expect_value(t, frame.state.players[0].x, i32(0))
    net.server_issue(&s, Action{take = true})
    net.server_step(&s)
    count, err = r.copy_events(&s.timeline, 2, events[:])

    for event in events[:count] {
        if event.value.kind == .Gameplay {
            testing.expect_value(t, event.value.value.value, u32(10))
        }
    }
}

@(test)
welcome_restores_an_action_verdict_without_replaying_its_old_fact :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    client := &f.clients[0]
    sequence, err := net.client_issue(client, Action{fail_after_mutation = true})
    testing.expect_value(t, err, net.Error.None)

    // Leave this client unpumped while authority admission settles its action.
    for _ in 0 ..< 80 {
        tr.memory_advance(&f.network, f.clock)
        net.server_pump(&f.server, f.clock * 1000 / 60)
        net.server_step(&f.server)
        f.clock += 1
    }

    buffer: [tr.MAX_PACKET_BYTES]u8

    for {
        packet := tr.receive(&client.wire, buffer[:])

        if packet.state != .Received {
            break
        }
    }

    client.phase = .Resyncing
    client.hello_sent = false
    client.request_sequence += 1

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    outcomes: [4]net.Action_Outcome
    recovered: [4]bool
    count := net.client_outcomes(client, outcomes[:], recovered[:])
    testing.expect_value(t, count, 1)
    testing.expect(t, recovered[0] && outcomes[0].sequence == sequence && !outcomes[0].applied)
    testing.expect_value(t, net.client_outcomes(client, outcomes[:], recovered[:]), 0)
}
