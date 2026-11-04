package replay_net_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"

Observed_World :: struct {
    sequence, accepted_at: u64,
    value:                 u32,
}

Observation :: struct {
    sequence: u64,
    value:    u32,
}

Observation_Model :: net.Model(Observed_World, Observation, u8, u8, 2)
Observation_Server :: net.Server(Observed_World, Observation, u8, u8, 2)
Observation_Client :: net.Client(Observed_World, Observation, u8, u8, 2)

Observation_Fixture :: struct {
    network:   tr.Memory,
    endpoints: [2]tr.Memory_Endpoint,
    server:    Observation_Server,
    client:    Observation_Client,
    clock:     u64,
}

observation_model :: proc(timing: net.Control_Timing) -> Observation_Model {
    return {
        control_timing = timing,
        step = proc(w: ^Observed_World, values: [2]Observation, joins, leaves: u64, ctx: ^r.Step(u8)) {
            if values[1].sequence > w.sequence {
                w^ = {values[1].sequence, ctx.tick, values[1].value}
            }
        },
        control_valid = proc(c: Observation) -> bool {
            return c.value <= 1000
        },
        state_valid = proc(w: Observed_World) -> bool {
            return w.value <= 1000
        },
        hold = proc(c: Observation) -> Observation {
            return c
        },
    }
}

observation_setup :: proc(f: ^Observation_Fixture, timing: net.Control_Timing, client_timing: net.Control_Timing) {
    assert(tr.memory_init(&f.network, cfg = {2, 128, 8192, 4096}))

    for &endpoint, i in f.endpoints {
        assert(tr.memory_open(&f.network, &endpoint, tr.Peer_Id(i + 1)))
    }

    assert(
        net.server_init(
            &f.server,
            r.Frame(Observed_World){},
            observation_model(timing),
            tr.memory_transport(&f.endpoints[0]),
            local_seat = 1,
        ) ==
        .None,
    )
    assert(net.server_set_local_token(&f.server, net.Token{0 = 1}) == .None)
    assert(
        net.client_init(
            &f.client,
            observation_model(client_timing),
            tr.memory_transport(&f.endpoints[1]),
            net.Token{0 = 2},
        ) ==
        .None,
    )

    for _ in 0 ..< 20 {
        tr.memory_advance(&f.network, f.clock)
        net.server_pump(&f.server, f.clock * 16)
        net.server_step(&f.server)
        net.client_pump(&f.client, f.clock * 16)
        f.clock += 1

        if f.client.phase == .Running || f.client.phase == .Rejected {
            break
        }
    }
}

observation_cleanup :: proc(f: ^Observation_Fixture) {
    net.client_destroy(&f.client)
    net.server_destroy(&f.server)

    for &endpoint in f.endpoints {
        wire := tr.memory_transport(&endpoint)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.network)
}

observation_packet :: proc(f: ^Observation_Fixture, value: Observation) -> []u8 {
    assert(net.client_step(&f.client, value) == .None)
    tr.memory_advance(&f.network, f.clock)
    f.clock += 1
    bytes: [8192]u8
    saved: []u8

    for {
        packet := tr.receive(&f.server.wire, bytes[:])

        if packet.state == .Empty {
            break
        }

        assert(packet.state == .Received)
        meta, _, report := sc.inspect(bytes[:packet.count])

        if report.error == .None && (meta.kind == 4 || meta.kind == 14 || meta.kind == 15 || meta.kind == 26) {
            delete(saved)
            saved = make([]u8, packet.count)
            copy(saved, bytes[:packet.count])
        }
    }

    assert(len(saved) > 0)
    return saved
}

observation_deliver :: proc(f: ^Observation_Fixture, bytes: []u8) {
    assert(tr.send(&f.client.wire, 1, .Unreliable, bytes) == .Sent)
    tr.memory_advance(&f.network, f.clock)
    f.clock += 1
    assert(net.server_pump(&f.server, f.clock * 16) == .None)
}

