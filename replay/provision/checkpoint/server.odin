package replay_checkpoint

import "core:crypto"
import "core:mem"
import auth "godot:replay/authority"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"

// One transfer per room, with bounded lifetime and memory. Own at a stable address
// beside its authority.Service; the embedding multiplexes input and renewals.
Server :: struct {
    ready:                         bool,
    previous_owner_rebind:         bool,
    allocator:                     mem.Allocator,
    authority:                     ^auth.Service,
    backend:                       Backend,
    wire:                          tr.Transport,
    data_channel:                  tr.Channel,
    codecs:                        Codecs,
    lane:                          Lane,
    receiver:                      tf.Blob_Receiver,
    sender:                        tf.Sender,
    reply:                         Reply,
    restore_receipt:               Reply,
    status_receipt:                Reply,
    status_at:                     u64,
    active:                        bool,
    serial, started, now:          u64,
    budget:                        f64,
    controls:                      [auth.MAX_MEMBERS]f64,
    received, rejected, published: u64,
    txb:                           [PACKET_BYTES]u8,
}

server_open :: proc(
    s: ^Server,
    authority: ^auth.Service,
    backend: Backend,
    wire: tr.Transport,
    data_channel: tr.Channel = .Reliable,
    allocator := context.allocator,
) -> bool {
    if s.ready ||
       authority == nil ||
       !authority.ready ||
       backend.load == nil ||
       backend.publish == nil ||
       data_channel > .Unreliable {
        return false
    }

    s.allocator, s.authority, s.backend, s.wire = allocator, authority, backend, wire
    s.previous_owner_rebind = authority.allow_expired_owner_rebind
    s.data_channel = data_channel

    if !codecs_init(&s.codecs, allocator) {
        server_close(s)
        return false
    }

    now, ok := authority.clock.read(authority.clock.user)

    if !ok {
        server_close(s)
        return false
    }

    s.now, s.budget, s.ready = now, 64, true

    for &b in s.controls {
        b = 8
    }

    if backend.recover != nil {
        authority.allow_expired_owner_rebind = true
    }

    return true
}

server_close :: proc(s: ^Server) {
    if s.authority != nil {
        s.authority.allow_expired_owner_rebind = s.previous_owner_rebind
    }

    server_clear(s)
    codecs_destroy(&s.codecs)
    s^ = {}
}

@(private)
server_clear :: proc(s: ^Server) {
    tf.blob_destroy(&s.receiver)
    tf.sender_destroy(&s.sender)
    crypto.zero_explicit(&s.lane, size_of(s.lane))
    s.active = false
    s.reply = {}
}

@(private)
server_clock :: proc(s: ^Server) -> bool {
    now, ok := s.authority.clock.read(s.authority.clock.user)

    if !ok || now < s.now {
        s.authority.coordinator.poisoned, s.authority.coordinator.active = true, false
        return false
    }

    s.budget = min(64, s.budget + f64(now - s.now) * 128 / 1000)

    for &b in s.controls {
        b = min(8, b + f64(now - s.now) * 4 / 1000)
    }

    s.now = now
    return true
}

@(private)
server_member :: proc(s: ^Server, q: Request, from: tr.Peer_Id) -> (auth.Key, int, bool) {
    r := s.authority.coordinator.record

    if !s.authority.ready ||
       s.authority.coordinator.poisoned ||
       q.room != r.room ||
       q.content != r.content ||
       q.generation != r.coordinator_generation {
        return {}, 0, false
    }

    for m, i in r.members {
        if m.identity == q.identity {
            if !m.enabled ||
               !m.can_host ||
               !m.trusted_authority ||
               (r.policy.mode == .Dedicated && !m.infrastructure) ||
               r.requests[i].nonce != q.nonce ||
               s.authority.active_peer[i] != from ||
               s.authority.active_generation[i] != tr.peer_generation(&s.wire, from) ||
               !tr.peer_connected(&s.wire, from) {
                return {}, 0, false
            }

            for c in s.authority.credentials {
                if c.identity.member == m.identity.member {
                    return c.key, i, c.key != (auth.Key{})
                }
            }
        }
    }

    return {}, 0, false
}

@(private)
server_owner :: proc(s: ^Server, q: Request) -> bool {
    v, e := auth.coordinator_view(&s.authority.coordinator, s.now)
    return e == .None && v.remaining_ms > 0 && v.owner == q.identity && v.epoch == q.point.scope.epoch
}

