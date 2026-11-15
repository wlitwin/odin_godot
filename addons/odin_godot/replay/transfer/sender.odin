package replay_transfer

import "core:mem"
import replay "godot:replay"
import compression "godot:replay/compress"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

sender_init :: proc(
    s: ^Sender,
    scope: Scope,
    target: tr.Peer_Id,
    wire: tr.Transport,
    cfg := DEFAULT_CONFIG,
    allocator := context.allocator,
    archive_kind: u16 = 0,
    kind_base: u16 = DEFAULT_KIND_BASE,
    max_bytes: int = MAX_BYTES,
    budget: Budget = {},
    ownership: Ownership = {},
) -> Error {
    if s.owner_state.cleanup ||
       s.ready ||
       !config_valid(scope, target, cfg, kind_base, max_bytes) ||
       archive_kind == 0 {
        return .Invalid_Config
    }

    if error := ownership_entry(ownership, allocator, s, wire.user, nil, nil, budget.user); error != .None {
        return error
    }

    s.ownership = ownership

    if error := ownership_retain(&s.owner_state, ownership); error != .None {
        retained := s.owner_state.retains
        s^ = {}

        if replay.owner_retains_drop(&retained) != .None {
            s.owner_state = {
                retains = retained,
                cleanup = true,
            }
        }

        return error
    }

    committed_owner := false

    defer if !committed_owner {
        sender_destroy(s)
    }

    s.allocator, s.scope, s.target, s.wire, s.cfg = allocator, scope, target, wire, cfg
    s.archive_kind, s.kind_base, s.max_bytes = archive_kind, kind_base, max_bytes

    if error := budget_begin(&s.budget, budget, u64(size_of(Sender))); error != .None {
        return error
    }

    schema_allocator, error := budget_schema_allocator(&s.budget, allocator)

    if error != .None {
        return error
    }

    if !codecs_init(&s.codecs, schema_allocator) {
        return .Invalid_Config
    }

    committed_owner = true
    s.ready = true
    return .None
}

sender_destroy :: proc(s: ^Sender) -> Error {
    when #config(BOX3D_REQUIRE_DOMAIN, false) {
        if !s.ready &&
           replay.owner_is_nil(s.ownership.container.owner) &&
           s.owner_state.retains.count == 0 &&
           !s.budget.attached {
            return .None
        }
    }

    if error := sender_owner_entry(s, .Read); error != .None {
        return error
    }

    if s.owner_state.cleanup {
        state := s.owner_state
        s^ = {}

        if replay.owner_retains_drop(&state.retains) != .None {
            s.owner_state = state
            return .Invalid_Config
        }

        return .None
    }

    budget_free(&s.budget, &s.bytes, s.allocator)
    budget_free(&s.budget, &s.wire_bytes, s.allocator)
    codecs_destroy(&s.codecs)
    budget_end(&s.budget, s.allocator)
    state := s.owner_state
    s^ = {}

    if replay.owner_retains_drop(&state.retains) != .None {
        state.cleanup = true
        s.owner_state = state
        return .Invalid_Config
    }

    return .None
}

sender_budget_attach :: proc(s: ^Sender, budget: Budget) -> Error {
    if error := sender_owner_entry(s); error != .None {
        return error
    }

    if replay.owned_context_access(
           s.ownership.budget,
           budget.user,
           !replay.owner_is_nil(s.ownership.container.owner),
           .Execute,
       ) !=
       .None {
        return .Invalid_Config
    }

    if !s.ready {
        return .Wrong_Phase
    }

    return budget_begin(
        &s.budget,
        budget,
        u64(size_of(Sender)) + budget_codecs_bytes(&s.codecs) + u64(len(s.bytes) + len(s.wire_bytes)),
    )
}

