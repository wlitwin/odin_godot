package replay_checkpoint

import "core:crypto"
import "core:mem"
import auth "godot:replay/authority"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"

Phase :: enum u8 {
    Idle,
    Requesting,
    Transferring,
    Complete,
    Failed,
}

Client :: struct {
    ready:                   bool,
    restore_lease:           ^auth.Lease,
    allocator:               mem.Allocator,
    clock:                   auth.Clock_Source,
    codecs:                  Codecs,
    lane:                    Lane,
    sender:                  tf.Sender,
    receiver:                tf.Blob_Receiver,
    phase:                   Phase,
    error:                   Error,
    reply:                   Reply,
    saved:                   Saved,
    upload:                  []u8,
    hash:                    [32]u8,
    now, started, last_send: u64,
    sent:                    bool,
    count:                   int,
    txb:                     [PACKET_BYTES]u8,
}

// Supply the identity/nonce from a registered authority RPC client on this same
// confidential connection. This owner borrows the transport and never drains it.
client_open :: proc(
    c: ^Client,
    key: auth.Key,
    clock: auth.Clock_Source,
    wire: tr.Transport,
    peer: tr.Peer_Id = 1,
    data_channel: tr.Channel = .Reliable,
    allocator := context.allocator,
) -> bool {
    if c.ready || key == (auth.Key{}) || clock.read == nil || peer == 0 || data_channel > .Unreliable {
        return false
    }

    c.allocator, c.clock = allocator, clock

    if !codecs_init(&c.codecs, allocator) {
        client_close(c)
        return false
    }

    c.lane = {
        wire     = wire,
        peer     = peer,
        key      = key,
        out_kind = UPSTREAM_KIND,
        channel  = data_channel,
        codecs   = &c.codecs,
    }
    c.ready = true
    return true
}

client_close :: proc(c: ^Client) {
    if c.restore_lease != nil && c.restore_lease.pending && c.restore_lease.sequence == c.lane.request.sequence {
        auth.lease_cancel_request(c.restore_lease)
    }

    tf.sender_destroy(&c.sender)
    tf.blob_destroy(&c.receiver)
    saved_destroy(&c.saved)
    delete(c.upload, c.allocator)
    codecs_destroy(&c.codecs)
    crypto.zero_explicit(c, size_of(Client))
}

client_begin :: proc(c: ^Client, q: Request, bytes: []u8 = nil) -> Error {
    if !c.ready || c.phase == .Requesting || c.phase == .Transferring {
        return .Busy
    }

    if !request_valid(q) || (q.verb != .Upload && len(bytes) != 0) {
        return .Invalid
    }

    if q.verb == .Upload {
        payload := q.payload

        if payload == (Payload{}) {
            payload = payload_for(q.point)
        }

        if !payload_valid(payload) || len(bytes) != int(payload.bytes) || tf.hash(bytes) != payload.hash {
            return .Invalid
        }

        if payload.kind == PACKAGE_KIND {
            if _, error := package_view(bytes, q.point); error != .None {
                return error
            }
        }
    }

    now, ok := c.clock.read(c.clock.user)

    if !ok || now < c.now {
        return .Clock
    }

    c.restore_lease = nil
    tf.sender_destroy(&c.sender)
    tf.blob_destroy(&c.receiver)
    saved_destroy(&c.saved)
    delete(c.upload, c.allocator)
    c.upload = nil

    if q.verb == .Upload {
        c.upload = make([]u8, len(bytes), c.allocator)
        copy(c.upload, bytes)
    }

    c.count = request_pack(&c.codecs, q, c.lane.key, c.txb[:])

    if c.count == 0 {
        return .Invalid
    }

    c.hash = tf.hash(c.txb[:c.count - 32])
    c.lane.request, c.lane.transfer = q, 0
    c.lane.request_hash = c.hash
    c.now, c.started, c.sent, c.phase, c.error, c.reply = now, now, false, .Requesting, .None, {}
    return .None
}

