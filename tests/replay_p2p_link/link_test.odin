package link_test

import "core:testing"
import auth "godot:replay/authority"
import adm "godot:replay/p2p/admission"
import lk "godot:replay/p2p/link"
import tr "godot:replay/transport"

MATCH :: adm.Match {
    session = 871,
    content = 55,
    epoch = 1,
    members = {0 = 1, 1 = 2, 2 = 3},
    count = 3,
}

credentials :: proc(member: u64) -> auth.Credential {
    return {{member, 2}, {0 = u8(20 + member)}}
}

pair :: proc(a, b: u64) -> lk.Grant {
    g, ok := lk.derive(MATCH, credentials(a), credentials(b))
    assert(ok)
    return g
}

Fixture :: struct {
    now:       u64,
    memory:    tr.Memory,
    endpoints: [2]tr.Memory_Endpoint,
    links:     [2]lk.Link,
}

clock :: proc(user: rawptr) -> (u64, bool) {
    return (cast(^Fixture)user).now, true
}

setup :: proc(f: ^Fixture, faults := tr.DEFAULT_FAULTS, packets: int = 128) {
    assert(tr.memory_init(&f.memory, cfg = {2, packets, tr.MAX_PACKET_BYTES, 4096}, faults = faults))

    for &e, i in f.endpoints {
        assert(tr.memory_open(&f.memory, &e, tr.Peer_Id(i + 1)))
    }

    g := pair(1, 2)

    for &l, i in f.links {
        cfg := lk.Config {
            grant = g,
            local = g.scope.members[i],
            peer = tr.Peer_Id(2 - i),
            nonce = {0 = u8(i + 1)},
            timeout_ms = 2000,
        }
        assert(lk.open(&l, tr.memory_transport(&f.endpoints[i]), {f, clock}, cfg))
    }
}

destroy :: proc(f: ^Fixture) {
    for &l in f.links {
        lk.close(&l)
    }

    for &e in f.endpoints {
        wire := tr.memory_transport(&e)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.memory)
}

step :: proc(f: ^Fixture, frames: int = 1) {
    for _ in 0 ..< frames {
        f.now += 10
        assert(tr.memory_advance(&f.memory, f.now / 10))

        for &l in f.links {
            lk.pump(&l)
        }
    }
}

ready :: proc(f: ^Fixture) {
    for _ in 0 ..< 190 {
        step(f)

        if f.links[0].phase == .Ready &&
           f.links[1].phase == .Ready &&
           f.links[0].acknowledged &&
           f.links[1].acknowledged {
            return
        }
    }

    panic("link handshake did not complete")
}

packet :: proc(f: ^Fixture, from: int, channel: tr.Channel, text: string) -> []u8 {
    wire := lk.transport(&f.links[from])
    assert(tr.send(&wire, tr.Peer_Id(2 - from), channel, transmute([]u8)text) == .Sent)
    count := lk.OVERHEAD + len(text)
    bytes := make([]u8, count)
    copy(bytes, f.links[from].txb[:count])
    return bytes
}

drain :: proc(f: ^Fixture, member: int, expected: string, channel: tr.Channel = .Reliable) {
    wire := lk.transport(&f.links[member])
    buffer: [256]u8

    for _ in 0 ..< 50 {
        step(f)
        p := tr.receive(&wire, buffer[:])

        if p.state == .Empty {
            continue
        }

        assert(p.state == .Received && p.channel == channel && string(buffer[:p.count]) == expected)
        return
    }

    panic("missing encrypted packet")
}