// Makes an owned copy. One archive is in flight at a time; cancel explicitly if
// replacing it. acknowledged continues to name the last fully validated receipt.
sender_begin :: proc(s: ^Sender, bytes: []u8, now_ms: u64, channel: tr.Channel = .Unreliable) -> Error {
    if error := sender_owner_entry(s); error != .None {
        return error
    }

    if !s.ready || s.phase == .Sending {
        return .Wrong_Phase
    }

    if channel > .Unreliable {
        return .Invalid_Config
    }

    clock := s.clock

    if !clock_at(&clock, now_ms, s.cfg) {
        return .Invalid_Time
    }

    if len(bytes) > s.max_bytes {
        return .Capacity
    }

    meta, fingerprint, report := sc.inspect(bytes)

    if report.error != .None ||
       meta.kind != s.archive_kind ||
       meta.epoch != s.scope.epoch ||
       meta.content != s.scope.content ||
       meta.tick < s.highest_tick {
        return .Invalid_Archive
    }

    _, _, checked := sc.unpack_bytes(fingerprint, bytes, expected(s.scope, s.archive_kind))

    if checked.error != .None {
        return .Invalid_Archive
    }

    if s.next_sequence == max(u64) {
        return .Capacity
    }

    candidate, error := budget_alloc(&s.budget, len(bytes), s.allocator)

    if error != .None {
        return error
    }

    copy(candidate, bytes)
    candidate_wire: []u8
    committed := false

    defer if !committed {
        budget_free(&s.budget, &candidate, s.allocator)
        budget_free(&s.budget, &candidate_wire, s.allocator)
    }

    wire_layout: u64
    shuffled, saved := u64(0), u64(0)

    if s.compress {
        workspace, work_error := budget_alloc(&s.budget, size_of(compression.Workspace), s.allocator)

        if work_error != .None {
            return work_error
        }

        defer budget_free(&s.budget, &workspace, s.allocator)
        work := cast(^compression.Workspace)raw_data(workspace)
        encoded, encode_error := budget_alloc(&s.budget, len(bytes), s.allocator)

        if encode_error != .None {
            return encode_error
        }

        defer budget_free(&s.budget, &encoded, s.allocator)
        n, valid := compression.encode(candidate, encoded, work)

        if valid && n < len(bytes) {
            candidate_wire, error = budget_alloc(&s.budget, n, s.allocator)

            if error != .None {
                return error
            }

            copy(candidate_wire, encoded[:n])
        }

        if s.shuffle {
            id := layout_signature(s.layout, len(candidate))

            if id != 0 {
                grouped, group_error := budget_alloc(&s.budget, len(candidate), s.allocator)

                if group_error != .None {
                    return group_error
                }

                defer budget_free(&s.budget, &grouped, s.allocator)
                copy(grouped, candidate)
                offset, size := s.layout.offset, s.layout.schema.wire_size

                if sc.shuffle(s.layout.schema, candidate[offset:offset + size], grouped[offset:offset + size]) {
                    prior := len(candidate_wire) > 0 ? len(candidate_wire) : len(candidate)
                    count, valid := compression.encode(grouped, encoded, work)
                    overhead := len(candidate_wire) > 0 ? 8 : 12

                    if valid && count + overhead < prior {
                        replacement, replacement_error := budget_alloc(&s.budget, count, s.allocator)

                        if replacement_error != .None {
                            return replacement_error
                        }

                        copy(replacement, encoded[:count])
                        budget_free(&s.budget, &candidate_wire, s.allocator)
                        candidate_wire = replacement
                        wire_layout = id
                        shuffled = 1
                        saved = u64(prior - count)
                    }
                }
            }
        }
    }

    // All allocations and compression succeed before replacing any published
    // sender payload, sequence, receipt, clock, or compression metadata.
    budget_free(&s.budget, &s.bytes, s.allocator)
    budget_free(&s.budget, &s.wire_bytes, s.allocator)
    s.bytes, s.wire_bytes, s.wire_layout = candidate, candidate_wire, wire_layout
    s.channel, s.clock = channel, clock
    s.next_sequence += 1
    s.archive = {
        sequence = s.next_sequence,
        tick     = meta.tick,
        bytes    = u32(len(bytes)),
        hash     = hash(candidate),
    }
    s.highest_tick = meta.tick
    s.phase, s.error, s.remote_failure = .Sending, .None, .None
    s.started, s.offer_ever, s.offer_acked = now_ms, false, false
    s.acked, s.sent, s.sent_at = {}, {}, {}
    s.stats.shuffled_archives += shuffled
    s.stats.shuffle_bytes_saved += saved
    committed = true
    return .None
}

sender_cancel :: proc(s: ^Sender) {
    if error := sender_owner_entry(s); error != .None {
        return
    }

    if !s.ready {
        return
    }

    budget_free(&s.budget, &s.bytes, s.allocator)
    budget_free(&s.budget, &s.wire_bytes, s.allocator)
    s.wire_layout = 0
    s.phase, s.error = .Idle, .None
}

