package replay_transport_test
import "core:testing"
import tr "godot:replay/transport"

@(test)
delay_and_remap_drop_retired_packets_without_dropping_other_peers :: proc(t: ^testing.T) {
    network: tr.Memory
    assert(tr.memory_init(&network, cfg = {3, 16, 1200, 64}))
    defer tr.memory_destroy(&network)
    endpoints: [3]tr.Memory_Endpoint

    for &e, i in endpoints {
        assert(tr.memory_open(&network, &e, tr.Peer_Id(i + 1)))
    }

    defer for &e in endpoints {
        wire := tr.memory_transport(&e)
        tr.close(&wire)
    }

    a, b, c :=
        tr.memory_transport(&endpoints[0]), tr.memory_transport(&endpoints[1]), tr.memory_transport(&endpoints[2])
    delay: tr.Delay
    assert(tr.delay_init(&delay, b, 100, 4))
    wire := tr.delay_transport(&delay)
    defer tr.close(&wire)
    mapping: tr.Remap
    bindings := [2]tr.Peer_Mapping{{101, 1}, {303, 3}}
    assert(tr.remap_init(&mapping, wire, bindings[:]))
    mapped := tr.remap_transport(&mapping)
    old, other, fresh := [1]u8{11}, [1]u8{33}, [1]u8{22}
    assert(tr.send(&a, 2, .Reliable, old[:]) == .Sent)
    assert(tr.send(&c, 2, .Reliable, other[:]) == .Sent)
    tr.memory_advance(&network, 1)
    tr.poll(&wire)
    testing.expect_value(t, tr.peer_generation(&mapped, 101), u64(1))
    tr.close(&a)
    assert(tr.memory_open(&network, &endpoints[0], 1))
    a = tr.memory_transport(&endpoints[0])
    assert(tr.send(&a, 2, .Reliable, fresh[:]) == .Sent)
    tr.memory_advance(&network, 2)
    tr.delay_time(&delay, 200)
    tr.poll(&wire)
    dst: [8]u8
    packet := tr.receive(&mapped, dst[:])
    testing.expect(t, packet.state == .Received && packet.from == 303 && dst[0] == 33)
    testing.expect_value(t, tr.receive(&mapped, dst[:]).state, tr.Receive_State.Empty)
    tr.delay_time(&delay, 400)
    packet = tr.receive(&mapped, dst[:])
    testing.expect(t, packet.state == .Received && packet.from == 101 && packet.generation == 2 && dst[0] == 22)
    testing.expect_value(t, delay.retired, u64(1))
    testing.expect_value(t, tr.peer_generation(&mapped, 101), u64(2))
}

