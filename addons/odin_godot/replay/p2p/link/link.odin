package replay_p2p_link

import "core:crypto"
import "core:crypto/chacha20poly1305"
import "core:crypto/hkdf"
import auth "godot:replay/authority"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"

VERSION :: u8(1)
HEADER :: 16
OVERHEAD :: HEADER + chacha20poly1305.TAG_SIZE
MAX_PAYLOAD :: tr.MAX_PACKET_BYTES - OVERHEAD
HELLO_BYTES :: 104
CONFIRM_BYTES :: 72

Phase :: enum {
    Closed,
    Connecting,
    Ready,
    Failed,
}

Error :: enum {
    None,
    Invalid,
    Clock,
    Timeout,
    Connection,
    Capacity,
}

Config :: struct {
    grant:      Grant,
    local:      auth.Identity,
    peer:       tr.Peer_Id,
    nonce:      Nonce,
    timeout_ms: u64,
}

Stats :: struct {
    hello_sent, confirmed, rejected, replayed, sent, received: u64,
}

Link :: struct {
    phase:                                                  Phase,
    error:                                                  Error,
    config:                                                 Config,
    base:                                                   tr.Transport,
    clock:                                                  auth.Clock_Source,
    local_index:                                            int,
    base_generation:                                        u64,
    now, started, last_handshake:                           u64,
    handshake_sent, remote_known, keys_ready, acknowledged: bool,
    remote_nonce:                                           Nonce,
    transcript:                                             [32]u8,
    tx_keys, rx_keys:                                       [2]Key,
    tx_confirm, rx_confirm:                                 Key,
    tx_sequence:                                            [2]u64,
    rx:                                                     [2]Window,
    pending:                                                tr.Received,
    plain:                                                  [MAX_PAYLOAD]u8,
    txb, rxb:                                               [tr.MAX_PACKET_BYTES]u8,
    stats:                                                  Stats,
}

@(private)
Window :: struct {
    highest, bits: u64,
}

// Borrow one already-connected physical peer on a generation-aware transport.
// Supply a fresh cryptographic nonce every time; never serialize this owner or
// reuse its nonce after restarting it. The embedding refreshes the grant before
// binding a new connection; this wrapper never guesses a replacement identity.
open :: proc(l: ^Link, base: tr.Transport, clock: auth.Clock_Source, cfg: Config) -> bool {
    base := base

    if l.phase != .Closed ||
       !grant_valid(cfg.grant) ||
       cfg.nonce == (Nonce{}) ||
       cfg.peer == 0 ||
       cfg.timeout_ms < 250 ||
       cfg.timeout_ms > 120000 ||
       clock.read == nil ||
       base.generation == nil ||
       !tr.peer_connected(&base, cfg.peer) {
        return false
    }

    index := -1

    for id, i in cfg.grant.scope.members {
        if id == cfg.local {
            index = i
        }
    }

    if index < 0 {
        return false
    }

    generation := tr.peer_generation(&base, cfg.peer)

    if generation == 0 {
        return false
    }

    now, ok := clock.read(clock.user)

    if !ok {
        return false
    }

    l.config, l.base, l.clock, l.local_index, l.base_generation = cfg, base, clock, index, generation
    l.now, l.started, l.phase = now, now, .Connecting
    return true
}

// Close releases secrets and pending plaintext. The embedding owns the base
// lifetime. Give each link a dedicated peer route; pump consumes that route.
close :: proc(l: ^Link) {
    crypto.zero_explicit(l, size_of(Link))
}

transport :: proc(l: ^Link) -> tr.Transport {
    return {
        user = l,
        send = send,
        receive = receive,
        poll = poll,
        status = status,
        close = close_transport,
        connected = connected,
        generation = generation,
    }
}

identity :: proc(l: ^Link) -> (auth.Identity, bool) {
    if !live(l) || l.phase != .Ready {
        return {}, false
    }

    return l.config.grant.scope.members[1 - l.local_index], true
}