sender_update :: proc(s: ^Sender, now_ms: u64, max_output_bytes: u32 = max(u32)) -> Error {
    if error := sender_owner_entry(s); error != .None {
        return error
    }

    if !s.ready {
        return .Wrong_Phase
    }

    if !clock_at(&s.clock, now_ms, s.cfg) {
        return .Invalid_Time
    }

    if s.phase != .Sending {
        return .None
    }

    if now_ms - s.started >= s.cfg.timeout_ms {
        sender_fail(s, .Timeout)
        return .Timeout
    }

    if !tr.peer_connected(&s.wire, s.target) {
        return .Transport
    }

    remaining := int(min(s.cfg.bytes_per_update, max_output_bytes))

    if !s.offer_ever || ((s.channel == .Unreliable || !s.offer_acked) && now_ms - s.offer_sent >= s.cfg.retry_ms) {
        value := Offer {
            key             = key_for(s.scope),
            version         = PROTOCOL_VERSION,
            chunk_bytes     = CHUNK_BYTES,
            archive         = s.archive,
            retain_sequence = s.acknowledged.archive.sequence,
            retain_hash     = s.acknowledged.archive.hash,
        }
        sent: bool

        if s.wire_layout != 0 {
            sent = send_value(
                &s.wire,
                s.target,
                &s.codecs.shuffled_offer,
                Shuffled_Offer{value, u32(len(s.wire_bytes)), s.wire_layout},
                s.scope,
                s.kind_base + u16(Kind.Shuffled_Offer),
                s.archive.tick,
                s.txb[:],
                &s.clock,
                &remaining,
                &s.stats,
                s.channel,
            )
        } else if len(s.wire_bytes) > 0 {
            sent = send_value(
                &s.wire,
                s.target,
                &s.codecs.compressed_offer,
                Compressed_Offer{value, u32(len(s.wire_bytes))},
                s.scope,
                s.kind_base + u16(Kind.Compressed_Offer),
                s.archive.tick,
                s.txb[:],
                &s.clock,
                &remaining,
                &s.stats,
                s.channel,
            )
        } else {
            sent = send_value(
                &s.wire,
                s.target,
                &s.codecs.offer,
                value,
                s.scope,
                s.kind_base + u16(Kind.Offer),
                s.archive.tick,
                s.txb[:],
                &s.clock,
                &remaining,
                &s.stats,
                s.channel,
            )
        }

        if sent {
            if s.offer_ever {
                s.stats.retries += 1
            }

            s.offer_sent, s.offer_ever = now_ms, true
        }
    }

    if !s.offer_acked {
        return .None
    }

    first := 0
    count := chunk_count(len(sender_wire_bytes(s)))

    for first < count && s.acked[first] {
        first += 1
    }

    for index in first ..< min(count, first + int(s.cfg.window)) {
        if s.acked[index] ||
           (s.sent[index] && (s.channel == .Reliable || now_ms - s.sent_at[index] < s.cfg.retry_ms)) {
            continue
        }

        header := Chunk{key_for(s.scope), s.archive.sequence, u16(index)}
        wire_bytes := sender_wire_bytes(s)
        size := min(CHUNK_BYTES, len(wire_bytes) - index * CHUNK_BYTES)
        body := s.txb[sc.HEADER_BYTES:sc.HEADER_BYTES + s.codecs.chunk.wire_size + size]

        if sc.encode(&s.codecs.chunk, header, body[:s.codecs.chunk.wire_size]).error != .None {
            return .Invalid_Archive
        }

        copy(body[s.codecs.chunk.wire_size:], wire_bytes[index * CHUNK_BYTES:index * CHUNK_BYTES + size])
        meta := sc.Envelope_Meta {
            kind    = s.kind_base + u16(Kind.Chunk),
            epoch   = s.scope.epoch,
            tick    = s.archive.tick,
            content = s.scope.content,
        }

        if sc.pack_bytes(s.codecs.chunk.fingerprint, meta, body, s.txb[:]).error != .None {
            return .Invalid_Archive
        }

        if !send(&s.wire, s.target, s.txb[:sc.HEADER_BYTES + len(body)], &s.clock, &remaining, &s.stats, s.channel) {
            break
        }

        if s.sent[index] {
            s.stats.retries += 1
        }

        s.sent[index], s.sent_at[index] = true, now_ms
    }

    return .None
}

