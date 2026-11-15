package replay_relay

import "core:crypto"
import "core:mem"
import "core:strings"
import auth "godot:replay/authority"
import tr "godot:replay/transport"

MAX_CONNECTIONS :: 128
Authorize :: proc(user: rawptr, room, content, member: u64) -> (key: auth.Key, incarnation: u64, allowed: bool)

Clock :: struct {
    user: rawptr,
    read: proc(user: rawptr) -> (unix_seconds, monotonic_ms: u64, valid: bool),
}

Config :: struct {
    content:    u64,
    secret:     string,
    urls:       [MAX_URLS]URL,
    ttl:        u32,
    relay_only: bool,
}

Server :: struct {
    ready, poisoned:                               bool,
    allocator:                                     mem.Allocator,
    config:                                        Config,
    authorize:                                     Authorize,
    user:                                          rawptr,
    clock:                                         Clock,
    wire:                                          tr.Transport,
    codecs:                                        Codecs,
    entries:                                       [MAX_CONNECTIONS]Challenge,
    wall, mono:                                    u64,
    budget:                                        f64,
    accepted, rejected, issued, replayed, limited: u64,
    txb:                                           [PACKET_BYTES]u8,
}

@(private)
Challenge :: struct {
    peer:                               tr.Peer_Id,
    room, member, sequence:             u64,
    nonce:                              [16]u8,
    value, acquire_hash:                [32]u8,
    deadline, touched, issued, expires: u64,
    incarnation:                        u64,
    budget:                             f64,
}

// The wire MUST be authenticated confidential transport, or an isolated local
// test channel. HMAC authenticates requests/replies; it does not encrypt grants.
server_open :: proc(
    s: ^Server,
    cfg: Config,
    authorize: Authorize,
    user: rawptr,
    clock: Clock,
    wire: tr.Transport,
    allocator := context.allocator,
) -> bool {
    if s.ready ||
       cfg.content == 0 ||
       len(cfg.secret) < 32 ||
       len(cfg.secret) > 256 ||
       authorize == nil ||
       clock.read == nil ||
       !grant_valid(grant_make(cfg.secret, cfg.urls, 1, 1, 1, 1, cfg.ttl, cfg.relay_only)) {
        return false
    }

    for b in cfg.secret {
        if b < 33 || b > 126 {
            return false
        }
    }

    wall, mono, ok := clock.read(clock.user)

    if !ok || wall == 0 {
        return false
    }

    s.allocator, s.config, s.authorize, s.user, s.clock, s.wire = allocator, cfg, authorize, user, clock, wire
    s.config.secret = strings.clone(cfg.secret, allocator)

    if !codecs_init(&s.codecs, allocator) {
        server_close(s)
        return false
    }

    s.wall, s.mono, s.budget, s.ready = wall, mono, 32, true
    return true
}

server_close :: proc(s: ^Server) {
    if len(s.config.secret) != 0 {
        crypto.zero_explicit(raw_data(s.config.secret), len(s.config.secret))
    }

    delete(s.config.secret, s.allocator)
    codecs_destroy(&s.codecs)
    crypto.zero_explicit(s, size_of(Server))
}