@(private)
client_fail :: proc(c: ^Client, error: Error) {
    if c.restore_lease != nil && c.restore_lease.pending && c.restore_lease.sequence == c.lane.request.sequence {
        auth.lease_cancel_request(c.restore_lease)
    }

    c.phase, c.error = .Failed, error
}

client_receive :: proc(c: ^Client, from: tr.Peer_Id, bytes: []u8) -> bool {
    if !c.ready ||
       (c.phase != .Requesting && c.phase != .Transferring && c.phase != .Complete) ||
       len(bytes) < sc.HEADER_BYTES + 32 ||
       len(bytes) > PACKET_BYTES {
        return false
    }

    now, ok := c.clock.read(c.clock.user)

    if !ok || now < c.now {
        client_fail(c, .Clock)
        return false
    }

    c.now = now
    q := c.lane.request
    meta, _, r := sc.inspect(bytes[:len(bytes) - 32])

    if r.error != .None {
        return false
    }

    if meta.kind == DOWNSTREAM_KIND {
        if c.lane.transfer == 0 {
            return false
        }

        d, valid := lane_read(&c.lane, from, bytes, DOWNSTREAM_KIND)

        if !valid {
            return false
        }

        if q.verb == .Upload {
            tf.sender_receive(&c.sender, from, d.bytes[:d.count], now)
        } else {
            tf.blob_receive(&c.receiver, from, d.bytes[:d.count], now)
        }

        return true
    }

    if meta.kind != REPLY_KIND || from != c.lane.peer || !authenticated(c.lane.key, REPLY_KIND, bytes) {
        return false
    }

    reply: Reply

    if !read(&c.codecs.reply, &reply, bytes, REPLY_KIND, q.content) ||
       meta.tick != q.sequence ||
       reply.request != q ||
       reply.request_hash != c.hash {
        return false
    }

    if c.phase == .Complete {
        return true
    }

    if reply.error != .None {
        if c.restore_lease != nil {
            auth.lease_cancel_request(c.restore_lease)
        }

        c.reply = reply
        client_fail(c, reply.error)
        return true
    }

    if reply.complete {
        if !publication_valid(reply.publication) ||
           reply.publication.point.scope.room != q.room ||
           reply.publication.point.scope.content != q.content ||
           reply.publication.contract != q.contract ||
           q.verb == .Download {
            return false
        }

        if q.verb == .Upload && (reply.publication.point != q.point || reply.publication.publisher != q.identity) {
            return false
        }

        if q.verb == .Restore {
            if c.restore_lease == nil ||
               reply.publication.revision != q.revision ||
               reply.publication.point != q.point ||
               reply.view.owner != q.identity ||
               q.authority_epoch == max(u64) ||
               reply.view.epoch != q.authority_epoch + 1 ||
               reply.view.recovered != q.point {
                return false
            }

            if auth.lease_accept(c.restore_lease, q.sequence, reply.view) != .None {
                return false
            }

            c.restore_lease.require_owner = true
        }

        c.reply, c.phase = reply, .Complete
        return true
    }

    if reply.transfer == 0 || q.verb == .Status || q.verb == .Restore {
        return false
    }

    if c.lane.transfer != 0 {
        return c.lane.transfer == reply.transfer
    }

    c.lane.transfer = reply.transfer
    c.reply = reply

    if q.verb == .Upload {
        payload := q.payload

        if payload == (Payload{}) {
            payload = payload_for(q.point)
        }

        if tf.sender_init(
               &c.sender,
               q.point.scope,
               c.lane.peer,
               lane_wire(&c.lane),
               allocator = c.allocator,
               archive_kind = payload.kind,
               kind_base = TRANSFER_BASE,
           ) !=
           .None {
            client_fail(c, .Capacity)
            return true
        }

        c.sender.next_sequence = q.point.archive.sequence - 1

        if tf.sender_begin(&c.sender, c.upload, now) != .None {
            client_fail(c, .Schema)
            return true
        }

        delete(c.upload, c.allocator)
        c.upload = nil
    } else {
        p := reply.publication

        if !publication_valid(p) ||
           p.revision != q.revision ||
           p.contract != q.contract ||
           p.point.scope.room != q.room ||
           p.point.scope.content != q.content {
            client_fail(c, .Schema)
            return true
        }

        if !payload_valid(reply.payload) ||
           (reply.payload.kind == net.CHECKPOINT_KIND && reply.payload != payload_for(p.point)) {
            client_fail(c, .Schema)
            return true
        }

        if tf.blob_init(
               &c.receiver,
               p.point.scope,
               c.lane.peer,
               lane_wire(&c.lane),
               reply.payload.kind,
               client_accept,
               c,
               allocator = c.allocator,
               kind_base = TRANSFER_BASE,
               max_bytes = int(reply.payload.bytes),
           ) !=
           .None {
            client_fail(c, .Capacity)
            return true
        }
    }

    c.phase = .Transferring
    return true
}