sender_receive :: proc(s: ^Sender, from: tr.Peer_Id, bytes: []u8, now_ms: u64) -> Received {
    if error := sender_owner_entry(s); error != .None {
        return .Rejected
    }

    if !s.ready || !handles(bytes, s.kind_base) {
        return .Ignored
    }

    s.stats.rx_packets += 1
    s.stats.rx_bytes += u64(len(bytes))

    if len(bytes) > CHUNK_BYTES + 128 ||
       from != s.target ||
       s.phase != .Sending ||
       !clock_at(&s.clock, now_ms, s.cfg) {
        s.stats.rejected += 1
        return .Rejected
    }

    if now_ms - s.started >= s.cfg.timeout_ms {
        sender_fail(s, .Timeout)
        s.stats.rejected += 1
        return .Rejected
    }

    meta, _, _ := sc.inspect(bytes)

    if meta.tick != s.archive.tick {
        s.stats.rejected += 1
        return .Rejected
    }

    #partial switch Kind(meta.kind - s.kind_base) {
    case .Progress:
        packet: Progress
        _, report := sc.unpack(&s.codecs.progress, &packet, bytes, expected(s.scope, meta.kind))

        if report.error != .None || packet.key != key_for(s.scope) || packet.sequence != s.archive.sequence {
            break
        }

        if packet.group == OFFER_GROUP {
            if packet.mask != 0 {
                break
            }

            s.offer_acked = true
            return .Accepted
        }

        count := chunk_count(len(sender_wire_bytes(s)))

        if int(packet.group) >= (count + 63) / 64 {
            break
        }

        bits := min(64, count - int(packet.group) * 64)

        if bits < 64 && packet.mask >> uint(bits) != 0 {
            break
        }

        // An ACK cannot acknowledge a chunk that has never left the sender.
        for bit in 0 ..< bits {
            if packet.mask & (u64(1) << uint(bit)) != 0 && !s.sent[int(packet.group) * 64 + bit] {
                s.stats.rejected += 1
                return .Rejected
            }
        }

        for bit in 0 ..< bits {
            if packet.mask & (u64(1) << uint(bit)) != 0 {
                s.acked[int(packet.group) * 64 + bit] = true
            }
        }

        return .Accepted
    case .Ready:
        packet: Ready
        _, report := sc.unpack(&s.codecs.ready, &packet, bytes, expected(s.scope, meta.kind))

        if report.error != .None || packet.key != key_for(s.scope) || packet.archive != s.archive {
            break
        }

        s.acknowledged = {s.archive, now_ms}
        s.phase = .Complete
        return .Validated
    case .Failed:
        packet: Failed
        _, report := sc.unpack(&s.codecs.failure, &packet, bytes, expected(s.scope, meta.kind))

        if report.error != .None ||
           packet.key != key_for(s.scope) ||
           packet.sequence != s.archive.sequence ||
           packet.reason == .None {
            break
        }

        s.remote_failure = packet.reason
        sender_fail(s, .Remote_Rejected)
        return .Accepted
    }

    s.stats.rejected += 1
    return .Rejected
}

@(private)
sender_fail :: proc(s: ^Sender, error: Error) {
    if error := sender_owner_entry(s); error != .None {
        return
    }

    s.phase, s.error = .Failed, error
    s.stats.failures += 1
}

@(private)
sender_wire_bytes :: proc(s: ^Sender) -> []u8 {
    if error := sender_owner_entry(s); error != .None {
        return nil
    }

    return len(s.wire_bytes) > 0 ? s.wire_bytes : s.bytes
}

@(private)
sender_owner_entry :: proc(s: ^Sender, access: replay.Owner_Access = .Execute) -> Error {
    if s == nil {
        return .Invalid_Config
    }

    if s.owner_state.cleanup {
        return(
            access == .Read && replay.owner_retains_access(&s.owner_state.retains, .Read) == .None ? Error.None : Error.Invalid_Config \
        )
    }

    return ownership_entry(s.ownership, s.allocator, s, s.wire.user, nil, s.layout.schema, s.budget.hooks.user, access)
}