@(test)
pair_keys_are_symmetric_but_bound_to_members_roster_content_and_incarnations :: proc(t: ^testing.T) {
    g := pair(1, 2)
    testing.expect_value(t, pair(2, 1), g)
    testing.expect(t, g.key != pair(1, 3).key && g.key != pair(2, 3).key)

    for variation in 0 ..< 5 {
        match := MATCH
        a, b := credentials(1), credentials(2)

        switch variation {
        case 0:
            match.session += 1
        case 1:
            match.content += 1
        case 2:
            match.epoch += 1
        case 3:
            match.members[1], match.members[2] = match.members[2], match.members[1]
        case 4:
            b.identity.incarnation += 1
        }

        changed, ok := lk.derive(match, a, b)
        testing.expect(t, ok && changed.key != g.key)
    }

    _, ok := lk.derive(MATCH, credentials(1), credentials(1))
    testing.expect(t, !ok)
    _, ok = lk.derive(MATCH, credentials(1), credentials(4))
    testing.expect(t, !ok)
}

@(test)
mutual_admission_and_encrypted_channels_survive_loss_and_jitter :: proc(t: ^testing.T) {
    f := new(Fixture)
    defer free(f)
    setup(f, {latency_ticks = 2, jitter_ticks = 3, loss_permyriad = 1500, duplicate_permyriad = 2500, retry_ticks = 3})
    defer destroy(f)
    wire := lk.transport(&f.links[0])
    testing.expect_value(t, tr.status(&wire), tr.Status.Connecting)
    testing.expect_value(t, tr.send(&wire, 2, .Reliable, {1, 2}), tr.Send_Result.Disconnected)
    ready(f)

    for &l, i in f.links {
        id, ok := lk.identity(&l)
        testing.expect(t, ok && id == credentials(u64(2 - i)).identity)
    }

    bytes := packet(f, 0, .Reliable, "secret-payload")
    defer delete(bytes)
    testing.expect(t, string(bytes[lk.HEADER:len(bytes) - 16]) != "secret-payload")
    drain(f, 1, "secret-payload")
    testing.expect(t, f.links[1].stats.received == 1)
    // Unreliable loss is allowed, but a received packet retains its channel.
    assert(tr.memory_set_faults(&f.memory, tr.DEFAULT_FAULTS))
    other := packet(f, 1, .Unreliable, "reply")
    defer delete(other)
    drain(f, 0, "reply", .Unreliable)
}

@(test)
forged_replayed_reflected_and_wrong_channel_packets_never_reach_gameplay :: proc(t: ^testing.T) {
    f := new(Fixture)
    defer free(f)
    setup(f)
    defer destroy(f)
    ready(f)
    bytes := packet(f, 0, .Reliable, "message")
    defer delete(bytes)
    drain(f, 1, "message")
    base := tr.memory_transport(&f.endpoints[0])
    receiver := lk.transport(&f.links[1])
    out: [64]u8

    for variation in 0 ..< 5 {
        changed := make([]u8, len(bytes))
        copy(changed, bytes)
        channel := tr.Channel.Reliable

        switch variation {
        case 0: // exact duplicate
        case 1:
            changed[len(changed) - 1] ~= 1
            changed[8] += 1
        case 2:
            changed[8] += 1
            changed[lk.HEADER] ~= 1
        case 3:
            channel = .Unreliable
        case 4:
            changed[4] = 1
        }

        assert(tr.send(&base, 2, channel, changed) == .Sent)
        delete(changed)
        step(f, 3)
        testing.expect_value(t, tr.receive(&receiver, out[:]).state, tr.Receive_State.Empty)
    }

    testing.expect(
        t,
        f.links[1].stats.received == 1 && f.links[1].stats.replayed >= 1 && f.links[1].stats.rejected >= 4,
    )
    // A reflected packet is invalid at its original sender as well.
    reverse := tr.memory_transport(&f.endpoints[1])
    assert(tr.send(&reverse, 1, .Reliable, bytes) == .Sent)
    step(f, 3)
    sender := lk.transport(&f.links[0])
    testing.expect_value(t, tr.receive(&sender, out[:]).state, tr.Receive_State.Empty)
}

