package replay_provision

import "core:crypto"
import "core:mem"
import auth "godot:replay/authority"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

MAX_ROOMS :: 32

Hub_Config :: struct {
    content: u64,
    policy:  auth.Policy,
    rooms:   int,
}

HUB_CONFIG :: Hub_Config {
    policy = auth.DEFAULT_POLICY,
    rooms  = 16,
}

Hub :: struct {
    ready, poisoned:                      bool,
    allocator:                            mem.Allocator,
    config:                               Hub_Config,
    rooms:                                []^Room,
    activity:                             []u64,
    creation_guard:                       Creation_Guard,
    reclaim:                              Reclaim,
    lifecycle_user:                       rawptr,
    commit:                               Commit,
    user:                                 rawptr,
    entropy:                              Entropy,
    clock:                                auth.Clock_Source,
    wire:                                 tr.Transport,
    codecs:                               Codecs,
    control_codecs:                       auth.Rpc_Codecs,
    now:                                  u64,
    budget:                               f64,
    peers:                                [128]Hub_Peer,
    received, rejected, limited, replies: u64,
    txb:                                  [PACKET_BYTES]u8,
}

@(private)
Hub_Peer :: struct {
    id:     tr.Peer_Id,
    at:     u64,
    budget: f64,
}

// Preload the complete bounded room set at startup; unauthenticated traffic
// cannot cause a lazy coordinator restart. A deployment owns this room set as
// one service. Two concurrent copies fence each other's CAS, not a shared lobby.
hub_open :: proc(
    h: ^Hub,
    config: Hub_Config,
    existing: []Bundle,
    commit: Commit,
    user: rawptr,
    clock: auth.Clock_Source,
    wire: tr.Transport,
    entropy := Entropy{read = random_bytes},
    allocator := context.allocator,
    creation_guard: Creation_Guard = nil,
    reclaim: Reclaim = nil,
    lifecycle_user: rawptr = nil,
) -> Error {
    if h.ready ||
       commit == nil ||
       clock.read == nil ||
       entropy.read == nil ||
       config.content == 0 ||
       config.rooms < 1 ||
       config.rooms > MAX_ROOMS ||
       len(existing) > config.rooms ||
       !auth.record_valid(auth.record_make(1, config.content, {1, 1}, config.policy)) {
        return .Invalid
    }

    for b, i in existing {
        if !bundle_valid(b) || b.record.content != config.content {
            return .Invalid
        }

        for previous in existing[:i] {
            if previous.record.room == b.record.room {
                return .Invalid
            }
        }
    }

    h.allocator, h.config, h.commit, h.user, h.clock, h.wire, h.entropy =
        allocator, config, commit, user, clock, wire, entropy
    h.rooms = make([]^Room, config.rooms, allocator)
    h.activity = make([]u64, config.rooms, allocator)
    h.creation_guard, h.reclaim, h.lifecycle_user = creation_guard, reclaim, lifecycle_user

    if !codecs_init(&h.codecs, allocator) || !auth.rpc_codecs_init(&h.control_codecs, allocator) {
        hub_close(h)
        return .Invalid
    }

    now, ok := clock.read(clock.user)

    if !ok {
        hub_close(h)
        return .Clock
    }

    h.now, h.budget = now, 32
    for &at in h.activity {at = now}

    for b, i in existing {
        h.rooms[i] = new(Room, allocator)

        if err := open(h.rooms[i], b, commit, user, clock, wire, entropy, allocator); err != .None {
            hub_close(h)
            return err
        }
    }

    h.ready = true
    return .None
}

hub_close :: proc(h: ^Hub) {
    for room in h.rooms {
        if room != nil {
            close(room)
            free(room, h.allocator)
        }
    }

    delete(h.rooms, h.allocator)
    delete(h.activity, h.allocator)
    codecs_destroy(&h.codecs)
    auth.rpc_codecs_destroy(&h.control_codecs)
    crypto.zero_explicit(h, size_of(Hub))
}

hub_room :: proc(h: ^Hub, id: u64) -> ^Room {
    for room in h.rooms {
        if room != nil && room.bundle.record.room == id {
            return room
        }
    }

    return nil
}

// Returns false for an unrelated/malformed packet. No response contains a
// private bundle. Ingress/connection/TLS limits also belong to the transport.
hub_receive :: proc(h: ^Hub, from: tr.Peer_Id, bytes: []u8) -> bool {
    if !h.ready || from == 0 {
        return false
    }

    h.received += 1

    if len(bytes) != sc.HEADER_BYTES + h.codecs.request.wire_size {
        h.rejected += 1
        return false
    }

    q: Request
    meta, report := sc.unpack(
        &h.codecs.request,
        &q,
        bytes,
        {kind = REQUEST_KIND, epoch = u64(PROTOCOL), content = h.config.content},
    )

    if report.error != .None || meta.tick != 0 || q.content != h.config.content || !request_valid(q) {
        h.rejected += 1
        return false
    }

    result := hub_budget(h, from)
    g: Grant
    ticket: Ticket

    if result == .None {
        g, ticket, result = hub_request(h, q)
    }

    if result != .None {
        g, ticket = {}, {}
        h.rejected += 1
    } else {
        for room, i in h.rooms {
            if room != nil && room.bundle.record.room == q.room {h.activity[i] = h.now; break}
        }
    }

    reply := Reply{PROTOCOL, q.room, q.content, rec.hash(bytes), result, g, ticket}
    count := sc.HEADER_BYTES + h.codecs.reply.wire_size

    if sc.pack(&h.codecs.reply, reply, {kind = REPLY_KIND, epoch = u64(PROTOCOL), content = q.content}, h.txb[:count]).error !=
       .None {
        return false
    }

    if tr.send(&h.wire, from, .Reliable, h.txb[:count]) == .Sent {
        h.replies += 1
    }

    crypto.zero_explicit(&h.txb, size_of(h.txb))
    return true
}

