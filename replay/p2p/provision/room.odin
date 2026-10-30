package replay_p2p_provision

import "core:crypto"
import auth "godot:replay/authority"
import adm "godot:replay/p2p/admission"
import p "godot:replay/provision"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

VERSION :: u16(1)
// Private durable storage. The player count is part of the room, not a mutable
// deployment setting. Never send a Bundle to participants or archive it with a game.
Bundle :: struct {version: u16, players: u8, enrollment: p.Bundle}
Commit :: proc(user: rawptr, expected_revision: u64, next: Bundle) -> bool
Room :: struct {
    ready: bool,
    bundle: Bundle,
    enrollment: p.Room,
    commit: Commit,
    user: rawptr,
}

bundle_valid :: proc(b: Bundle) -> bool {
    b := b
    if b.version != VERSION || b.players < 2 || b.players > adm.MAX_PLAYERS || !p.bundle_valid(b.enrollment) {return false}
    r := b.enrollment.record
    if r.epoch != 0 || r.policy != auth.DEFAULT_POLICY {return false}
    count := 0
    for m, i in r.members {
        if m.identity.member == 0 {continue}
        // Enrollment order is the permanent simulation player order. Disabled
        // members retain their seats; neither departures nor revocation recycle it.
        if i != count || i >= int(b.players) || m.can_host || m.trusted_authority || m.infrastructure {return false}
        count += 1
    }
    reserved := 0
    for item in b.enrollment.invites {
        if item.role != .Player {return false}
        if !item.revoked {reserved += int(item.remaining)}
    }
    return count + reserved <= int(b.players)
}

make_room :: proc(room, content: u64, players: u8, claim: p.Secret, endpoint: auth.Endpoint,
                  entropy: p.Entropy) -> (Bundle, p.Error) {
    if players < 2 || players > adm.MAX_PLAYERS {return {}, .Invalid}
    enrollment, error := p.make_room(room, content, claim, endpoint, entropy = entropy)
    if error != .None {return {}, error}
    enrollment.record.members[0].can_host, enrollment.record.members[0].trusted_authority = false, false
    b := Bundle{VERSION, players, enrollment}
    if !bundle_valid(b) {return {}, .Invalid}
    return b, .None
}

// Stable address, serialized owner. This owner exposes registration and roster
// reads only. Do not pass enrollment.service to a generic authority RPC driver.
open :: proc(r: ^Room, b: Bundle, commit: Commit, user: rawptr, clock: auth.Clock_Source,
             wire: tr.Transport, entropy: p.Entropy, allocator := context.allocator) -> p.Error {
    if r.ready || r.enrollment.ready || commit == nil || !bundle_valid(b) {return .Invalid}
    r.bundle, r.commit, r.user = b, commit, user
    error := p.open(&r.enrollment, b.enrollment, commit_enrollment, r, clock, wire, entropy, allocator)
    if error != .None {close(r); return error}
    r.ready = true
    return .None
}
close :: proc(r: ^Room) {p.close(&r.enrollment); crypto.zero_explicit(r, size_of(Room))}

creator_grant :: proc(r: ^Room, claim: p.Secret) -> (p.Grant, p.Error) {
    if error := usable(r); error != .None {return {}, error}
    return p.creator_grant(&r.enrollment, claim)
}

invite :: proc(r: ^Room, admin, secret: p.Secret, uses: u8 = 1) -> (p.Ticket, p.Error) {
    if error := usable(r); error != .None {return {}, error}
    // Authenticate before exposing capacity. Exact retries continue to work
    // after some or all seats have enrolled, or the invite has been exhausted.
    if _, error := p.creator_grant(&r.enrollment, admin); error != .None {return {}, error}
    if uses == 0 || uses >= r.bundle.players {return {}, .Invalid}
    s := secret; digest := rec.hash(s[:])
    for item in r.bundle.enrollment.invites {
        if item.hash == digest {return p.invite(&r.enrollment, admin, secret, .Player, uses)}
    }
    reserved := members(r.bundle)
    for item in r.bundle.enrollment.invites {if !item.revoked {reserved += int(item.remaining)}}
    if reserved + int(uses) > int(r.bundle.players) {return {}, .Capacity}
    return p.invite(&r.enrollment, admin, secret, .Player, uses)
}

join :: proc(r: ^Room, ticket: p.Ticket, claim: p.Secret, endpoint: auth.Endpoint) -> (p.Grant, p.Error) {
    if error := usable(r); error != .None {return {}, error}
    // All live invite uses already reserve seats. The underlying exact-retry
    // path precedes exhaustion/revocation checks and does not allocate a new seat.
    return p.join(&r.enrollment, ticket, claim, endpoint)
}
revoke :: proc(r: ^Room, admin: p.Secret, ticket: p.Ticket) -> p.Error {
    if error := usable(r); error != .None {return error}
    return p.revoke(&r.enrollment, admin, ticket)
}

