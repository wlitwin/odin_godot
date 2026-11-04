package replay_net_parts_reference

import sc "godot:replay/schema"
import tr "godot:replay/transport"
import delta "godot:replay/delta"

// Small enough for Replay's RTC routing/fragment headers as well as an ENet
// datagram. The logical snapshot and canonical codecs remain unchanged.
SNAPSHOT_PARTS_FEATURE :: u64(1)
SNAPSHOT_PART_BYTES :: 1024
SNAPSHOT_ASSEMBLIES :: 4
SNAPSHOT_PART_TIMEOUT_MS :: u64(2000)

@(private)
Snapshot_Assembly :: struct {
    id, tick, digest, started:   u64,
    data:                        []u8,
    mask:                        [4]u64,
    received, parts, part_bytes: int,
}

@(private)
client_features :: proc(c: ^Client($S, $C, $A, $E, $N)) {
    if c.features_sent {
        return
    }

    if !c.snapshot_parts_enabled {
        c.features_sent = true
        return
    }

    packet := Features_Packet {
        c.generation,
        c.serial,
        SNAPSHOT_PARTS_FEATURE,
        u16(min(c.cfg.unreliable_packet_limit, SNAPSHOT_PART_BYTES)),
    }
    c.features_sent = client_send(c, &c.codecs.features, .Features, packet, c.timeline.head, .Reliable) == .Sent
}

// At most one encoded snapshot is retained per recipient. Backpressure resumes
// its remaining pieces before encoding another world; there is no stale-world
// application queue. IDs are reserved even if a reset abandons a partial send.
@(private)
server_snapshot_parts_flush :: proc(s: ^Server($S, $C, $A, $E, $N), index: int) {
    peer := &s.peers[index]
    tx := &s.snapshot_tx[index]

    if tx.part_size == 0 {
        return
    }

    lap, lap_valid := profile_start(s.profile_clock)
    payload := tx.part_bytes - sc.HEADER_BYTES - s.codecs.snapshot_part.wire_size
    parts := (tx.part_size + payload - 1) / payload

    for tx.part_next < parts {
        at := tx.part_next * payload
        count := min(payload, tx.part_size - at)
        header := Snapshot_Part_Header {
            peer.generation,
            peer.serial,
            tx.next_id,
            tx.part_digest,
            u32(tx.part_size),
            u16(tx.part_next),
            u16(tx.part_bytes),
        }
        body := s.txb[sc.HEADER_BYTES:sc.HEADER_BYTES + s.codecs.snapshot_part.wire_size + count]

        if sc.encode(&s.codecs.snapshot_part, header, body[:s.codecs.snapshot_part.wire_size]).error != .None {
            return
        }

        copy(body[s.codecs.snapshot_part.wire_size:], tx.part_wire[at:at + count])
        meta := sc.Envelope_Meta {
            kind    = u16(Kind.Snapshot_Part),
            epoch   = s.cfg.epoch,
            tick    = tx.part_tick,
            content = s.cfg.content,
        }

        if sc.pack_bytes(s.codecs.snapshot_part.fingerprint, meta, body, s.txb).error != .None {
            return
        }

        if server_send(s, peer.connection, .Unreliable, s.txb[:sc.HEADER_BYTES + len(body)]) != .Sent {
            return
        }

        tx.part_next += 1
        s.stats.snapshot_parts_sent += 1
    }

    profile_lap(
        &s.profile_metrics,
        .Snapshot_Send,
        s.profile_clock,
        &lap,
        &lap_valid,
        s.profile_user,
        s.profile_sample,
    )
    slot := tx.sent.next
    assert(delta.cache_note_prehashed(&tx.sent, tx.next_id, tx.scratch, tx.part_hash))
    tx.views[slot] = {tx.next_id, tx.part_tick, s.now, true}
    profile_lap(
        &s.profile_metrics,
        .Snapshot_Cache,
        s.profile_clock,
        &lap,
        &lap_valid,
        s.profile_user,
        s.profile_sample,
    )
    tx.force_full = false
    peer.snapshot_sent = tx.part_tick

    if tx.part_compressed {
        s.stats.delta_snapshots += 1
        s.stats.snapshot_bytes_saved += u64(sc.HEADER_BYTES + len(tx.scratch) - tx.part_size)
    } else {
        s.stats.full_snapshots += 1
    }

    s.stats.fragmented_snapshots += 1
    tx.part_size, tx.part_next = 0, 0
}

@(private)
client_part_drop :: proc(c: ^Client($S, $C, $A, $E, $N), slot: ^Snapshot_Assembly) {
    delete(slot.data, c.allocator)
    slot^ = {}
}

