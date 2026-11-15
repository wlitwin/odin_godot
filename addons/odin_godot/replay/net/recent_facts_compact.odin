package replay_net

import "core:reflect"
import r "godot:replay"
import sc "godot:replay/schema"

// Kind 27 shares the outer epoch/content and generation/serial across facts.
// Each entry is age:u8, count:u16 LE, followed by complete canonical occurrences.
// Ages are 3..0, strictly decreasing; no previous packet is needed to decode.
@(private)
server_recent_facts_compact :: proc(s: ^Server($S, $C, $A, $E, $N), index: int) {
    peer := &s.peers[index]
    limit := min(s.cfg.unreliable_packet_limit, s.snapshot_tx[index].part_bytes, SNAPSHOT_PART_BYTES)
    cursor := sc.HEADER_BYTES + s.codecs.recent_facts.wire_size
    count := u8(0)
    first := s.timeline.head > 3 ? s.timeline.head - 3 : 1

    for tick := first; tick <= s.timeline.head; tick += 1 {
        fact := s.facts[tick % u64(s.cfg.history)]

        if fact.tick != tick {
            continue
        }

        if s.model.replication.id != 0 {
            historical, found := r.read(&s.timeline, tick)

            if !found {
                continue
            }

            fact = replica_facts(s.model, historical, Recipient{peer.seat, peer.spectator}, fact)
        }

        if fact.count > WIRE_EVENTS {
            return
        }

        size := 3 + int(fact.count) * s.codecs.occurrence.wire_size

        if cursor + size > limit {
            continue
        }

        s.txb[cursor] = u8(s.timeline.head - tick)
        s.txb[cursor + 1], s.txb[cursor + 2] = u8(fact.count), u8(fact.count >> 8)
        cursor += 3

        for occurrence in fact.events[:fact.count] {
            if sc.encode(&s.codecs.occurrence, occurrence, s.txb[cursor:cursor + s.codecs.occurrence.wire_size]).error !=
               .None {
                return
            }

            cursor += s.codecs.occurrence.wire_size
        }

        count += 1
    }

    if count == 0 {
        return
    }

    header := Recent_Facts_Header{peer.generation, peer.serial, count}
    body := s.txb[sc.HEADER_BYTES:cursor]

    if sc.encode(&s.codecs.recent_facts, header, body[:s.codecs.recent_facts.wire_size]).error != .None {
        return
    }

    meta := sc.Envelope_Meta {
        kind    = u16(Kind.Recent_Facts_Compact),
        epoch   = s.cfg.epoch,
        tick    = s.timeline.head,
        content = s.cfg.content,
    }

    // Bind the event schema as well as the shared header to the envelope.
    if sc.pack_bytes(s.codecs.facts.fingerprint, meta, body, s.txb).error != .None {
        return
    }

    if server_send(s, peer.connection, .Unreliable, s.txb[:cursor]) == .Sent {
        s.stats.redundant_facts += u64(count)
        s.stats.redundant_fact_bytes += u64(cursor)
        s.stats.compact_recent_facts += 1
        s.stats.recent_fact_bytes_saved += u64(count) * u64(2 + sc.HEADER_BYTES + s.codecs.fact_header.wire_size - 3)
    }
}

@(private)
compact_fact_read :: proc(
    codecs: ^Codecs,
    header: Recent_Facts_Header,
    tick: u64,
    bytes: []u8,
    packet: ^Facts_Packet($E),
) -> bool {
    if len(bytes) < 3 || bytes[0] > 3 || u64(bytes[0]) >= tick {
        return false
    }

    count := u16(bytes[1]) | u16(bytes[2]) << 8

    if count > WIRE_EVENTS || len(bytes) != 3 + int(count) * codecs.occurrence.wire_size {
        return false
    }

    packet^ = {
        generation = header.generation,
        serial     = header.serial,
        tick       = tick - u64(bytes[0]),
        count      = count,
    }
    cursor := 3

    for &occurrence in packet.events[:count] {
        if sc.decode(&codecs.occurrence, &occurrence, bytes[cursor:cursor + codecs.occurrence.wire_size]).error !=
           .None {
            return false
        }

        cursor += codecs.occurrence.wire_size
    }

    return true
}

@(private)
client_recent_facts_compact :: proc(
    c: ^Client($S, $C, $A, $E, $N),
    bytes: []u8,
    expected: sc.Envelope_Meta,
) -> (
    error: Error,
) {
    meta, body, report := sc.unpack_bytes(c.codecs.facts.fingerprint, bytes, expected)
    header: Recent_Facts_Header
    header_size := c.codecs.recent_facts.wire_size

    if report.error != .None ||
       len(bytes) > min(c.cfg.unreliable_packet_limit, SNAPSHOT_PART_BYTES) ||
       len(body) < header_size ||
       sc.decode(&c.codecs.recent_facts, &header, body[:header_size]).error != .None ||
       header.generation != c.generation ||
       header.serial != c.serial ||
       header.count == 0 ||
       header.count > 4 {
        c.stats.rejected_packets += 1
        return
    }

    spans: [4][2]int
    cursor := header_size
    previous: u64

    // Preflight the entire bundle before admitting any fact, as in kind 19.
    for i in 0 ..< int(header.count) {
        if len(body) - cursor < 3 {
            c.stats.rejected_packets += 1
            return
        }

        count := u16(body[cursor + 1]) | u16(body[cursor + 2]) << 8
        size := 3 + int(count) * c.codecs.occurrence.wire_size

        if size > len(body) - cursor {
            c.stats.rejected_packets += 1
            return
        }

        packet: Facts_Packet(E)

        if !compact_fact_read(&c.codecs, header, meta.tick, body[cursor:cursor + size], &packet) ||
           packet.tick <= previous {
            c.stats.rejected_packets += 1
            return
        }

        previous = packet.tick

        for occurrence, j in packet.events[:packet.count] {
            if occurrence.id.epoch != c.cfg.epoch || occurrence.id.tick != packet.tick {
                c.stats.rejected_packets += 1
                return
            }

            for prior in packet.events[:j] {
                if prior.id == occurrence.id {
                    c.stats.rejected_packets += 1
                    return
                }
            }
        }

        slot := &c.facts[packet.tick % u64(c.cfg.history)]

        if slot.tick == packet.tick && !reflect.equal(slot^, packet) {
            c.stats.rejected_packets += 1
            return
        }

        spans[i] = {cursor, size}
        cursor += size
    }

    if cursor != len(body) {
        c.stats.rejected_packets += 1
        return
    }

    for span in spans[:header.count] {
        packet: Facts_Packet(E)

        if !compact_fact_read(&c.codecs, header, meta.tick, body[span[0]:span[0] + span[1]], &packet) {
            return .Invalid_Config
        }

        if err := client_accept_facts(c, packet); err != .None {
            return err
        }
    }

    return
}