// Reuses enrollment request/reply semantics and the existing client journal.
// A deployment authenticates/encrypts the channel and bounds request ingress.
request :: proc(r: ^Room, q: p.Request) -> (p.Grant, p.Ticket, p.Error) {
    if !p.request_valid(q) {return {}, {}, .Invalid}
    if error := usable(r); error != .None {return {}, {}, error}
    if q.room != r.bundle.enrollment.record.room || q.content != r.bundle.enrollment.record.content {return {}, {}, .Denied}
    switch q.verb {
    case .Create:
        if q.endpoint != r.bundle.enrollment.enrollments[0].endpoint {return {}, {}, .Denied}
        g, error := creator_grant(r, q.claim); return g, {}, error
    case .Join:
        g, error := join(r, {q.room, q.ticket}, q.claim, q.endpoint); return g, {}, error
    case .Invite:
        if q.role != .Player {return {}, {}, .Denied}
        ticket, error := invite(r, q.claim, q.ticket, q.uses); return {}, ticket, error
    case .Revoke: return {}, {}, revoke(r, q.claim, {q.room, q.ticket})
    }
    return {}, {}, .Invalid
}

// Filter before the ordinary MAC/nonce/frontier verifier. No authority verb or
// optional authority extension is reachable, even with valid creator credentials.
control_receive :: proc(r: ^Room, from: tr.Peer_Id, bytes: []u8) -> bool {
    if usable(r) != .None {return false}
    s := &r.enrollment.service
    if len(bytes) != sc.HEADER_BYTES + s.codecs.request.wire_size + 32 {return false}
    q: auth.Request
    _, report := sc.unpack(&s.codecs.request, &q, bytes[:len(bytes)-32],
        {kind = auth.RPC_REQUEST, epoch = u64(auth.RPC_VERSION), content = r.bundle.enrollment.record.content})
    if report.error != .None {return false}
    #partial switch q.command.verb {
    case .Query, .Challenge, .Rebind: return auth.service_receive(s, from, bytes)
    case: return false
    }
}

// Copy immediately before signaling admission/pump; do not cache across a
// registration change. No roster is published before all fixed seats exist.
registry :: proc(r: ^Room) -> (adm.Registry, p.Error) {
    if error := usable(r); error != .None {return {}, error}
    if members(r.bundle) != int(r.bundle.players) {return {}, .Not_Ready}
    result: adm.Registry
    b := &r.bundle.enrollment
    result.match = {session = b.record.room, content = b.record.content, epoch = 1, count = r.bundle.players}
    for i in 0..<int(r.bundle.players) {
        m := b.record.members[i]
        result.match.members[i] = m.identity.member
        result.credentials[i] = {m.identity, b.enrollments[i].key}
        result.enabled[i] = m.enabled
    }
    if !adm.registry_valid(&result) {return {}, .Invalid}
    return result, .None
}

// Call only on a reply accepted by Rpc_Client (MAC, scope, sequence and nonce).
// players comes from the game's required participant count. This contains no
// private peer keys and does not turn a coordinator read into a simulation lease.
match_from_reply :: proc(reply: auth.Reply, room, content: u64, players: u8, identity: auth.Identity) -> (adm.Match, p.Error) {
    if players < 2 || players > adm.MAX_PLAYERS || room == 0 || content == 0 || !auth.identity_valid(identity) ||
       reply.version != auth.RPC_VERSION || reply.result != .None || reply.view.room != room || reply.view.content != content ||
       reply.view.epoch != 0 || reply.view.remaining_ms != 0 || reply.view.owner != (auth.Identity{}) {return {}, .Invalid}
    result := adm.Match{session = room, content = content, epoch = 1, count = players}
    found, incomplete := false, false
    for m, i in reply.members {
        if i >= int(players) {if m != (auth.Member{}) {return {}, .Invalid}; continue}
        if m == (auth.Member{}) {incomplete = true; continue}
        if m.identity.member != u64(i+1) || !auth.identity_valid(m.identity) || m.can_host || m.trusted_authority || m.infrastructure {return {}, .Invalid}
        if !m.enabled {return {}, .Denied}
        result.members[i] = m.identity.member
        if m.identity == identity {found = true}
    }
    if !found {return {}, .Denied}
    if incomplete {return {}, .Not_Ready}
    return result, .None
}

@(private)
members :: proc(b: Bundle) -> int {n := 0; for m in b.enrollment.record.members {if m.identity.member != 0 {n += 1}}; return n}
@(private)
usable :: proc(r: ^Room) -> p.Error {
    if !r.ready {return .Not_Ready}
    if r.enrollment.service.coordinator.poisoned {return .Storage}
    if r.bundle.enrollment != r.enrollment.bundle || r.bundle.enrollment.record != r.enrollment.service.coordinator.record {
        r.enrollment.service.coordinator.poisoned = true
        return .Storage
    }
    return .None
}
@(private)
commit_enrollment :: proc(user: rawptr, expected: u64, next: p.Bundle) -> bool {
    r := cast(^Room)user
    if expected != r.bundle.enrollment.record.revision || expected == max(u64) || next.record.revision != expected+1 {return false}
    b := r.bundle; b.enrollment = next
    if !bundle_valid(b) || !r.commit(r.user, expected, b) {return false}
    r.bundle = b
    return true
}
