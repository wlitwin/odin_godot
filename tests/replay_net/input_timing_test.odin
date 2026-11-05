package replay_net_test

import "core:testing"
import "core:reflect"
import "core:fmt"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import view "godot:replay/view"

// Follow the public clock discipline used by the Godot adapter. The ordinary
// fixture intentionally advances once per call and does not consume clock_scale.
timed_step :: proc(f: ^Fixture, clocks: ^[3]r.Clock, moving: bool = false) {
    assert(tr.memory_advance(&f.network, f.clock))
    now := f.clock * 1000 / 60
    assert(net.server_pump(&f.server, now) == .None)

    for &client, i in f.clients {
        catchups := client.stats.snapshot_catchups
        assert(net.client_pump(&client, now) == .None)

        if client.stats.snapshot_catchups != catchups {
            r.clock_init(&clocks[i], 60)
        }
    }

    assert(net.server_step(&f.server) == .None)

    for &client, i in f.clients {
        count, ok := r.clock_add(&clocks[i], client.clock_scale / 60)
        assert(ok)

        for _ in 0 ..< count {
            if client.phase == .Running && !client.spectator {
                err := net.client_step(&client, Control{move = moving ? i8(1) : 0})
                assert(err == .None || err == .Capacity)
            }

            r.clock_consume(&clocks[i])
        }

        changes: [512]view.Change(net.Net_Event(Event))

        for view.drain(&client.journal, changes[:]) > 0 {}
    }

    f.clock += 1
}

@(test)
slow_welcome_calibrates_from_live_input_echo_without_retiming_actions :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, {latency_ticks = 3, retry_ticks = 3})
    defer fixture_destroy(&f)
    clocks: [3]r.Clock

    for &clock in clocks {
        r.clock_init(&clock, 60)
    }

    // Send Hello, then stall the authority's initial work for 1.5 seconds. No
    // gameplay advances during setup; the later wire has an ordinary six-tick RTT.
    for &client in f.clients {
        net.client_pump(&client, 0)
    }

    f.clock = 90

    for _ in 0 ..< 12 {
        timed_step(&f, &clocks)
    }

    c := &f.clients[0]
    testing.expect_value(t, c.phase, net.Phase.Running)
    initial := c.lead_ticks
    testing.expect(t, initial >= 50)
    sequence, issued := net.client_issue(c, Action{take = true})
    testing.expect_value(t, issued, net.Error.None)
    due := c.actions[0].tick
    saw_fast_slew := false

    for _ in 0 ..< 600 {
        timed_step(&f, &clocks, true)
        saw_fast_slew = saw_fast_slew || c.clock_scale < 0.98

        for action in c.actions[:c.action_count] {
            if action.sequence == sequence {
                testing.expect_value(t, action.tick, due)
            }
        }
    }

    testing.expect(t, saw_fast_slew)
    testing.expect(t, c.stats.timing_samples > 20 && c.stats.lead_updates > 0)
    testing.expect(t, c.lead_ticks <= 16)
    testing.expect(t, c.timeline.head - c.authority_frame.tick <= 18)
    testing.expect_value(t, c.stats.resyncs, u64(0))
    testing.expect_value(t, f.server.stats.rejected_inputs, u64(0))
    frame, _ := r.current(&f.server.timeline)
    testing.expect_value(t, frame.state.players[0].bag, u32(5))
    outcomes: [net.ACTION_CAPACITY]net.Action_Outcome
    n := net.client_outcomes(c, outcomes[:])
    applied := 0

    for outcome in outcomes[:n] {
        if outcome.sequence == sequence {
            testing.expect(t, outcome.applied && outcome.tick == due)
            applied += 1
        }
    }

    testing.expect_value(t, applied, 1)

    for _ in 0 ..< 180 {
        timed_step(&f, &clocks)
    }

    truth, _ := r.current(&f.server.timeline)

    for &client in f.clients {
        got, _ := r.current(&client.timeline)
        testing.expect(t, reflect.equal(got.state, truth.state))
    }

    fmt.printf(
        "INPUT_TIMING_CALIBRATED initial=%d final=%d depth=%d samples=%d turnaround_ms=%d\n",
        initial,
        c.lead_ticks,
        c.timeline.head - c.authority_frame.tick,
        c.stats.timing_samples,
        c.input_timing.turnaround_ms,
    )
}