@(test)
pending_plaintext_retains_buffer_too_small_and_is_fenced_on_connection_reuse :: proc(t: ^testing.T) {
    f := new(Fixture)
    defer free(f)
    setup(f)
    defer destroy(f)
    ready(f)
    bytes := packet(f, 0, .Reliable, "retained")
    defer delete(bytes)
    step(f, 3)
    receiver := lk.transport(&f.links[1])
    small: [2]u8
    large: [32]u8
    testing.expect_value(t, tr.receive(&receiver, small[:]).state, tr.Receive_State.Buffer_Too_Small)
    testing.expect_value(t, tr.receive(&receiver, small[:]).state, tr.Receive_State.Buffer_Too_Small)
    p := tr.receive(&receiver, large[:])
    testing.expect(t, p.state == .Received && string(large[:p.count]) == "retained")
    again := packet(f, 0, .Reliable, "discard")
    defer delete(again)
    step(f, 3)
    base := tr.memory_transport(&f.endpoints[0])
    tr.close(&base)
    assert(tr.memory_open(&f.memory, &f.endpoints[0], 1))
    testing.expect_value(t, tr.receive(&receiver, large[:]).state, tr.Receive_State.Disconnected)
    testing.expect(
        t,
        f.links[1].phase == .Failed && f.links[1].error == .Connection && f.links[1].pending.state != .Received,
    )
    testing.expect_value(t, f.links[1].config.grant.key, lk.Key{})
}

@(test)
separate_channel_windows_keep_reliable_packets_after_unreliable_bursts :: proc(t: ^testing.T) {
    f := new(Fixture)
    defer free(f)
    setup(f)
    defer destroy(f)
    ready(f)
    reliable := packet(f, 0, .Reliable, "reliable")
    defer delete(reliable)
    drain(f, 1, "reliable")

    for _ in 0 ..< 80 {
        bytes := packet(f, 0, .Unreliable, "fast")
        delete(bytes)
        drain(f, 1, "fast", .Unreliable)
    }

    next := packet(f, 0, .Reliable, "later")
    defer delete(next)
    drain(f, 1, "later")
    testing.expect(t, f.links[1].stats.received == 82 && f.links[1].stats.replayed == 0)
}

@(test)
invalid_grant_cannot_complete_handshake_and_timeout_is_bounded :: proc(t: ^testing.T) {
    f := new(Fixture)
    defer free(f)
    setup(f)
    defer destroy(f)
    f.links[1].config.grant.key[0] ~= 1
    step(f, 210)

    for &l in f.links {
        testing.expect(t, l.phase == .Failed && l.error == .Timeout)
        id, ok := lk.identity(&l)
        testing.expect(t, !ok && id == (auth.Identity{}))
    }
}

@(test)
backpressure_consumes_nonce_and_old_transcript_cannot_cross_reopen :: proc(t: ^testing.T) {
    f := new(Fixture)
    defer free(f)
    setup(f, packets = 4)
    defer destroy(f)
    ready(f)
    wire := lk.transport(&f.links[0])
    base := tr.memory_transport(&f.endpoints[0])

    for _ in 0 ..< 4 {
        assert(tr.send(&base, 2, .Unreliable, {7}) == .Sent)
    }

    testing.expect_value(t, tr.send(&wire, 2, .Reliable, {1}), tr.Send_Result.Backpressure)
    old_sequence := f.links[0].tx_sequence[0]
    testing.expect_value(t, old_sequence, u64(1))
    step(f, 3)
    old := packet(f, 0, .Reliable, "old")
    defer delete(old)
    testing.expect_value(t, f.links[0].tx_sequence[0], u64(2))
    drain(f, 1, "old")

    for &l, i in f.links {
        cfg := l.config
        cfg.nonce[1] = 99
        lk.close(&l)
        assert(lk.open(&l, tr.memory_transport(&f.endpoints[i]), {f, clock}, cfg))
    }

    ready(f)
    assert(tr.send(&base, 2, .Reliable, old) == .Sent)
    step(f, 3)
    receiver := lk.transport(&f.links[1])
    bytes: [16]u8
    testing.expect_value(t, tr.receive(&receiver, bytes[:]).state, tr.Receive_State.Empty)
    fresh := packet(f, 0, .Reliable, "new")
    defer delete(fresh)
    drain(f, 1, "new")
}