@(private)
client_parts_reset :: proc(c: ^Client($S, $C, $A, $E, $N)) {
    for &slot in c.snapshot_parts {
        client_part_drop(c, &slot)
    }
}

@(private)
client_parts_expire :: proc(c: ^Client($S, $C, $A, $E, $N)) {
    for &slot in c.snapshot_parts {
        if slot.id != 0 && (slot.id <= c.snapshot_latest || c.now - slot.started >= SNAPSHOT_PART_TIMEOUT_MS) {
            client_part_drop(c, &slot)
            c.stats.snapshot_parts_expired += 1
        }
    }
}

@(private)
client_snapshot_part :: proc(c: ^Client($S, $C, $A, $E, $N), bytes: []u8, expected: sc.Envelope_Meta) {
    meta, body, report := sc.unpack_bytes(c.codecs.snapshot_part.fingerprint, bytes, expected)
    header: Snapshot_Part_Header
    size := c.codecs.snapshot_part.wire_size

    if report.error != .None ||
       len(bytes) > SNAPSHOT_PART_BYTES ||
       len(body) < size ||
       sc.decode(&c.codecs.snapshot_part, &header, body[:size]).error != .None ||
       header.generation != c.generation ||
       header.serial != c.serial ||
       header.id == 0 ||
       header.part_bytes < 512 ||
       int(header.part_bytes) > min(SNAPSHOT_PART_BYTES, c.cfg.unreliable_packet_limit) ||
       len(bytes) > int(header.part_bytes) ||
       header.total < sc.HEADER_BYTES ||
       int(header.total) > min(tr.MAX_PACKET_BYTES, c.codecs.snapshot.wire_size + sc.HEADER_BYTES) {
        c.stats.rejected_packets += 1
        return
    }

    if header.id <= c.snapshot_latest {
        return
    }

    payload := int(header.part_bytes) - sc.HEADER_BYTES - size
    parts := (int(header.total) + payload - 1) / payload
    index := int(header.index)

    if parts > 256 || index >= parts || len(body) - size != min(payload, int(header.total) - index * payload) {
        c.stats.rejected_packets += 1
        return
    }

    c.stats.snapshot_parts_received += 1
    at, free, oldest := -1, -1, 0

    for slot, i in c.snapshot_parts {
        if slot.id == header.id {
            at = i
            break
        }

        if slot.id == 0 {
            free = i
        }

        if slot.id < c.snapshot_parts[oldest].id {
            oldest = i
        }
    }

    if at < 0 {
        if free >= 0 {
            at = free
        } else {
            if header.id < c.snapshot_parts[oldest].id {
                return
            }

            at = oldest
            client_part_drop(c, &c.snapshot_parts[at])
            c.stats.snapshot_parts_expired += 1
        }

        c.snapshot_parts[at] = {
            id         = header.id,
            tick       = meta.tick,
            digest     = header.digest,
            started    = c.now,
            data       = make([]u8, int(header.total), c.allocator),
            parts      = parts,
            part_bytes = int(header.part_bytes),
        }
    }

    slot := &c.snapshot_parts[at]

    if len(slot.data) != int(header.total) ||
       slot.tick != meta.tick ||
       slot.digest != header.digest ||
       slot.part_bytes != int(header.part_bytes) {
        client_part_drop(c, slot)
        c.stats.rejected_packets += 1
        return
    }

    offset := index * payload
    incoming := body[size:]
    word := index / 64
    bit := u64(1) << uint(index % 64)

    if slot.mask[word] & bit != 0 {
        for value, i in incoming {
            if value != slot.data[offset + i] {
                client_part_drop(c, slot)
                c.stats.rejected_packets += 1
                return
            }
        }

        return
    }

    copy(slot.data[offset:offset + len(incoming)], incoming)
    slot.mask[word] |= bit
    slot.received += 1

    if slot.received != slot.parts {
        return
    }

    defer client_part_drop(c, slot)

    if sc.digest(slot.data) != slot.digest {
        c.stats.rejected_packets += 1
        return
    }

    inner, _, inner_report := sc.inspect(slot.data)

    if inner_report.error != .None ||
       inner.epoch != c.cfg.epoch ||
       inner.content != c.cfg.content ||
       inner.tick != slot.tick {
        c.stats.rejected_packets += 1
        return
    }

    content := slot.data[sc.HEADER_BYTES:]
    compressed := inner.kind == u16(Kind.Snapshot_Delta)

    if (inner.kind != u16(Kind.Snapshot) && !compressed) ||
       len(content) < (compressed ? 40 : 8) ||
       get64(compressed ? content[32:40] : content[:8]) != slot.id {
        c.stats.rejected_packets += 1
        return
    }

    client_snapshot(c, slot.data, inner, compressed)
}