@(test)
input_feedback_handles_latency_changes_and_jitter :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, {latency_ticks = 3, jitter_ticks = 2, retry_ticks = 3})
    defer fixture_destroy(&f)
    clocks: [3]r.Clock

    for &clock in clocks {
        r.clock_init(&clock, 60)
    }

    for _ in 0 ..< 300 {
        timed_step(&f, &clocks, true)
    }

    before := f.clients[0].lead_ticks
    f.network.faults.latency_ticks = 8

    for _ in 0 ..< 420 {
        timed_step(&f, &clocks, true)
    }

    high := f.clients[0].lead_ticks
    testing.expect(t, high > before)
    f.network.faults.latency_ticks = 2

    for _ in 0 ..< 600 {
        timed_step(&f, &clocks)
    }

    c := &f.clients[0]
    testing.expect(t, c.lead_ticks < high)
    testing.expect(t, c.clock_scale >= 0.9 && c.clock_scale <= 1.1)
    testing.expect_value(t, c.phase, net.Phase.Running)

    for client in f.clients {
        testing.expect_value(t, client.stats.resyncs, u64(0))
    }

    testing.expect_value(t, f.clients[2].clock_scale, f64(1))
    testing.expect_value(t, f.clients[2].stats.timing_samples, u64(0))
    fmt.printf(
        "INPUT_TIMING_NETWORK low=%d high=%d recovered=%d resyncs=%d\n",
        before,
        high,
        c.lead_ticks,
        c.stats.resyncs,
    )
}

Timing_Gate :: struct {
    base:    tr.Transport,
    blocked: bool,
}

timing_gate_wire :: proc(g: ^Timing_Gate) -> tr.Transport {
    return {user = g, send = proc(user: rawptr, to: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> tr.Send_Result {
            gate := cast(^Timing_Gate)user

            if gate.blocked && channel == .Unreliable {
                return .Backpressure
            }

            return tr.send(&gate.base, to, channel, bytes)
        }, receive = proc(user: rawptr, out: []u8) -> tr.Received {
            return tr.receive(&(cast(^Timing_Gate)user).base, out)
        }, poll = proc(user: rawptr) {
            tr.poll(&(cast(^Timing_Gate)user).base)
        }, status = proc(user: rawptr) -> tr.Status {
            return tr.status(&(cast(^Timing_Gate)user).base)
        }, connected = proc(user: rawptr, id: tr.Peer_Id) -> bool {
            return tr.peer_connected(&(cast(^Timing_Gate)user).base, id)
        }}
}

@(test)
timing_records_only_successful_submissions_and_discards_local_stall_samples :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, {latency_ticks = 3, retry_ticks = 3})
    defer fixture_destroy(&f)
    clocks: [3]r.Clock

    for &clock in clocks {
        r.clock_init(&clock, 60)
    }

    for _ in 0 ..< 120 {
        timed_step(&f, &clocks)
    }

    c := &f.clients[0]
    gate := Timing_Gate{c.wire, true}
    c.wire = timing_gate_wire(&gate)
    first := c.timeline.head + 1

    for _ in 0 ..< 25 {
        timed_step(&f, &clocks, true)
    }

    for tick in first ..= c.timeline.head {
        record := c.input_sent[tick % u64(len(c.input_sent))]
        testing.expect(t, !record.valid || record.tick != tick)
    }

    gate.blocked = false

    for _ in 0 ..< 120 {
        timed_step(&f, &clocks)
    }

    testing.expect(t, c.input_timing.samples > 3)
    f.clock += 60
    testing.expect(t, tr.memory_advance(&f.network, f.clock))
    testing.expect_value(t, net.client_pump(c, f.clock * 1000 / 60), net.Error.None)
    testing.expect_value(t, c.input_timing.samples, u32(0))

    for sent in c.input_sent {
        testing.expect(t, !sent.valid)
    }

    testing.expect_value(t, net.client_reconnect(c, timing_gate_wire(&gate)), net.Error.None)
    testing.expect_value(t, c.input_timing.last_echo, u64(0))
    testing.expect_value(t, c.clock_scale, f64(1))
}

