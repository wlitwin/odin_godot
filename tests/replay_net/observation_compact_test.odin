package replay_net_test
import "core:testing"
import "core:reflect"
import "core:mem"
import r "godot:replay"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

observation_negotiate :: proc(f: ^Observation_Fixture) {
    for _ in 0 ..< 8 {
        tr.memory_advance(&f.network, f.clock)
        now := f.clock * 16
        f.clock += 1
        assert(net.server_pump(&f.server, now) == .None)
        assert(net.client_pump(&f.client, now) == .None)
    }
}

@(test)
compact_observations_are_independent_and_keep_identical_admission :: proc(t: ^testing.T) {
    f: Observation_Fixture
    observation_setup(&f, .Latest_Observation, .Latest_Observation)
    defer observation_cleanup(&f)
    observation_negotiate(&f)
    testing.expect(t, f.client.compact_observations_negotiated)
    first := observation_packet(&f, {1, 10})
    defer delete(first)
    second := observation_packet(&f, {2, 20})
    defer delete(second)
    meta, _, report := sc.inspect(second)
    body := second[sc.HEADER_BYTES:]
    testing.expect_value(t, report.error, sc.Error.None)
    testing.expect_value(t, meta.kind, u16(26))
    testing.expect(t, len(second) < sc.HEADER_BYTES + f.client.codecs.observation.wire_size)
    // Golden sparse layout for this model: five nonzero low bytes, no view stamp.
    testing.expect_value(t, f.client.codecs.observation.wire_size, 71)
    testing.expect(t, reflect.equal(body[:9], ([]u8{1, 1, 1, 1, 1, 0, 0, 0, 0}), true))
    testing.expect(
        t,
        reflect.equal(body[9:], ([]u8{u8(f.client.generation), u8(f.client.serial), u8(meta.tick), 2, 20}), true),
    )
    // Losing the first packet cannot prevent decoding the second; a later old
    // packet cannot overwrite the newest observation admitted for this tick.
    observation_deliver(&f, second)
    observation_deliver(&f, first)
    due := f.server.timeline.head + 1
    net.server_step(&f.server)
    frame, _ := r.current(&f.server.timeline)
    testing.expect_value(t, frame.state, (Observed_World{2, due, 20}))
    testing.expect_value(t, r.audit(&f.server.timeline, due).error, r.Error.None)
    testing.expect(t, f.client.stats.compact_observations == 2 && f.client.stats.observation_bytes_saved > 0)
}

@(test)
malformed_compact_observations_do_not_partially_admit :: proc(t: ^testing.T) {
    f: Observation_Fixture
    observation_setup(&f, .Latest_Observation, .Latest_Observation)
    defer observation_cleanup(&f)
    observation_negotiate(&f)
    packet := observation_packet(&f, {1, 10})
    defer delete(packet)
    meta, _, report := sc.inspect(packet)
    body := packet[sc.HEADER_BYTES:]
    assert(report.error == .None && meta.kind == 26)
    fingerprint := f.client.codecs.observation.fingerprint

    for mutation in 0 ..< 6 {
        data := make([]u8, len(body) + 1)
        defer delete(data)
        copy(data, body)
        size := len(body)
        envelope := meta

        switch mutation {
        case 0:
            size -= 1 // missing selected byte
        case 1:
            size += 1 // trailing byte
        case 2:
            data[8] |= 0x80 // unused high bitmap bit
        case 3:
            data[9] = 0 // noncanonical selected zero
        case 4:
            data[9] += 1 // wrong admitted connection generation
        case 5:
            envelope.tick += 1 // payload/envelope tick mismatch
        }

        bytes := make([]u8, sc.HEADER_BYTES + size)
        defer delete(bytes)
        testing.expect_value(t, sc.pack_bytes(fingerprint, envelope, data[:size], bytes).error, sc.Error.None)
        inputs := make([]u8, len(f.server.inputs) * size_of(f.server.inputs[0]))
        defer delete(inputs)
        copy(inputs, mem.slice_to_bytes(f.server.inputs))
        // Slot values/frontiers, rather than transport rejection counters, are the
        // transaction boundary under test.
        before := f.server.peers
        rejected := f.server.stats.rejected_inputs
        observation_deliver(&f, bytes)
        testing.expect_value(t, f.server.stats.rejected_inputs, rejected + 1)
        testing.expect(t, reflect.equal(inputs, mem.slice_to_bytes(f.server.inputs), true))

        for peer, i in f.server.peers {
            testing.expect_value(t, peer.input_newest, before[i].input_newest)
        }
    }

    observation_deliver(&f, packet)
    net.server_step(&f.server)
    frame, _ := r.current(&f.server.timeline)
    testing.expect_value(t, frame.state.value, u32(10))
}

@(test)
compact_observation_feature_is_optional_and_resets_with_welcome :: proc(t: ^testing.T) {
    f: Observation_Fixture
    observation_setup(&f, .Latest_Observation, .Latest_Observation)
    defer observation_cleanup(&f)
    f.server.compact_observations_disabled = true
    observation_negotiate(&f)
    testing.expect(t, !f.client.compact_observations_negotiated)
    packet := observation_packet(&f, {1, 10})
    defer delete(packet)
    meta, _, _ := sc.inspect(packet)
    testing.expect_value(t, meta.kind, u16(14))
    // Reconnect must not retain an earlier peer's negotiation state.
    f.client.compact_observations_negotiated = true
    testing.expect_value(t, net.client_reconnect(&f.client, tr.memory_transport(&f.endpoints[1])), net.Error.None)
    testing.expect(t, !f.client.compact_observations_negotiated && f.client.phase == .Joining)
}

@(test)
compact_observations_converge_under_loss_duplicates_and_jitter :: proc(t: ^testing.T) {
    f: Observation_Fixture
    observation_setup(&f, .Latest_Observation, .Latest_Observation)
    defer observation_cleanup(&f)
    observation_negotiate(&f)
    assert(f.client.compact_observations_negotiated)
    assert(
        tr.memory_set_faults(
            &f.network,
            {latency_ticks = 2, jitter_ticks = 3, loss_permyriad = 2000, duplicate_permyriad = 2000, retry_ticks = 2},
        ),
    )

    for i in u64(1) ..= 180 {
        tr.memory_advance(&f.network, f.clock)
        now := f.clock * 16
        f.clock += 1
        testing.expect_value(t, net.server_pump(&f.server, now), net.Error.None)
        testing.expect_value(t, net.server_step(&f.server), net.Error.None)
        testing.expect_value(t, net.client_pump(&f.client, now), net.Error.None)
        error := net.client_step(&f.client, Observation{i, u32(i)})
        testing.expect(t, error == .None || error == .Capacity)
    }

    tr.memory_set_faults(&f.network, tr.DEFAULT_FAULTS)

    for _ in 0 ..< 30 {
        tr.memory_advance(&f.network, f.clock)
        now := f.clock * 16
        f.clock += 1
        net.server_pump(&f.server, now)
        net.server_step(&f.server)
        net.client_pump(&f.client, now)
        error := net.client_step(&f.client, Observation{181, 181})
        testing.expect(t, error == .None || error == .Capacity)
    }

    frame, _ := r.current(&f.server.timeline)
    testing.expect(t, frame.state.sequence == 181 && frame.state.value == 181 && f.client.phase == .Running)
    testing.expect(t, f.client.stats.compact_observations > 100 && f.client.stats.resyncs == 0)
    dropped := 0

    for event in f.network.trace {
        if event.kind == .Drop {
            dropped += 1
        }
    }

    testing.expect(t, dropped > 0)
}
