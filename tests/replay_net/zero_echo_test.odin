package replay_net_test
import "core:testing"
import "core:fmt"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"

Late_Input_Wire :: struct {
    base:   tr.Transport,
    memory: ^tr.Memory,
}

late_input_send :: proc(user: rawptr, to: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> tr.Send_Result {
    wire := cast(^Late_Input_Wire)user
    saved := wire.memory.faults.latency_ticks
    meta, _, report := sc.inspect(bytes)

    if report.error == .None && (meta.kind == 4 || meta.kind == 15 || meta.kind == 5) {
        wire.memory.faults.latency_ticks = 30
    }

    result := tr.send(&wire.base, to, channel, bytes)
    wire.memory.faults.latency_ticks = saved
    return result
}

@(test)
zero_input_echo_recovers_a_client_whose_first_inputs_arrive_stale :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)
    c := &f.clients[0]
    wire := Late_Input_Wire{c.wire, &f.network}
    c.wire = {
        user = &wire,
        send = late_input_send,
        receive = proc(user: rawptr, dst: []u8) -> tr.Received {
            return tr.receive(&(cast(^Late_Input_Wire)user).base, dst)
        },
        status = proc(user: rawptr) -> tr.Status {
            return tr.status(&(cast(^Late_Input_Wire)user).base)
        },
        connected = proc(user: rawptr, id: tr.Peer_Id) -> bool {
            return tr.peer_connected(&(cast(^Late_Input_Wire)user).base, id)
        },
    }
    clocks: [3]r.Clock

    for &clock in clocks {
        r.clock_init(&clock, 60)
    }

    first_echo: u64

    for _ in 0 ..< 600 {
        timed_step(&f, &clocks, true)

        if first_echo == 0 && c.input_timing.last_echo != 0 {
            first_echo = f.clock
        }

        testing.expect(t, c.clock_scale >= 0.9 && c.clock_scale <= 1.1)
    }

    testing.expect(t, first_echo > 0 && first_echo < 500)
    testing.expect(t, c.stats.timing_samples > 20)
    frame, _ := r.current(&f.server.timeline)
    testing.expect(t, frame.state.players[0].x > 100)
    sequence, err := net.client_issue(c, Action{take = true})
    testing.expect_value(t, err, net.Error.None)
    due := c.actions[0].tick

    for _ in 0 ..< 150 {
        timed_step(&f, &clocks)

        for action in c.actions[:c.action_count] {
            if action.sequence == sequence {
                testing.expect_value(t, action.tick, due)
            }
        }
    }

    outcomes: [16]net.Action_Outcome
    n := net.client_outcomes(c, outcomes[:])
    applied := 0

    for outcome in outcomes[:n] {
        if outcome.sequence == sequence && outcome.applied {
            testing.expect_value(t, outcome.tick, due)
            applied += 1
        }
    }

    testing.expect_value(t, applied, 1)
    testing.expect_value(t, c.stats.resyncs, u64(0))
    fmt.printf(
        "ZERO_ECHO_RECOVERY first_echo=%d samples=%d rejected_initial_inputs=%d\n",
        first_echo,
        c.stats.timing_samples,
        f.server.stats.rejected_inputs,
    )
}