@(test)
router_retires_queued_and_pending_reliable_packets_on_replacement :: proc(t: ^testing.T) {
    network: tr.Memory
    assert(tr.memory_init(&network, cfg = {2, 16, 1200, 64}))
    defer tr.memory_destroy(&network)
    endpoints: [2]tr.Memory_Endpoint

    for &e, i in endpoints {
        assert(tr.memory_open(&network, &e, tr.Peer_Id(i + 1)))
    }

    defer for &e in endpoints {
        wire := tr.memory_transport(&e)
        tr.close(&wire)
    }

    a, b := tr.memory_transport(&endpoints[0]), tr.memory_transport(&endpoints[1])
    router: tr.Router
    cfg := tr.DEFAULT_ROUTER_CONFIG
    cfg.packets_per_lane = 1
    assert(tr.router_init(&router, b, proc(user: rawptr, from: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> int {
                return 0
            }, cfg))
    defer tr.router_destroy(&router)
    lane := tr.router_transport(&router, 0)
    bytes := [1]u8{11}
    assert(tr.send(&a, 2, .Reliable, bytes[:]) == .Sent)
    assert(tr.send(&a, 2, .Reliable, bytes[:]) == .Sent)
    tr.memory_advance(&network, 1)
    assert(tr.router_pump(&router, 1))
    testing.expect(t, router.pending)
    tr.close(&a)
    assert(tr.memory_open(&network, &endpoints[0], 1))
    a = tr.memory_transport(&endpoints[0])
    bytes[0] = 22
    assert(tr.send(&a, 2, .Reliable, bytes[:]) == .Sent)
    tr.memory_advance(&network, 2)
    assert(tr.router_pump(&router, 2))
    output: [8]u8
    packet := tr.receive(&lane, output[:])
    testing.expect(t, packet.state == .Received && packet.generation == 2 && output[0] == 22)
    testing.expect_value(t, router.stats.retired, u64(2))
    testing.expect_value(t, tr.peer_generation(&lane, 1), u64(2))
}

@(test)
fragments_retire_completion_pending_and_outgoing_work_and_reset_delivery_frontier :: proc(t: ^testing.T) {
    f: Fragment_Fixture
    fragment_fixture_init(&f)
    defer fragment_fixture_destroy(&f)
    assert(tr.memory_set_faults(&f.memory, tr.DEFAULT_FAULTS))
    tr.fragments_destroy(&f.fragments[1])
    cfg := tr.DEFAULT_FRAGMENT_CONFIG
    cfg.messages = 1
    assert(tr.fragments_init(&f.fragments[1], tr.memory_transport(&f.ends[1]), proc(user: rawptr) -> u64 {
                return (cast(^Fragment_Fixture)user).now
            }, &f, cfg))
    a, b := tr.fragments_transport(&f.fragments[0]), tr.fragments_transport(&f.fragments[1])
    bytes := [8]u8 {
        0 = 11,
    }
    out: [8]u8
    assert(tr.send(&a, 2, .Reliable, bytes[:]) == .Sent)
    fragment_fixture_step(&f)
    fragment_fixture_step(&f)
    testing.expect_value(t, tr.receive(&b, out[:]).state, tr.Receive_State.Received)

    for _ in 0 ..< 2 {
        assert(tr.send(&a, 2, .Reliable, bytes[:]) == .Sent)
    }

    fragment_fixture_step(&f)
    fragment_fixture_step(&f)
    testing.expect(t, f.fragments[1].pending && f.fragments[1].rx_bytes == 8)
    assert(tr.send(&b, 1, .Reliable, bytes[:]) == .Sent)
    old := tr.memory_transport(&f.ends[0])
    tr.close(&old)
    tr.fragments_destroy(&f.fragments[0])
    assert(tr.memory_open(&f.memory, &f.ends[0], 1))
    assert(tr.fragments_init(&f.fragments[0], tr.memory_transport(&f.ends[0]), proc(user: rawptr) -> u64 {
                return (cast(^Fragment_Fixture)user).now
            }, &f))
    a = tr.fragments_transport(&f.fragments[0])
    bytes[0] = 99
    assert(tr.send(&a, 2, .Reliable, bytes[:]) == .Sent)
    fragment_fixture_step(&f)
    fragment_fixture_step(&f)
    packet := tr.receive(&b, out[:])
    testing.expect(t, packet.state == .Received && packet.generation == 2 && out[0] == 99)
    testing.expect_value(t, f.fragments[1].stats.retired, u64(3))
    testing.expect_value(t, f.fragments[1].tx_bytes, 0)
    testing.expect_value(t, len(f.fragments[1].delivered), 1)
}

@(test)
incomplete_fragments_cannot_be_spliced_with_a_reused_message_id :: proc(t: ^testing.T) {
    f: Fragment_Fixture
    fragment_fixture_init(&f)
    defer fragment_fixture_destroy(&f)
    assert(tr.memory_set_faults(&f.memory, tr.DEFAULT_FAULTS))
    f.fragments[0].cfg.packets_per_poll = 1
    a, b := tr.fragments_transport(&f.fragments[0]), tr.fragments_transport(&f.fragments[1])
    bytes: [2000]u8

    for &byte in bytes {
        byte = 11
    }

    assert(tr.send(&a, 2, .Reliable, bytes[:]) == .Sent)
    tr.poll(&a)
    f.now = 1
    tr.memory_advance(&f.memory, f.now)
    tr.poll(&b)
    testing.expect_value(t, f.fragments[1].rx_bytes, 2000)
    old := tr.memory_transport(&f.ends[0])
    tr.close(&old)
    tr.fragments_destroy(&f.fragments[0])
    assert(tr.memory_open(&f.memory, &f.ends[0], 1))
    assert(tr.fragments_init(&f.fragments[0], tr.memory_transport(&f.ends[0]), proc(user: rawptr) -> u64 {
                return (cast(^Fragment_Fixture)user).now
            }, &f))
    a = tr.fragments_transport(&f.fragments[0])

    for &byte in bytes {
        byte = 99
    }

    assert(tr.send(&a, 2, .Reliable, bytes[:]) == .Sent)
    fragment_fixture_step(&f)
    fragment_fixture_step(&f)
    out: [2000]u8
    packet := tr.receive(&b, out[:])
    testing.expect(t, packet.state == .Received && packet.count == 2000 && packet.generation == 2)

    for byte in out {
        testing.expect_value(t, byte, u8(99))
    }

    testing.expect_value(t, f.fragments[1].stats.retired, u64(1))
}

@(test)
unversioned_adapters_keep_their_existing_packet_contract :: proc(t: ^testing.T) {
    network: tr.Memory
    assert(tr.memory_init(&network, cfg = {2, 8, 1200, 32}))
    defer tr.memory_destroy(&network)
    endpoints: [2]tr.Memory_Endpoint

    for &e, i in endpoints {
        assert(tr.memory_open(&network, &e, tr.Peer_Id(i + 1)))
    }

    defer for &e in endpoints {
        wire := tr.memory_transport(&e)
        tr.close(&wire)
    }

    a, b := tr.memory_transport(&endpoints[0]), tr.memory_transport(&endpoints[1])
    // Existing custom wrappers may not yet expose the optional callback. Their
    // packets stay unversioned, rather than acquiring inconsistent inner metadata.
    legacy := tr.Transport {
        user = &b,
        receive = proc(user: rawptr, dst: []u8) -> tr.Received {
            return tr.receive(cast(^tr.Transport)user, dst)
        },
        status = proc(user: rawptr) -> tr.Status {
            return .Connected
        },
    }
    delay: tr.Delay
    assert(tr.delay_init(&delay, legacy, 20, 2))
    wrapped := tr.delay_transport(&delay)
    defer tr.close(&wrapped)
    bytes := [2]u8{7, 8}
    assert(tr.send(&a, 2, .Reliable, bytes[:]) == .Sent)
    tr.memory_advance(&network, 1)
    tr.poll(&wrapped)
    tr.delay_time(&delay, 30)
    out: [2]u8
    small := tr.receive(&wrapped, out[:1])
    testing.expect_value(t, small.state, tr.Receive_State.Buffer_Too_Small)
    packet := tr.receive(&wrapped, out[:])
    testing.expect(t, packet.state == .Received && packet.generation == 0 && out == bytes)
    testing.expect_value(t, delay.retired, u64(0))
}