@(test)
latest_observations_coalesce_at_the_next_authority_tick_and_reject_reordered_values :: proc(t: ^testing.T) {
    f: Observation_Fixture
    observation_setup(&f, .Latest_Observation, .Latest_Observation)
    defer observation_cleanup(&f)
    first := observation_packet(&f, {1, 10})
    defer delete(first)
    second := observation_packet(&f, {2, 20})
    defer delete(second)
    next_tick := f.server.timeline.head + 1
    testing.expect(t, f.client.timeline.head > next_tick)
    observation_deliver(&f, second)
    observation_deliver(&f, first)
    testing.expect_value(t, net.server_step(&f.server), net.Error.None)
    frame, _ := r.current(&f.server.timeline)
    testing.expect_value(t, frame.state, Observed_World{2, next_tick, 20})
    testing.expect_value(t, r.audit(&f.server.timeline, next_tick).error, r.Error.None)
    observation_deliver(&f, first)
    net.server_step(&f.server)
    after, _ := r.current(&f.server.timeline)
    testing.expect_value(t, after.state, frame.state)
}

@(test)
scheduled_controls_keep_their_original_due_tick_and_timing_modes_must_negotiate :: proc(t: ^testing.T) {
    f: Observation_Fixture
    observation_setup(&f, .Scheduled, .Scheduled)
    defer observation_cleanup(&f)
    packet := observation_packet(&f, {1, 10})
    defer delete(packet)
    due := f.client.timeline.head
    observation_deliver(&f, packet)

    for f.server.timeline.head + 1 < due {
        net.server_step(&f.server)
        frame, _ := r.current(&f.server.timeline)
        testing.expect_value(t, frame.state.sequence, u64(0))
    }

    net.server_step(&f.server)
    frame, _ := r.current(&f.server.timeline)
    testing.expect_value(t, frame.state, Observed_World{1, due, 10})
    mismatch: Observation_Fixture
    observation_setup(&mismatch, .Latest_Observation, .Scheduled)
    defer observation_cleanup(&mismatch)
    testing.expect_value(t, mismatch.client.phase, net.Phase.Rejected)
    testing.expect_value(t, mismatch.client.rejection, net.Reject.Contract)
}

@(test)
observation_archives_preserve_admitted_values_pending_samples_and_capability_contract :: proc(t: ^testing.T) {
    f: Observation_Fixture
    observation_setup(&f, .Latest_Observation, .Latest_Observation)
    defer observation_cleanup(&f)
    first := observation_packet(&f, {1, 10})
    defer delete(first)
    observation_deliver(&f, first)
    net.server_step(&f.server)
    second := observation_packet(&f, {2, 20})
    defer delete(second)
    observation_deliver(&f, second)
    cp, decoded: net.Checkpoint(Observed_World, Observation, u8, 2)
    defer net.checkpoint_destroy(&cp)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_capture(&f.server, &cp), net.Error.None)
    testing.expect_value(t, len(cp.inputs), 1)
    testing.expect_value(t, cp.inputs[0].tick, cp.frame.tick + 1)
    testing.expect_value(t, cp.inputs[0].value, Observation{2, 20})
    bytes, err := net.checkpoint_encode(&cp, observation_model(.Latest_Observation))
    defer delete(bytes)
    testing.expect_value(t, err, net.Error.None)
    testing.expect_value(
        t,
        net.checkpoint_decode(&decoded, bytes, observation_model(.Scheduled), 1),
        net.Error.Checkpoint_Contract,
    )
    testing.expect(t, !decoded.ready)
    testing.expect_value(
        t,
        net.checkpoint_decode(&decoded, bytes, observation_model(.Latest_Observation), 1),
        net.Error.None,
    )
    resumed: Observation_Server
    defer net.server_destroy(&resumed)
    testing.expect_value(
        t,
        net.server_restore(
            &resumed,
            &decoded,
            observation_model(.Latest_Observation),
            {},
            {epoch = 2, local_seat = 1},
        ),
        net.Error.None,
    )
    frame, _ := r.current(&resumed.timeline)
    testing.expect(t, reflect.equal(frame, cp.frame))
    testing.expect_value(t, resumed.model.control_timing, net.Control_Timing.Latest_Observation)
}