// Drive handshake/ack retries even after local admission until the remote has
// acknowledged our confirmation. Data authenticated by the transcript also
// confirms possession, so an early unreliable packet cannot strand admission.
pump :: proc(l: ^Link) {
    if !live(l) {
        return
    }

    tr.poll(&l.base)

    if !live(l) {
        return
    }

    if l.phase == .Connecting && l.now - l.started >= l.config.timeout_ms {
        fail(l, .Timeout)
        return
    }

    if !l.acknowledged && (!l.handshake_sent || l.now - l.last_handshake >= 250) {
        hello(l)

        if l.keys_ready {
            confirm(l, false)
        }

        l.last_handshake, l.handshake_sent = l.now, true
    }

    if l.pending.state == .Received {
        return
    }

    for _ in 0 ..< 32 {
        packet := tr.receive(&l.base, l.rxb[:])

        if packet.state == .Empty {
            break
        }

        if packet.state == .Disconnected {
            fail(l, .Connection)
            return
        }

        if packet.state != .Received ||
           packet.from != l.config.peer ||
           packet.generation != l.base_generation ||
           packet.count < 1 ||
           packet.count > len(l.rxb) ||
           packet.channel > .Unreliable {
            l.stats.rejected += 1
            continue
        }

        accept(l, packet, l.rxb[:packet.count])

        if l.pending.state == .Received {
            break
        }
    }
}

@(private)
live :: proc(l: ^Link) -> bool {
    if l.phase == .Closed || l.phase == .Failed {
        return false
    }

    now, ok := l.clock.read(l.clock.user)

    if !ok || now < l.now {
        fail(l, .Clock)
        return false
    }

    l.now = now

    if !tr.peer_connected(&l.base, l.config.peer) || tr.peer_generation(&l.base, l.config.peer) != l.base_generation {
        fail(l, .Connection)
        return false
    }

    return true
}

@(private)
fail :: proc(l: ^Link, error: Error) {
    l.phase, l.error, l.pending = .Failed, error, {}
    crypto.zero_explicit(&l.config.grant.key, size_of(Key))
    crypto.zero_explicit(&l.tx_keys, size_of(l.tx_keys))
    crypto.zero_explicit(&l.rx_keys, size_of(l.rx_keys))
    crypto.zero_explicit(&l.tx_confirm, size_of(Key))
    crypto.zero_explicit(&l.rx_confirm, size_of(Key))
    crypto.zero_explicit(&l.plain, size_of(l.plain))
}

@(private)
hello :: proc(l: ^Link) {
    packet: [HELLO_BYTES]u8
    packet[0], packet[1], packet[2], packet[3] = 'R', 'L', VERSION, 1
    packet[4] = u8(l.local_index)
    scope := scope_hash(l.config.grant.scope)
    copy(packet[8:40], scope[:])
    copy(packet[40:72], l.config.nonce[:])
    tag := mac(l.config.grant.key, "replay-p2p-link-hello-v1", packet[:72])
    copy(packet[72:], tag[:])

    if tr.send(&l.base, l.config.peer, .Reliable, packet[:]) == .Sent {
        l.stats.hello_sent += 1
    }
}

@(private)
derive_keys :: proc(l: ^Link) {
    bytes: [96]u8
    scope := scope_hash(l.config.grant.scope)
    copy(bytes[:32], scope[:])

    if l.local_index == 0 {
        copy(bytes[32:64], l.config.nonce[:])
        copy(bytes[64:], l.remote_nonce[:])
    } else {
        copy(bytes[32:64], l.remote_nonce[:])
        copy(bytes[64:], l.config.nonce[:])
    }

    l.transcript = rec.hash(bytes[:])
    material: [192]u8
    info := "replay-p2p-link-traffic-v1"
    hkdf.extract_and_expand(.SHA256, l.transcript[:], l.config.grant.key[:], transmute([]u8)info, material[:])

    for channel in 0 ..< 2 {
        tx := (l.local_index * 2 + channel) * 32
        rx := ((1 - l.local_index) * 2 + channel) * 32
        copy(l.tx_keys[channel][:], material[tx:tx + 32])
        copy(l.rx_keys[channel][:], material[rx:rx + 32])
    }

    tx := 128 + l.local_index * 32
    rx := 128 + (1 - l.local_index) * 32
    copy(l.tx_confirm[:], material[tx:tx + 32])
    copy(l.rx_confirm[:], material[rx:rx + 32])
    crypto.zero_explicit(&material, size_of(material))
    l.keys_ready = true
}

