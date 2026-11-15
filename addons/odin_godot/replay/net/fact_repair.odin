package replay_net

import r "godot:replay"
import sc "godot:replay/schema"

FACT_REPAIR_INTERVAL_MS :: u64(100)
FACT_REPAIR_MAX_PACKETS :: 4

// This optional extension leaves the reliable fact stream and canonical Facts
// packets intact. A server confirms support only when the client advertised it;
// old protocol-7 peers never receive an unknown request or unsolicited reply.
@(private)
server_features_reply :: proc(s: ^Server($S, $C, $A, $E, $N), index: int) {
    tx := &s.snapshot_tx[index]

    if !tx.feature_reply_pending {
        return
    }

    peer := &s.peers[index]
    features := u64(0)

    if tx.fact_repair_enabled {
        features |= FACT_REPAIR_FEATURE
    }

    if tx.action_copies_enabled {
        features |= RECENT_ACTIONS_FEATURE
    }

    if tx.observer_names {
        features |= OBSERVER_NAMES_FEATURE
    }

    if tx.compact_observations {
        features |= OBSERVATION_COMPACT_FEATURE
    }

    packet := Features_Packet{peer.generation, peer.serial, features, u16(tx.part_bytes)}
    meta := sc.Envelope_Meta {
        kind    = u16(Kind.Features),
        epoch   = s.cfg.epoch,
        tick    = s.timeline.head,
        content = s.cfg.content,
    }

    if sc.pack(&s.codecs.features, packet, meta, s.txb).error != .None {
        return
    }

    if server_send(s, peer.connection, .Reliable, s.txb[:sc.HEADER_BYTES + s.codecs.features.wire_size]) == .Sent {
        tx.feature_reply_pending = false
    }
}

@(private)
client_features_reply :: proc(c: ^Client($S, $C, $A, $E, $N), bytes: []u8, expected: sc.Envelope_Meta) {
    packet: Features_Packet
    _, report := sc.unpack(&c.codecs.features, &packet, bytes, expected)
    offered := OBSERVER_NAMES_FEATURE

    if c.fact_repair_enabled {
        offered |= FACT_REPAIR_FEATURE
    }

    if c.action_copies_enabled {
        offered |= RECENT_ACTIONS_FEATURE
    }

    if c.compact_observations_enabled && c.model.control_timing == .Latest_Observation && !c.spectator {
        offered |= OBSERVATION_COMPACT_FEATURE
    }

    if c.phase != .Running ||
       !c.features_sent ||
       !c.snapshot_parts_enabled ||
       report.error != .None ||
       packet.generation != c.generation ||
       packet.serial != c.serial ||
       packet.features == 0 ||
       packet.features &~ offered != 0 ||
       packet.part_bytes < 512 ||
       int(packet.part_bytes) > min(c.cfg.unreliable_packet_limit, SNAPSHOT_PART_BYTES) {
        c.stats.rejected_packets += 1
        return
    }

    c.fact_repair_negotiated = packet.features & FACT_REPAIR_FEATURE != 0
    c.action_copies_negotiated = packet.features & RECENT_ACTIONS_FEATURE != 0
    c.observer_names_negotiated = packet.features & OBSERVER_NAMES_FEATURE != 0
    c.compact_observations_negotiated = packet.features & OBSERVATION_COMPACT_FEATURE != 0
}

@(private)
client_request_facts :: proc(c: ^Client($S, $C, $A, $E, $N)) {
    if !c.fact_repair_negotiated ||
       c.facts_contiguous >= c.authority_tick_seen ||
       (c.fact_repair_sent && c.now - c.fact_repair_last < FACT_REPAIR_INTERVAL_MS) {
        return
    }

    first := c.facts_contiguous + 1
    missing := u32(0)
    count := 0
    last := min(c.authority_tick_seen, first + min(u64(31), max(u64) - first))

    for tick := first; tick <= last; tick += 1 {
        if c.facts[tick % u64(c.cfg.history)].tick != tick {
            missing |= u32(1) << uint(tick - first)
            count += 1
        }

        if count == FACT_REPAIR_MAX_PACKETS || tick == max(u64) {
            break
        }
    }

    if missing == 0 {
        return
    }

    packet := Facts_Request{c.generation, c.serial, first, missing}

    if client_send(c, &c.codecs.facts_request, .Facts_Request, packet, c.timeline.head, .Unreliable) == .Sent {
        c.fact_repair_sent, c.fact_repair_last = true, c.now
        c.stats.fact_repair_requests += 1
    }
}

@(private)
server_repair_facts :: proc(s: ^Server($S, $C, $A, $E, $N), index: int, bytes: []u8, expected: sc.Envelope_Meta) {
    peer := &s.peers[index]
    tx := &s.snapshot_tx[index]
    packet: Facts_Request
    _, report := sc.unpack(&s.codecs.facts_request, &packet, bytes, expected)

    if !tx.fact_repair_enabled ||
       report.error != .None ||
       packet.generation != peer.generation ||
       packet.serial != peer.serial ||
       packet.first == 0 ||
       packet.first > s.timeline.head ||
       packet.missing == 0 ||
       packet.missing & 1 == 0 {
        s.stats.rejected_packets += 1
        return
    }

    // Validate the whole request before replying. Only retained, already-published
    // ticks qualify; never trigger a checkpoint or send unbounded reliable data.
    count := 0

    for bit in 0 ..< 32 {
        if packet.missing & (u32(1) << uint(bit)) == 0 {
            continue
        }

        if u64(bit) > s.timeline.head - packet.first {
            s.stats.rejected_packets += 1
            return
        }

        tick := packet.first + u64(bit)
        count += 1

        if count > FACT_REPAIR_MAX_PACKETS || tick > peer.facts_sent || s.timeline.head - tick >= u64(s.cfg.history) {
            s.stats.rejected_packets += 1
            return
        }
    }

    if tx.fact_repair_sent && s.now - tx.fact_repair_last < FACT_REPAIR_INTERVAL_MS {
        return
    }

    tx.fact_repair_sent, tx.fact_repair_last = true, s.now
    s.stats.fact_repair_requests += 1
    limit := min(s.cfg.unreliable_packet_limit, tx.part_bytes)

    for bit in 0 ..< 32 {
        if packet.missing & (u32(1) << uint(bit)) == 0 {
            continue
        }

        tick := packet.first + u64(bit)
        fact := s.facts[tick % u64(s.cfg.history)]

        if fact.tick != tick {
            continue
        }

        fact.generation, fact.serial = peer.generation, peer.serial

        if s.model.replication.id != 0 {
            historical, found := r.read(&s.timeline, tick)

            if !found {
                continue
            }

            fact = replica_facts(s.model, historical, Recipient{peer.seat, peer.spectator}, fact)
        }

        meta := sc.Envelope_Meta {
            kind    = u16(Kind.Facts),
            epoch   = s.cfg.epoch,
            tick    = tick,
            content = s.cfg.content,
        }
        size, ok := pack_facts(&s.codecs, fact, meta, s.txb[:limit])

        if !ok {
            s.stats.fact_repair_oversize += 1
            continue
        }

        if server_send(s, peer.connection, .Unreliable, s.txb[:size]) != .Sent {
            break
        }

        s.stats.fact_repairs += 1
        s.stats.fact_repair_bytes += u64(size)
    }
}