@(private)
server_reply :: proc(s: ^Server, from: tr.Peer_Id, value: Reply, key: auth.Key) {
    n := pack(&s.codecs.reply, value, key, REPLY_KIND, value.request.content, value.request.sequence, s.txb[:])

    if n > 0 {
        tr.send(&s.wire, from, .Reliable, s.txb[:n])
    }
}

server_receive :: proc(s: ^Server, from: tr.Peer_Id, bytes: []u8) -> bool {
    if !s.ready || from == 0 || len(bytes) < sc.HEADER_BYTES + 32 || len(bytes) > PACKET_BYTES || !server_clock(s) {
        return false
    }

    meta, _, inspected := sc.inspect(bytes[:len(bytes) - 32])

    if inspected.error != .None {
        return false
    }

    if meta.kind == UPSTREAM_KIND {
        if !s.active || s.budget < 1 {
            s.rejected += 1
            return false
        }

        s.budget -= 1
        _, _, allowed := server_member(s, s.lane.request, from)
        d, valid := lane_read(&s.lane, from, bytes, UPSTREAM_KIND)

        if !allowed || !valid || s.now - s.started >= tf.DEFAULT_CONFIG.timeout_ms {
            s.rejected += 1
            return false
        }

        if s.lane.request.verb == .Upload {
            if !s.reply.complete && !server_owner(s, s.lane.request) {
                s.reply.error = .Denied
                server_reply(s, from, s.reply, s.lane.key)
                server_clear(s)
                return true
            }

            tf.blob_receive(&s.receiver, from, d.bytes[:d.count], s.now)
        } else {
            tf.sender_receive(&s.sender, from, d.bytes[:d.count], s.now)
        }

        return true
    }

    if meta.kind != REQUEST_KIND {
        return false
    }

    q: Request

    if !read(&s.codecs.request, &q, bytes, REQUEST_KIND, s.authority.coordinator.record.content) ||
       !request_valid(q) ||
       meta.tick != q.sequence {
        return false
    }

    key, index, allowed := server_member(s, q, from)

    if !allowed || !authenticated(key, REQUEST_KIND, bytes) {
        s.rejected += 1
        return false
    }

    if s.budget < 1 || s.controls[index] < 1 {
        s.rejected += 1
        return true
    }

    s.budget -= 1
    s.controls[index] -= 1
    s.received += 1
    digest := tf.hash(bytes[:len(bytes) - 32])

    if q.verb == .Status &&
       s.status_receipt.request == q &&
       s.status_receipt.request_hash == digest &&
       s.now - s.status_at < tf.DEFAULT_CONFIG.timeout_ms {
        // A retry repeats one read result; a new sequence requests a fresh view.
        server_reply(s, from, s.status_receipt, key)
        return true
    }

    if q.verb == .Restore {
        reply := Reply {
            request      = q,
            request_hash = digest,
        }
        frontier := s.authority.coordinator.record.requests[index]

        if q.sequence < frontier.sequence || (q.sequence == frontier.sequence && digest != frontier.hash) {
            reply.error, reply.recovery_result = .Stale, .Stale
            reply.view, _ = auth.coordinator_view(&s.authority.coordinator, s.now)
            server_reply(s, from, reply, key)
            return true
        }

        if q.sequence == frontier.sequence &&
           digest == frontier.hash &&
           s.restore_receipt.request == q &&
           s.restore_receipt.request_hash == digest &&
           s.restore_receipt.recovery_result == frontier.result {
            // The authenticated durable frontier proves this exact outcome. Avoid
            // decoding the world again for every retry while renewal is queued.
            reply = s.restore_receipt
            reply.replayed = true
            reply.view, _ = auth.coordinator_view(&s.authority.coordinator, s.now)
            server_reply(s, from, reply, key)
            return true
        }

        saved, found, error := s.backend.load(s.backend.user, q.room, q.content, s.allocator)
        defer saved_destroy(&saved)

        if error != .None {
            reply.error = error
        } else if !found ||
           saved.publication.revision != q.revision ||
           saved.publication.point != q.point ||
           saved.publication.contract != q.contract {
            reply.error = .Stale
        } else if s.backend.recover == nil {
            reply.error = .Denied
        } else {
            reply.recovery_result, reply.replayed = s.backend.recover(
                s.backend.user,
                s.authority,
                from,
                q.identity,
                q.nonce,
                q.sequence,
                digest,
                q.authority_epoch,
                saved.publication,
            )
            reply.error = recovery_error(reply.recovery_result)

            if reply.error == .None {
                reply.publication, reply.complete = saved.publication, true
            }
        }

        now, ok := s.authority.clock.read(s.authority.clock.user)

        if ok {
            reply.view, _ = auth.coordinator_view(&s.authority.coordinator, now)
        }

        frontier = s.authority.coordinator.record.requests[index]

        if frontier.sequence == q.sequence && frontier.hash == digest && frontier.result == reply.recovery_result {
            s.restore_receipt = reply
        }

        server_reply(s, from, reply, key)
        return true
    }

    if s.active &&
       s.now - s.started < tf.DEFAULT_CONFIG.timeout_ms &&
       s.lane.peer == from &&
       s.reply.request == q &&
       s.reply.request_hash == digest {
        server_reply(s, from, s.reply, key)
        return true
    }

    reply := Reply {
        request      = q,
        request_hash = digest,
    }
    // An explicit newer operation by the same registered process may supersede
    // its transfer, including a download whose final ACK was lost. Other members
    // cannot evict it, and a changed payload at the same sequence cannot replace it.
    replaces_own :=
        s.active &&
        from == s.lane.peer &&
        q.identity == s.lane.request.identity &&
        q.nonce == s.lane.request.nonce &&
        q.sequence > s.lane.request.sequence

    if s.active &&
       !replaces_own &&
       s.now - s.started < tf.DEFAULT_CONFIG.timeout_ms &&
       !s.reply.complete &&
       s.sender.phase != .Complete &&
       s.sender.phase != .Failed {
        reply.error = .Busy
        server_reply(s, from, reply, key)
        return true
    }

    saved, found, error := s.backend.load(s.backend.user, q.room, q.content, s.allocator)
    defer saved_destroy(&saved)

    if error != .None {
        reply.error = error
    } else if found &&
       (!saved.ready ||
               !publication_valid(saved.publication) ||
               saved.publication.point.scope.room != q.room ||
               saved.publication.point.scope.content != q.content ||
               saved.publication.contract != q.contract) {
        reply.error = .Schema
    }

    if reply.error == .None {
        if q.verb == .Status {
            reply.complete = true

            if found {
                reply.publication = saved.publication
                reply.payload = payload_for(saved.publication.point, saved.payload)
            } else {
                reply.error = .Missing
            }
        } else if q.verb == .Upload &&
           found &&
           saved.publication.publisher == q.identity &&
           saved.publication.point == q.point {
            reply.complete = true
            reply.publication = saved.publication
        } else if q.verb == .Upload && !server_owner(s, q) {
            reply.error = .Denied
        } else if (found && q.revision != saved.publication.revision) || (!found && q.revision != 0) {
            reply.error = .Stale
        } else if q.verb == .Download && !found {
            reply.error = .Missing
        }
    }

    if reply.error != .None || reply.complete {
        if q.verb == .Status {
            s.status_receipt, s.status_at = reply, s.now
        }

        server_reply(s, from, reply, key)
        return true
    }

    if s.serial == max(u64) {
        reply.error = .Capacity
        server_reply(s, from, reply, key)
        return true
    }

    server_clear(s)
    s.serial += 1
    s.started = s.now
    s.reply = reply
    s.reply.transfer = s.serial
    s.lane = {
        wire         = s.wire,
        peer         = from,
        key          = key,
        request      = q,
        request_hash = digest,
        transfer     = s.serial,
        out_kind     = DOWNSTREAM_KIND,
        channel      = s.data_channel,
        codecs       = &s.codecs,
    }

    if q.verb == .Upload {
        payload := q.payload

        if payload == (Payload{}) {
            payload = payload_for(q.point)
        }

        if tf.blob_init(
               &s.receiver,
               q.point.scope,
               from,
               lane_wire(&s.lane),
               payload.kind,
               server_accept,
               s,
               allocator = s.allocator,
               kind_base = TRANSFER_BASE,
               max_bytes = int(payload.bytes),
           ) !=
           .None {
            s.reply.error = .Capacity
        }
    } else {
        s.reply.publication = saved.publication
        s.reply.payload = payload_for(saved.publication.point, saved.payload)
        point := saved.publication.point

        if tf.sender_init(
               &s.sender,
               point.scope,
               from,
               lane_wire(&s.lane),
               allocator = s.allocator,
               archive_kind = s.reply.payload.kind,
               kind_base = TRANSFER_BASE,
           ) !=
           .None {
            s.reply.error = .Capacity
        } else {
            s.sender.next_sequence = point.archive.sequence - 1
            bytes := len(saved.payload) > 0 ? saved.payload : saved.bytes

            if tf.sender_begin(&s.sender, bytes, s.now) != .None {
                s.reply.error = .Schema
            }
        }
    }

    s.active = s.reply.error == .None
    server_reply(s, from, s.reply, key)
    return true
}