@(private)
confirm :: proc(l: ^Link, ack: bool) {
    packet: [CONFIRM_BYTES]u8
    packet[0], packet[1], packet[2], packet[3] = 'R', 'L', VERSION, ack ? u8(3) : u8(2)
    packet[4] = u8(l.local_index)
    copy(packet[8:40], l.transcript[:])
    tag := mac(l.tx_confirm, "replay-p2p-link-confirm-v1", packet[:40])
    copy(packet[40:], tag[:])
    tr.send(&l.base, l.config.peer, .Reliable, packet[:])
}

@(private)
accept :: proc(l: ^Link, packet: tr.Received, bytes: []u8) {
    if len(bytes) < 8 ||
       bytes[0] != 'R' ||
       bytes[1] != 'L' ||
       bytes[2] != VERSION ||
       bytes[4] != u8(1 - l.local_index) ||
       bytes[6] != 0 ||
       bytes[7] != 0 {
        l.stats.rejected += 1
        return
    }

    if bytes[3] == 1 {
        if len(bytes) != HELLO_BYTES || packet.channel != .Reliable || bytes[5] != 0 {
            l.stats.rejected += 1
            return
        }

        scope := scope_hash(l.config.grant.scope)
        tag := mac(l.config.grant.key, "replay-p2p-link-hello-v1", bytes[:72])
        nonce: Nonce
        copy(nonce[:], bytes[40:72])

        if !equal(scope[:], bytes[8:40]) ||
           !equal(tag[:], bytes[72:]) ||
           nonce == (Nonce{}) ||
           (l.remote_known && l.remote_nonce != nonce) {
            l.stats.rejected += 1
            return
        }

        if !l.remote_known {
            l.remote_nonce, l.remote_known = nonce, true
            derive_keys(l)
        }

        confirm(l, false)
        return
    }

    if !l.keys_ready {
        l.stats.rejected += 1
        return
    }

    if bytes[3] == 2 || bytes[3] == 3 {
        if len(bytes) != CONFIRM_BYTES ||
           packet.channel != .Reliable ||
           bytes[5] != 0 ||
           !equal(l.transcript[:], bytes[8:40]) {
            l.stats.rejected += 1
            return
        }

        tag := mac(l.rx_confirm, "replay-p2p-link-confirm-v1", bytes[:40])

        if !equal(tag[:], bytes[40:]) {
            l.stats.rejected += 1
            return
        }

        if bytes[3] == 2 {
            confirm(l, true)
        } else {
            l.acknowledged = true
        }

        if l.phase != .Ready {
            l.stats.confirmed += 1
        }

        l.phase = .Ready
        return
    }

    if bytes[3] != 4 || len(bytes) <= OVERHEAD || len(bytes) > tr.MAX_PACKET_BYTES || bytes[5] != u8(packet.channel) {
        l.stats.rejected += 1
        return
    }

    channel := int(packet.channel)
    sequence := get(bytes[8:16])

    if !window_accepts(l.rx[channel], sequence) {
        l.stats.replayed += 1
        return
    }

    nonce: [12]u8
    put(nonce[4:], sequence)
    ctx: chacha20poly1305.Context
    chacha20poly1305.init(&ctx, l.rx_keys[channel][:])
    defer crypto.zero_explicit(&ctx, size_of(ctx))
    count := len(bytes) - OVERHEAD

    if !chacha20poly1305.open(
        &ctx,
        l.plain[:count],
        nonce[:],
        bytes[:HEADER],
        bytes[HEADER:HEADER + count],
        bytes[HEADER + count:],
    ) {
        l.stats.rejected += 1
        return
    }

    window_record(&l.rx[channel], sequence)

    if l.phase != .Ready {
        l.stats.confirmed += 1
        confirm(l, true)
    }

    l.phase = .Ready
    l.stats.received += 1
    l.pending = {
        state      = .Received,
        from       = l.config.peer,
        channel    = packet.channel,
        count      = count,
        generation = l.base_generation,
    }
}