@(private)
client_accept :: proc(user: rawptr, archive: tf.Archive, bytes: []u8) -> bool {
    c := cast(^Client)user
    p := c.reply.publication
    d := c.reply.payload

    if archive.sequence != p.point.archive.sequence ||
       archive.tick != p.point.archive.tick ||
       archive.bytes != d.bytes ||
       archive.hash != d.hash {
        return false
    }

    root := bytes
    payload: []u8

    if d.kind == PACKAGE_KIND {
        view, error := package_view(bytes, p.point)

        if error != .None {
            return false
        }

        root = view.root
        payload = make([]u8, len(bytes), c.allocator)
        copy(payload, bytes)
    }

    copy_bytes := make([]u8, len(root), c.allocator)
    copy(copy_bytes, root)
    saved_destroy(&c.saved)
    c.saved = {
        ready       = true,
        publication = p,
        bytes       = copy_bytes,
        allocator   = c.allocator,
        payload     = payload,
    }
    c.phase = .Complete
    return true
}

client_update :: proc(c: ^Client) -> Error {
    if !c.ready {
        return .Invalid
    }

    now, ok := c.clock.read(c.clock.user)

    if !ok || now < c.now {
        client_fail(c, .Clock)
        return .Clock
    }

    c.now = now

    if c.phase == .Failed {
        return c.error
    }

    if c.phase != .Idle && c.phase != .Complete && now - c.started >= tf.DEFAULT_CONFIG.timeout_ms {
        client_fail(c, .Timeout)
        return .Timeout
    }

    if c.phase == .Requesting || c.phase == .Transferring {
        if !c.sent || now - c.last_send >= 250 {
            if tr.send(&c.lane.wire, c.lane.peer, .Reliable, c.txb[:c.count]) == .Sent {
                c.sent, c.last_send = true, now
            }
        }
    }

    if c.sender.ready {
        if e := tf.sender_update(&c.sender, now); e != .None && e != .Transport {
            client_fail(c, .Invalid)
        }
    }

    if c.receiver.ready {
        tf.blob_update(&c.receiver, now)
    }

    return c.error
}

// Downloaded bytes remain owned by Client until the next begin/close. The model
// is required before handing a decoded world to game code; this grants no lease.
client_decode :: proc(
    c: ^Client,
    cp: ^net.Checkpoint($S, $C, $A, $N),
    model: net.Model(S, C, A, $E, N),
    allocator := context.allocator,
    codec: ^net.Checkpoint_Codec = nil,
) -> net.Error {
    if c.phase != .Complete || !c.saved.ready {
        return .Wrong_Phase
    }

    error := net.checkpoint_decode(cp, c.saved.bytes, model, c.lane.request.content, allocator, codec)

    if error != .None {
        return error
    }

    if !cp.settings.require_permit || cp.header.contract != c.saved.publication.contract {
        net.checkpoint_destroy(cp)
        return .Invalid_Checkpoint
    }

    return .None
}
