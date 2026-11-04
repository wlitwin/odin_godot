package replay_net

import sc "godot:replay/schema"
import tr "godot:replay/transport"

// Credential-free preflight on the already selected transport connection. This
// discovers a direct host's current epoch; it neither authenticates that endpoint
// nor authorizes migration. Both sides opt in; strict Hello/Welcome are unchanged.
@(private)
Epoch_Query :: struct {
    nonce:    Token,
    contract: u64,
}

client_discover_epoch :: proc(c: ^Client($S, $C, $A, $E, $N), nonce: Token) -> Error {
    if !c.initialized ||
       c.phase != .Joining ||
       c.has_world ||
       c.hello_sent ||
       c.epoch_query_pending ||
       c.action_count != 0 {
        return .Wrong_Phase
    }

    if c.cfg.require_permit || !token_valid(nonce) || nonce == c.token {
        return .Invalid_Input
    }

    c.epoch_query_pending, c.epoch_query_nonce = true, nonce
    return .None
}

@(private)
server_epoch_query :: proc(s: ^Server($S, $C, $A, $E, $N), from: tr.Peer_Id, bytes: []u8, meta: sc.Envelope_Meta) {
    if !s.epoch_discovery || s.cfg.require_permit || meta.content != s.cfg.content || meta.tick != 0 {
        s.stats.rejected_packets += 1
        return
    }

    query: Epoch_Query
    _, report := sc.unpack(&s.codecs.epoch_query, &query, bytes, meta)

    if report.error != .None || query.contract != s.contract || !token_valid(query.nonce) {
        s.stats.rejected_packets += 1
        return
    }

    reply := sc.Envelope_Meta {
        kind    = u16(Kind.Epoch_Reply),
        epoch   = s.cfg.epoch,
        content = s.cfg.content,
    }

    if sc.pack(&s.codecs.epoch_query, query, reply, s.txb).error == .None {
        server_send(s, from, .Reliable, s.txb[:sc.HEADER_BYTES + s.codecs.epoch_query.wire_size])
    }
}

@(private)
client_epoch_reply :: proc(c: ^Client($S, $C, $A, $E, $N), bytes: []u8, meta: sc.Envelope_Meta) {
    if !c.epoch_query_pending ||
       c.phase != .Joining ||
       c.has_world ||
       c.cfg.require_permit ||
       !c.hello_sent ||
       meta.epoch == 0 ||
       meta.tick != 0 ||
       meta.content != c.cfg.content {
        c.stats.rejected_packets += 1
        return
    }

    reply: Epoch_Query
    _, report := sc.unpack(&c.codecs.epoch_query, &reply, bytes, meta)

    if report.error != .None || reply.contract != c.contract || reply.nonce != c.epoch_query_nonce {
        c.stats.rejected_packets += 1
        return
    }

    c.cfg.epoch = meta.epoch
    c.epoch_query_pending = false
    c.epoch_query_nonce = {}
    c.hello_sent = false
    c.last_received = c.now
}