@(private)
window_accepts :: proc(w: Window, sequence: u64) -> bool {
    return(
        sequence != 0 &&
        (sequence > w.highest ||
                (w.highest - sequence < 64 && (w.bits & (u64(1) << uint(w.highest - sequence))) == 0)) \
    )
}

@(private)
window_record :: proc(w: ^Window, sequence: u64) {
    if sequence > w.highest {
        gap := sequence - w.highest
        w.bits = gap >= 64 ? 1 : (w.bits << uint(gap)) | 1
        w.highest = sequence
    } else {
        w.bits |= u64(1) << uint(w.highest - sequence)
    }
}

@(private)
send :: proc(user: rawptr, to: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> tr.Send_Result {
    l := cast(^Link)user

    if !live(l) || l.phase != .Ready {
        return .Disconnected
    }

    if to != l.config.peer || channel > .Unreliable || len(bytes) == 0 {
        return .Invalid
    }

    if len(bytes) > MAX_PAYLOAD {
        return .Too_Large
    }

    index := int(channel)

    if l.tx_sequence[index] == max(u64) {
        fail(l, .Capacity)
        return .Disconnected
    }

    // Consume a sequence for every encryption, including transport backpressure.
    // No later attempt can encrypt different plaintext under the same key/nonce.
    l.tx_sequence[index] += 1
    sequence := l.tx_sequence[index]
    header := l.txb[:HEADER]

    for &b in header {
        b = 0
    }

    header[0], header[1], header[2], header[3] = 'R', 'L', VERSION, 4
    header[4], header[5] = u8(l.local_index), u8(channel)
    put(header[8:16], sequence)
    nonce: [12]u8
    put(nonce[4:], sequence)
    ctx: chacha20poly1305.Context
    chacha20poly1305.init(&ctx, l.tx_keys[index][:])
    defer crypto.zero_explicit(&ctx, size_of(ctx))
    count := HEADER + len(bytes)
    chacha20poly1305.seal(&ctx, l.txb[HEADER:count], l.txb[count:count + 16], nonce[:], header, bytes)
    result := tr.send(&l.base, to, channel, l.txb[:count + 16])

    if result == .Sent {
        l.stats.sent += 1
    }

    return result
}

@(private)
receive :: proc(user: rawptr, dst: []u8) -> tr.Received {
    l := cast(^Link)user

    if !live(l) {
        return {state = .Disconnected}
    }

    if l.pending.state != .Received {
        return {state = .Empty}
    }

    packet := l.pending

    if len(dst) < packet.count {
        packet.state = .Buffer_Too_Small
        return packet
    }

    copy(dst, l.plain[:packet.count])
    crypto.zero_explicit(raw_data(l.plain[:]), packet.count)
    l.pending = {}
    return packet
}

@(private)
poll :: proc(user: rawptr) {
    pump(cast(^Link)user)
}

@(private)
status :: proc(user: rawptr) -> tr.Status {
    l := cast(^Link)user

    if !live(l) {
        return .Disconnected
    }

    return l.phase == .Ready ? .Connected : .Connecting
}

@(private)
connected :: proc(user: rawptr, peer: tr.Peer_Id) -> bool {
    l := cast(^Link)user
    return peer == l.config.peer && status(user) == .Connected
}

@(private)
generation :: proc(user: rawptr, peer: tr.Peer_Id) -> u64 {
    l := cast(^Link)user
    return connected(user, peer) ? l.base_generation : 0
}

@(private)
close_transport :: proc(user: rawptr) {
    close(cast(^Link)user)
}