server_receive :: proc(s: ^Server, from: tr.Peer_Id, bytes: []u8) -> bool {
    if !s.ready || from == 0 {
        return false
    }

    q, valid := request_read(&s.codecs, bytes, s.config.content)

    if !valid {
        return false
    }

    key, incarnation, allowed := s.authorize(s.user, q.room, q.content, q.member)

    if key == (auth.Key{}) || !authenticated(key, REQUEST_KIND, bytes) {
        s.rejected += 1
        return false
    }

    reply := Reply {
        version      = VERSION,
        room         = q.room,
        content      = q.content,
        member       = q.member,
        sequence     = q.sequence,
        nonce        = q.nonce,
        request_hash = request_hash(bytes),
    }
    wall, now, ok := s.clock.read(s.clock.user)

    if !ok || wall < s.wall || now < s.mono {
        s.poisoned = true
    }

    if s.poisoned {
        reply.error = .Clock
    } else if !allowed || incarnation == 0 {
        reply.error = .Denied
    } else {
        s.budget = min(32, s.budget + f64(now - s.mono) * 16 / 1000)
        s.wall, s.mono = wall, now

        if s.budget < 1 {
            reply.error = .Rate_Limited
        } else {
            s.budget -= 1
            reply.error, reply.challenge, reply.grant = server_decide(
                s,
                from,
                q,
                reply.request_hash,
                incarnation,
                wall,
                now,
            )
        }
    }

    if reply.error != .None {
        s.rejected += 1
        reply.challenge, reply.grant = {}, {}

        if reply.error == .Rate_Limited {
            s.limited += 1
        }
    } else {
        s.accepted += 1
    }

    count := pack(&s.codecs.reply, reply, key, REPLY_KIND, q.content, q.sequence, s.txb[:])

    if count != 0 {
        tr.send(&s.wire, from, .Reliable, s.txb[:count])
    }

    crypto.zero_explicit(&s.txb, size_of(s.txb))
    return true
}

@(private)
server_decide :: proc(
    s: ^Server,
    from: tr.Peer_Id,
    q: Request,
    digest: [32]u8,
    incarnation, wall, now: u64,
) -> (
    Error,
    [32]u8,
    Grant,
) {
    index := -1

    for item, i in s.entries {
        if item.peer == from {
            index = i
            break
        }
    }

    if index < 0 {
        if q.verb != .Challenge {
            return .Denied, {}, {}
        }

        for item, i in s.entries {
            if item.peer == 0 || (!tr.peer_connected(&s.wire, item.peer) && now >= item.deadline) {
                index = i
                s.entries[i] = {
                    peer    = from,
                    touched = now,
                    budget  = 4,
                }
                break
            }
        }
    }

    if index < 0 {
        return .Capacity, {}, {}
    }

    e := &s.entries[index]
    e.budget = min(4, e.budget + f64(now - e.touched) * 2 / 1000)
    e.touched = now

    if e.budget < 1 {
        return .Rate_Limited, {}, {}
    }

    e.budget -= 1
    same :=
        e.room == q.room &&
        e.member == q.member &&
        e.sequence == q.sequence &&
        e.nonce == q.nonce &&
        e.incarnation == incarnation

    if q.verb == .Challenge {
        if same && now < e.deadline {
            return .None, e.value, {}
        }

        if now > max(u64) - 5000 {
            return .Clock, {}, {}
        }

        value: [32]u8

        when crypto.HAS_RAND_BYTES {
            crypto.rand_bytes(value[:])
        } else {
            return .Unavailable, {}, {}
        }

        if value == ([32]u8{}) {
            return .Unavailable, {}, {}
        }

        budget := e.budget
        e^ = {
            peer        = from,
            room        = q.room,
            member      = q.member,
            sequence    = q.sequence,
            nonce       = q.nonce,
            incarnation = incarnation,
            value       = value,
            deadline    = now + 5000,
            touched     = now,
            budget      = budget,
        }
        return .None, value, {}
    }

    if !same || e.value != q.challenge {
        return .Denied, {}, {}
    }

    if now >= e.deadline {
        return .Expired, {}, {}
    }

    if e.issued != 0 {
        if e.acquire_hash != digest || wall >= e.expires {
            return .Expired, {}, {}
        }

        s.replayed += 1
        return .None, {}, grant_make(s.config.secret, s.config.urls, q.room, q.member, incarnation, e.issued, s.config.ttl, s.config.relay_only)
    }

    grant := grant_make(
        s.config.secret,
        s.config.urls,
        q.room,
        q.member,
        incarnation,
        wall,
        s.config.ttl,
        s.config.relay_only,
    )

    if !grant_valid(grant) {
        return .Clock, {}, {}
    }

    e.issued, e.expires, e.acquire_hash = grant.issued, grant.expires, digest
    s.issued += 1
    return .None, {}, grant
}
