package replay_transport_test

import "core:testing"
import "core:reflect"
import tr "godot:replay/transport"

Fragment_Fixture :: struct {
    memory:    tr.Memory,
    ends:      [2]tr.Memory_Endpoint,
    fragments: [2]tr.Fragments,
    now:       u64,
}

fragment_fixture_init :: proc(f: ^Fragment_Fixture) {
    faults := tr.DEFAULT_FAULTS
    faults.latency_ticks, faults.jitter_ticks, faults.duplicate_permyriad = 20, 10, 1000
    assert(tr.memory_init(&f.memory, 44, {2, 512, 1200, 16384}, faults))

    for &e, i in f.ends {
        assert(tr.memory_open(&f.memory, &e, tr.Peer_Id(i + 1)))
        assert(tr.fragments_init(&f.fragments[i], tr.memory_transport(&e), proc(user: rawptr) -> u64 {
                    return (cast(^Fragment_Fixture)user).now
                }, f))
    }
}

fragment_fixture_destroy :: proc(f: ^Fragment_Fixture) {
    for &adapter in f.fragments {
        tr.fragments_destroy(&adapter)
    }

    for &e in f.ends {
        wire := tr.memory_transport(&e)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.memory)
}

fragment_fixture_step :: proc(f: ^Fragment_Fixture) {
    f.now += 10
    tr.memory_advance(&f.memory, f.now)

    for &adapter in f.fragments {
        wire := tr.fragments_transport(&adapter)
        tr.poll(&wire)
    }
}

@(test)
fragmented_reliable_messages_preserve_bytes_order_and_small_read_retention :: proc(t: ^testing.T) {
    f: Fragment_Fixture
    fragment_fixture_init(&f)
    defer fragment_fixture_destroy(&f)
    a, b := tr.fragments_transport(&f.fragments[0]), tr.fragments_transport(&f.fragments[1])
    large := make([]u8, tr.MAX_PACKET_BYTES)
    defer delete(large)

    for &byte, i in large {
        byte = u8(i % 251)
    }

    small := [4]u8{8, 7, 6, 5}
    testing.expect_value(t, tr.send(&a, 2, .Reliable, large), tr.Send_Result.Sent)
    testing.expect_value(t, tr.send(&a, 2, .Reliable, small[:]), tr.Send_Result.Sent)
    output := make([]u8, tr.MAX_PACKET_BYTES)
    defer delete(output)
    count := 0
    retained := false

    for _ in 0 ..< 500 {
        fragment_fixture_step(&f)

        if count == 0 && !retained {
            packet := tr.receive(&b, output[:1])

            if packet.state == .Empty {
                continue
            }

            testing.expect_value(t, packet.state, tr.Receive_State.Buffer_Too_Small)
            retained = true
        }

        for {
            packet := tr.receive(&b, output)

            if packet.state != .Received {
                break
            }

            testing.expect_value(t, packet.channel, tr.Channel.Reliable)
            testing.expect(t, reflect.equal(output[:packet.count], count == 0 ? large : small[:], true))
            count += 1
        }

        if count == 2 {
            break
        }
    }

    testing.expect(t, retained && count == 2)
}

@(test)
fragment_limits_and_unreliable_timeout_do_not_consume_unbounded_memory :: proc(t: ^testing.T) {
    f: Fragment_Fixture
    fragment_fixture_init(&f)
    defer fragment_fixture_destroy(&f)
    a := tr.fragments_transport(&f.fragments[0])
    bytes := make([]u8, tr.MAX_PACKET_BYTES)
    defer delete(bytes)

    for _ in 0 ..< 16 {
        testing.expect_value(t, tr.send(&a, 2, .Unreliable, bytes), tr.Send_Result.Sent)
    }

    testing.expect_value(t, tr.send(&a, 2, .Unreliable, bytes), tr.Send_Result.Backpressure)

    for _ in 0 ..< 40 {
        fragment_fixture_step(&f)
    }

    testing.expect(t, f.fragments[1].rx_bytes <= f.fragments[1].cfg.rx_bytes)

    for _ in 0 ..< 300 {
        fragment_fixture_step(&f)
    }

    testing.expect(t, f.fragments[1].rx_bytes <= f.fragments[1].cfg.rx_bytes)
}

@(test)
fragment_partial_unreliable_expires_but_reliable_waits_for_backpressure :: proc(t: ^testing.T) {
    f: Fragment_Fixture
    fragment_fixture_init(&f)
    defer fragment_fixture_destroy(&f)
    raw := tr.memory_transport(&f.ends[0])
    // First fragment of a 2,000-byte message. Deliberately never send the second.
    packet: [1200]u8
    packet[0], packet[1], packet[2], packet[3] = 'R', 'P', 'F', 1
    packet[4] = 1
    packet[12], packet[13] = 0xd0, 7
    packet[18] = 2

    for channel in tr.Channel {
        testing.expect_value(t, tr.send(&raw, 2, channel, packet[:]), tr.Send_Result.Sent)
    }

    for _ in 0 ..< 10 {
        fragment_fixture_step(&f)
    }

    testing.expect_value(t, f.fragments[1].rx_bytes, 4000)

    for _ in 0 ..< 220 {
        fragment_fixture_step(&f)
    }

    testing.expect_value(t, f.fragments[1].rx_bytes, 2000)
    testing.expect_value(t, f.fragments[1].stats.expired, u64(1))
    tr.close(&raw)
    fragment_fixture_step(&f)
    testing.expect_value(t, f.fragments[1].rx_bytes, 0)
}