@(private)
recovery_error :: proc(error: auth.Error) -> Error {
    switch error {
    case .None:
        return .None
    case .Busy:
        return .Busy
    case .Stale:
        return .Stale
    case .Storage:
        return .Storage
    case .Clock:
        return .Clock
    case .Capacity:
        return .Capacity
    case .No_Checkpoint:
        return .Missing
    case .Invalid:
        return .Invalid
    case .Denied, .Too_Old, .Not_Ready:
        return .Denied
    }

    return .Invalid
}

@(private)
server_accept :: proc(user: rawptr, archive: tf.Archive, bytes: []u8) -> bool {
    s := cast(^Server)user
    q := s.lane.request
    _, _, allowed := server_member(s, q, s.lane.peer)
    descriptor := q.payload

    if descriptor == (Payload{}) {
        descriptor = payload_for(q.point)
    }

    if !server_clock(s) ||
       !allowed ||
       !server_owner(s, q) ||
       archive.sequence != q.point.archive.sequence ||
       archive.tick != q.point.archive.tick ||
       archive.bytes != descriptor.bytes ||
       archive.hash != descriptor.hash {
        s.reply.error = .Denied
        return false
    }

    root := bytes
    payload: []u8

    if descriptor.kind == PACKAGE_KIND {
        view, error := package_view(bytes, q.point)

        if error != .None {
            s.reply.error = error
            return false
        }

        root, payload = view.root, bytes
    }

    publication, error := s.backend.publish(
        s.backend.user,
        s.authority.coordinator.record,
        q.revision,
        q.contract,
        q.point,
        root,
        {s, server_commit_allowed},
        payload,
    )

    if error != .None && s.reply.error == .Denied {
        error = .Denied
    }

    s.reply.error = error

    if error != .None {
        return false
    }

    if !publication_valid(publication) ||
       publication.point != q.point ||
       publication.publisher != q.identity ||
       publication.contract != q.contract {
        s.reply.error = .Schema
        return false
    }

    s.reply.publication, s.reply.complete = publication, true
    s.published += 1
    return true
}