// Multiplex existing authenticated authority packets on the same connection.
// Unknown rooms do not touch storage, and service_receive verifies the key MAC.
hub_control_receive :: proc(h: ^Hub, from: tr.Peer_Id, bytes: []u8) -> bool {
    if !h.ready || h.poisoned || len(bytes) != sc.HEADER_BYTES + h.control_codecs.request.wire_size + 32 {
        return false
    }

    meta, _, inspection := sc.inspect(bytes[:len(bytes) - 32])

    if inspection.error != .None || (meta.kind != auth.RPC_REQUEST && meta.kind != auth.RPC_REMOVE_REQUEST) {
        return false
    }

    q: auth.Request
    _, report := sc.unpack(
        &h.control_codecs.request,
        &q,
        bytes[:len(bytes) - 32],
        {kind = meta.kind, epoch = u64(auth.RPC_VERSION), content = h.config.content},
    )

    if report.error != .None {
        return false
    }

    room := hub_room(h, q.room)
    if room == nil {return false}
    accepted := auth.service_receive(&room.service, from, bytes)
    if accepted {
        for item, i in h.rooms {
            if item == room {h.activity[i] = max(h.activity[i], room.service.coordinator.now); break}
        }
    }
    return accepted
}

@(private)
hub_request :: proc(h: ^Hub, q: Request) -> (Grant, Ticket, Error) {
    room := hub_room(h, q.room)

    if room == nil {
        if q.verb != .Create {
            return {}, {}, .Missing
        }

        // The bootstrap grant of a dedicated room is an infrastructure secret.
        // Only trusted startup provisioning may create it; public callers cannot
        // become infrastructure by choosing a room ID in a dedicated deployment.
        if h.config.policy.mode == .Dedicated {
            return {}, {}, .Denied
        }

        if h.creation_guard != nil {
            if error := h.creation_guard(h.lifecycle_user, q.room); error != .None {
                if error == .Storage {hub_poison(h)}
                return {}, {}, error
            }
        }

        slot := -1

        for r, i in h.rooms {
            if r == nil {
                slot = i
                break
            }
        }

        if slot < 0 {
            if h.reclaim == nil {return {}, {}, .Capacity}
            if error := h.reclaim(h.lifecycle_user, h); error != .None {return {}, {}, error}
            for r, i in h.rooms {if r == nil {slot = i; break}}
            if slot < 0 {return {}, {}, .Capacity}
        }

        b, err := make_room(q.room, q.content, q.claim, q.endpoint, h.config.policy, h.entropy)

        if err != .None {
            return {}, {}, err
        }

        candidate := new(Room, h.allocator)

        if error := open(candidate, b, h.commit, h.user, h.clock, h.wire, h.entropy, h.allocator); error != .None {
            close(candidate)
            free(candidate, h.allocator)

            // Creation may have committed without an acknowledgement. A restart
            // must reload the whole set before another create can be attempted.
            if error == .Storage {
                hub_poison(h)
            }

            return {}, {}, error
        }

        h.rooms[slot], room = candidate, candidate
        h.activity[slot] = h.now
    }

    switch q.verb {
    case .Create:
        if room.bundle.enrollments[0].endpoint != q.endpoint {
            return {}, {}, .Denied
        }

        g, err := creator_grant(room, q.claim)
        return g, {}, err
    case .Join:
        g, err := join(room, {q.room, q.ticket}, q.claim, q.endpoint)
        return g, {}, err
    case .Invite:
        ticket, err := invite(room, q.claim, q.ticket, q.role, q.uses)
        return {}, ticket, err
    case .Revoke:
        return {}, {}, revoke(room, q.claim, {q.room, q.ticket})
    }

    return {}, {}, .Invalid
}

@(private)
hub_budget :: proc(h: ^Hub, from: tr.Peer_Id) -> Error {
    if h.poisoned {
        return .Storage
    }

    now, ok := h.clock.read(h.clock.user)

    if !ok || now < h.now {
        hub_poison(h)
        return .Clock
    }

    h.budget = min(32, h.budget + f64(now - h.now) * 32 / 1000)
    h.now = now

    if h.budget < 1 {
        h.limited += 1
        return .Rate_Limited
    }

    h.budget -= 1
    slot := -1

    for item, i in h.peers {
        if item.id == from {
            slot = i
            break
        }
    }

    if slot < 0 {
        for item, i in h.peers {
            if item.id == 0 || now - item.at >= 10000 {
                slot = i
                h.peers[i] = {from, now, 8}
                break
            }
        }
    }

    if slot < 0 {
        h.limited += 1
        return .Rate_Limited
    }

    p := &h.peers[slot]
    p.budget = min(8, p.budget + f64(now - p.at) * 4 / 1000)
    p.at = now

    if p.budget < 1 {
        h.limited += 1
        return .Rate_Limited
    }

    p.budget -= 1
    return .None
}

@(private)
hub_poison :: proc(h: ^Hub) {
    h.poisoned = true

    for r in h.rooms {
        if r != nil {
            r.service.coordinator.poisoned, r.service.coordinator.active = true, false
        }
    }
}
