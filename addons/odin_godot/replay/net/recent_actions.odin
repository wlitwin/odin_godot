package replay_net

import sc "godot:replay/schema"
import tr "godot:replay/transport"

ACTION_COPY_INTERVAL_MS :: u64(100)
ACTION_COPY_COUNT :: 4

// Reliable submission/retry remains active. This bounded bundle copies the
// oldest contiguous sent requests without retiming or predicting them again.
@(private)
client_recent_actions :: proc(c: ^Client($S, $C, $A, $E, $N)) {
    if c.phase != .Running ||
       !c.action_copies_negotiated ||
       c.action_count == 0 ||
       (c.action_copies_sent && c.now - c.action_copies_last < ACTION_COPY_INTERVAL_MS) {
        return
    }

    c.action_copies_sent, c.action_copies_last = true, c.now
    // The same generation/serial/count header as recent facts, with its own kind.
    cursor := sc.HEADER_BYTES + c.codecs.recent_facts.wire_size
    count := u8(0)
    previous: u64
    limit := min(c.cfg.unreliable_packet_limit, SNAPSHOT_PART_BYTES)
    packet_bytes := sc.HEADER_BYTES + c.codecs.action.wire_size

    for action in c.actions[:c.action_count] {
        if !action.sent || count == ACTION_COPY_COUNT || (count > 0 && action.sequence != previous + 1) {
            break
        }

        if packet_bytes + 2 > limit - cursor {
            if count == 0 {
                c.stats.action_copy_oversize += 1
            }

            break
        }

        packet := Action_Packet(A){c.generation, c.serial, action.sequence, action.tick, action.value}
        meta := sc.Envelope_Meta {
            kind    = u16(Kind.Action),
            epoch   = c.cfg.epoch,
            tick    = action.tick,
            content = c.cfg.content,
        }

        if sc.pack(&c.codecs.action, packet, meta, c.txb[cursor + 2:cursor + 2 + packet_bytes]).error != .None {
            return
        }

        c.txb[cursor], c.txb[cursor + 1] = u8(packet_bytes), u8(packet_bytes >> 8)
        cursor += 2 + packet_bytes
        count += 1
        previous = action.sequence
    }

    if count == 0 {
        return
    }

    header := Recent_Facts_Header{c.generation, c.serial, count}
    body := c.txb[sc.HEADER_BYTES:cursor]

    if sc.encode(&c.codecs.recent_facts, header, body[:c.codecs.recent_facts.wire_size]).error != .None {
        return
    }

    meta := sc.Envelope_Meta {
        kind    = u16(Kind.Recent_Actions),
        epoch   = c.cfg.epoch,
        tick    = c.timeline.head,
        content = c.cfg.content,
    }

    if sc.pack_bytes(c.codecs.recent_facts.fingerprint, meta, body, c.txb).error != .None {
        return
    }

    if client_send_bytes(c, c.txb[:cursor]) {
        c.stats.action_copy_batches += 1
        c.stats.action_copies += u64(count)
        c.stats.action_copy_bytes += u64(cursor)
    }
}

@(private)
client_send_bytes :: proc(c: ^Client($S, $C, $A, $E, $N), bytes: []u8) -> bool {
    if !permitted(c.cfg.require_permit, c.permit, c.cfg.epoch) {
        return false
    }

    if tr.send(&c.wire, c.authority, .Unreliable, bytes) == .Sent {
        c.stats.tx_packets += 1
        c.stats.tx_bytes += u64(len(bytes))
        return true
    }

    return false
}

@(private)
server_recent_actions :: proc(s: ^Server($S, $C, $A, $E, $N), index: int, bytes: []u8, expected: sc.Envelope_Meta) {
    peer := &s.peers[index]
    _, body, report := sc.unpack_bytes(s.codecs.recent_facts.fingerprint, bytes, expected)
    header: Recent_Facts_Header
    size := s.codecs.recent_facts.wire_size

    if !s.snapshot_tx[index].action_copies_enabled ||
       report.error != .None ||
       len(bytes) > min(s.cfg.unreliable_packet_limit, SNAPSHOT_PART_BYTES) ||
       len(body) < size ||
       sc.decode(&s.codecs.recent_facts, &header, body[:size]).error != .None ||
       header.generation != peer.generation ||
       header.serial != peer.serial ||
       peer.spectator ||
       header.count == 0 ||
       header.count > ACTION_COPY_COUNT {
        s.stats.rejected_packets += 1
        return
    }

    spans: [ACTION_COPY_COUNT][2]int
    cursor := size
    previous: u64

    for i in 0 ..< int(header.count) {
        if len(body) - cursor < 2 {
            s.stats.rejected_packets += 1
            return
        }

        n := int(body[cursor]) | int(body[cursor + 1]) << 8
        cursor += 2

        if n > len(body) - cursor {
            s.stats.rejected_packets += 1
            return
        }

        packet: Action_Packet(A)
        meta, decoded := sc.unpack(
            &s.codecs.action,
            &packet,
            body[cursor:cursor + n],
            {kind = u16(Kind.Action), epoch = s.cfg.epoch, content = s.cfg.content},
        )

        if decoded.error != .None ||
           packet.generation != peer.generation ||
           packet.serial != peer.serial ||
           packet.tick != meta.tick ||
           packet.sequence == 0 ||
           packet.sequence > max(u64) >> 8 ||
           (i > 0 && packet.sequence != previous + 1) {
            s.stats.rejected_packets += 1
            return
        }

        spans[i] = {cursor, n}
        cursor += n
        previous = packet.sequence
    }

    if cursor != len(body) {
        s.stats.rejected_packets += 1
        return
    }

    // Charge each enclosed action against the ordinary packet admission budget.
    // The outer receive already charged one packet and all actual wire bytes.
    extra := f64(header.count - 1)

    if peer.budget_packets < extra {
        s.stats.rejected_packets += 1
        return
    }

    peer.budget_packets -= extra
    s.stats.action_copy_batches += 1
    s.stats.action_copies += u64(header.count)
    s.stats.action_copy_bytes += u64(len(bytes))
    // Admission hooks run below; retain the validated bytes before invoking them.
    stable: [SNAPSHOT_PART_BYTES]u8
    copy(stable[:], body)

    for span in spans[:header.count] {
        packet: Action_Packet(A)
        _, decoded := sc.unpack(
            &s.codecs.action,
            &packet,
            stable[span[0]:span[0] + span[1]],
            {kind = u16(Kind.Action), epoch = s.cfg.epoch, content = s.cfg.content},
        )
        assert(decoded.error == .None)
        server_action(s, index, packet)
    }
}