@(private)
server_commit_allowed :: proc(user: rawptr, expected: auth.Record) -> bool {
    s := cast(^Server)user

    if !server_clock(s) {
        s.reply.error = .Denied
        return false
    }

    _, _, allowed := server_member(s, s.lane.request, s.lane.peer)

    if !allowed || s.authority.coordinator.record != expected || !server_owner(s, s.lane.request) {
        s.reply.error = .Denied
        return false
    }

    return true
}

server_update :: proc(s: ^Server) -> Error {
    if !s.ready {
        return .Invalid
    }

    if !server_clock(s) {
        server_clear(s)
        return .Clock
    }

    if !s.active {
        return .None
    }

    _, _, allowed := server_member(s, s.lane.request, s.lane.peer)

    if !allowed || s.now - s.started >= tf.DEFAULT_CONFIG.timeout_ms {
        server_clear(s)
        return .Timeout
    }

    if s.receiver.ready && !s.reply.complete && !server_owner(s, s.lane.request) {
        s.reply.error = .Denied
        server_reply(s, s.lane.peer, s.reply, s.lane.key)
        server_clear(s)
        return .Denied
    }

    if s.receiver.ready {
        tf.blob_update(&s.receiver, s.now)
    }

    if s.sender.ready {
        tf.sender_update(&s.sender, s.now)
    }

    return .None
}