@(test)
fragment_full_receiver_retains_reliable_next_packet_until_application_drains :: proc(t: ^testing.T) {
    f: Fragment_Fixture
    fragment_fixture_init(&f)
    defer fragment_fixture_destroy(&f)
    tr.fragments_destroy(&f.fragments[1])
    cfg := tr.DEFAULT_FRAGMENT_CONFIG
    cfg.messages = 1
    assert(tr.fragments_init(&f.fragments[1], tr.memory_transport(&f.ends[1]), proc(user: rawptr) -> u64 {
                return (cast(^Fragment_Fixture)user).now
            }, &f, cfg))
    a, b := tr.fragments_transport(&f.fragments[0]), tr.fragments_transport(&f.fragments[1])
    bytes := make([]u8, tr.MAX_PACKET_BYTES)
    defer delete(bytes)

    for i in 1 ..= 3 {
        bytes[0] = u8(i)
        testing.expect_value(t, tr.send(&a, 2, .Reliable, bytes), tr.Send_Result.Sent)
    }

    for _ in 0 ..< 250 {
        fragment_fixture_step(&f)
    }

    testing.expect(t, f.fragments[1].pending)
    count := 0

    for _ in 0 ..< 500 {
        fragment_fixture_step(&f)
        packet := tr.receive(&b, bytes)

        if packet.state == .Received {
            count += 1
            testing.expect_value(t, bytes[0], u8(count))
            testing.expect_value(t, packet.count, tr.MAX_PACKET_BYTES)
        }

        if count == 3 {
            break
        }
    }

    testing.expect_value(t, count, 3)
}

@(test)
fragment_sender_drains_small_messages_across_reused_slots :: proc(t: ^testing.T) {
    f: Fragment_Fixture
    fragment_fixture_init(&f)
    defer fragment_fixture_destroy(&f)
    assert(tr.memory_set_faults(&f.memory, tr.DEFAULT_FAULTS))
    sender, receiver := tr.fragments_transport(&f.fragments[0]), tr.fragments_transport(&f.fragments[1])
    bytes := [1]u8{7}
    output: [16]u8

    for round in 0 ..< 16 {
        for _ in 0 ..< 4 {
            testing.expect_value(t, tr.send(&sender, 2, .Reliable, bytes[:]), tr.Send_Result.Sent)
        }

        tr.poll(&sender)
        f.now += 10
        tr.memory_advance(&f.memory, f.now)
        tr.poll(&receiver)
        count := 0

        for {
            packet := tr.receive(&receiver, output[:])

            if packet.state != .Received {
                break
            }

            count += 1
        }

        testing.expectf(t, count == 4, "round %d delivered %d small messages despite available budget", round, count)
    }
}

@(test)
unreliable_staging_limit_applies_backpressure_without_blocking_reliable_admission :: proc(t: ^testing.T) {
    f: Fragment_Fixture
    fragment_fixture_init(&f)
    defer fragment_fixture_destroy(&f)
    testing.expect(t, tr.fragments_limit_unreliable(&f.fragments[0], 8))
    wire := tr.fragments_transport(&f.fragments[0])
    bytes := [1]u8{7}

    for _ in 0 ..< 8 {
        testing.expect_value(t, tr.send(&wire, 2, .Unreliable, bytes[:]), tr.Send_Result.Sent)
    }

    testing.expect_value(t, tr.send(&wire, 2, .Unreliable, bytes[:]), tr.Send_Result.Backpressure)
    testing.expect_value(t, tr.send(&wire, 2, .Reliable, bytes[:]), tr.Send_Result.Sent)
    testing.expect(t, !tr.fragments_limit_unreliable(&f.fragments[0], 4))
    testing.expect_value(t, f.fragments[0].stats.queue_limited, u64(1))
    fragment_fixture_step(&f)
    testing.expect_value(t, tr.send(&wire, 2, .Unreliable, bytes[:]), tr.Send_Result.Sent)
}

@(test)
unreliable_staging_limit_still_admits_a_large_logical_message :: proc(t: ^testing.T) {
    f: Fragment_Fixture
    fragment_fixture_init(&f)
    defer fragment_fixture_destroy(&f)
    testing.expect(t, tr.fragments_limit_unreliable(&f.fragments[0], 8))
    wire := tr.fragments_transport(&f.fragments[0])
    bytes := make([]u8, tr.MAX_PACKET_BYTES)
    defer delete(bytes)
    testing.expect_value(t, tr.send(&wire, 2, .Unreliable, bytes), tr.Send_Result.Sent)
    testing.expect_value(t, tr.send(&wire, 2, .Unreliable, bytes[:1]), tr.Send_Result.Backpressure)
    f.fragments[0].cfg.packets_per_poll = 4
    fragment_fixture_step(&f)
    testing.expect_value(t, tr.send(&wire, 2, .Unreliable, bytes[:1]), tr.Send_Result.Backpressure)

    for _ in 0 ..< 20 {
        fragment_fixture_step(&f)
    }

    testing.expect_value(t, tr.send(&wire, 2, .Unreliable, bytes[:1]), tr.Send_Result.Sent)
}