@(test)
latest_observation_clients_do_not_calibrate_a_scheduled_input_lead :: proc(t: ^testing.T) {
    f: Observation_Fixture
    observation_setup(&f, .Latest_Observation, .Latest_Observation)
    defer observation_cleanup(&f)

    for i in 1 ..= 60 {
        tr.memory_advance(&f.network, f.clock)
        net.server_pump(&f.server, f.clock * 16)
        net.server_step(&f.server)
        net.client_pump(&f.client, f.clock * 16)
        net.client_step(&f.client, Observation{sequence = u64(i), value = u32(i)})
        changes: [512]view.Change(net.Net_Event(u8))

        for view.drain(&f.client.journal, changes[:]) > 0 {}

        f.clock += 1
    }

    testing.expect_value(t, f.client.clock_scale, f64(1))
    testing.expect_value(t, f.client.stats.timing_samples, u64(0))

    for sent in f.client.input_sent {
        testing.expect(t, !sent.valid)
    }
}

input_delay_run :: proc(t: ^testing.T, delay_max: u32) -> (lead: u64, chosen: u32) {
    f: Fixture
    cfg := net.DEFAULT_CONFIG
    cfg.input_delay_max, cfg.input_delay_ping_ms = delay_max, 100
    // Six-tick one-way latency: a 200 ms round trip.
    fixture_init(&f, {latency_ticks = 6, retry_ticks = 6}, cfg)
    defer fixture_destroy(&f)
    clocks: [3]r.Clock

    for &clock in clocks {
        r.clock_init(&clock, 60)
    }

    for step in 0 ..< 900 {
        assert(tr.memory_advance(&f.network, f.clock))
        now := f.clock * 1000 / 60
        assert(net.server_pump(&f.server, now) == .None)

        for &client, i in f.clients {
            catchups := client.stats.snapshot_catchups
            assert(net.client_pump(&client, now) == .None)

            if client.stats.snapshot_catchups != catchups {
                r.clock_init(&clocks[i], 60)
            }
        }

        assert(net.server_step(&f.server) == .None)

        for &client, i in f.clients {
            count, ok := r.clock_add(&clocks[i], client.clock_scale / 60)
            assert(ok)

            for _ in 0 ..< count {
                if client.phase == .Running && !client.spectator {
                    // Inputs change every 20 ticks so delayed samples are visible.
                    err := net.client_step(&client, Control{move = i8((step / 20) % 3) - 1})
                    assert(err == .None || err == .Capacity)
                }

                r.clock_consume(&clocks[i])
            }

            changes: [512]view.Change(net.Net_Event(Event))

            for view.drain(&client.journal, changes[:]) > 0 {}
        }

        f.clock += 1
    }

    c := &f.clients[0]
    testing.expect_value(t, c.phase, net.Phase.Running)
    testing.expect_value(t, c.stats.resyncs, u64(0))
    testing.expect_value(t, f.server.stats.rejected_inputs, u64(0))

    // Every confirmed own-seat input the client recorded is exactly what the
    // authority accepted for that tick: a sample sent early never changes.
    first := c.timeline.confirmed > 100 ? c.timeline.confirmed - 100 : 1

    for tick in first ..= c.timeline.confirmed {
        mine, found := r.read_input(&c.timeline, tick)
        theirs, accepted := r.read_input(&f.server.timeline, tick)

        if found && accepted {
            testing.expect_value(t, mine.controls[c.seat - 1], theirs.controls[c.seat - 1])
        }
    }

    return c.timeline.head - f.server.timeline.head, c.input_delay
}

// Quantum-style input offset: past the ping threshold the client schedules
// each sample input_delay ticks ahead and sends it at once, so it leads the
// authority by about that many fewer ticks while staying consistent.
@(test)
input_delay_schedules_samples_ahead_and_shortens_lead :: proc(t: ^testing.T) {
    plain, none := input_delay_run(t, 0)
    delayed, chosen := input_delay_run(t, 4)
    testing.expect_value(t, none, u32(0))
    testing.expect_value(t, chosen, u32(4)) // ceil((200 - 100) ms * 60 Hz) = 6, capped at 4
    testing.expect(t, delayed + 3 <= plain, fmt.tprintf("lead plain=%d delayed=%d", plain, delayed))
    fmt.printf("INPUT_DELAY lead_plain=%d lead_delayed=%d delay=%d\n", plain, delayed, chosen)
}
