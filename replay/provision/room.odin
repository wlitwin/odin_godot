package replay_provision

import "core:crypto"
import auth "godot:replay/authority"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"

VERSION :: u16(1)
MAX_INVITES :: 16
Secret :: [32]u8

Role :: enum u8 {
    Player,
    Trusted_Peer,
}

Error :: enum u8 {
    None,
    Invalid,
    Not_Ready,
    Denied,
    Capacity,
    Entropy,
    Storage,
    Clock,
    Missing,
    Rate_Limited,
}

Ticket :: struct {
    room:   u64,
    secret: Secret,
}

Invite :: struct {
    hash:             [32]u8,
    role:             Role,
    limit, remaining: u8,
    revoked:          bool,
}

Enrollment :: struct {
    claim_hash, invite_hash: [32]u8,
    endpoint:                auth.Endpoint,
    key:                     auth.Key,
    token:                   net.Token,
}

// This is PRIVATE coordinator storage. It includes bearer credentials and must
// never be sent as a roster, gameplay checkpoint, or successor archive.
Bundle :: struct {
    version:     u16,
    record:      auth.Record,
    enrollments: [auth.MAX_MEMBERS]Enrollment,
    invites:     [MAX_INVITES]Invite,
}

Grant :: struct {
    room, content:                               u64,
    identity:                                    auth.Identity,
    key:                                         auth.Key,
    token:                                       net.Token,
    can_host, trusted_authority, infrastructure: bool,
}

Commit :: proc(user: rawptr, expected_revision: u64, next: Bundle) -> bool

Entropy :: struct {
    user: rawptr,
    read: proc(user: rawptr, dst: []u8) -> bool,
}

// Stable address, one serialized owner. All authority and admission writes use
// the same durable CAS. Do not mutate service.coordinator or credentials except
// through authority APIs and this owner; do not copy an open Room.
Room :: struct {
    ready:   bool,
    bundle:  Bundle,
    service: auth.Service,
    commit:  Commit,
    user:    rawptr,
    entropy: Entropy,
}

secret :: proc(entropy := Entropy{read = random_bytes}) -> (value: Secret, error: Error) {
    if entropy.read == nil || !entropy.read(entropy.user, value[:]) || !nonzero(value[:]) {
        return {}, .Entropy
    }

    return value, .None
}

// Trusted server-side creation. room/content/policy come from the deployment,
// not an unauthenticated player's arbitrary policy. claim is a fresh secret
// generated and retained by the creator before its first create request.
// Creation becomes durable only when open succeeds. A broker must load an
// existing room first and use creator_grant for a lost create reply.
make_room :: proc(
    room, content: u64,
    claim: Secret,
    endpoint: auth.Endpoint,
    policy := auth.DEFAULT_POLICY,
    entropy := Entropy{read = random_bytes},
) -> (
    Bundle,
    Error,
) {
    c := claim

    if !nonzero(c[:]) {
        return {}, .Invalid
    }

    b := Bundle {
        version = VERSION,
        record  = auth.record_make(room, content, {1, 1}, policy),
    }
    e, err := new_enrollment(claim, {}, endpoint, entropy)

    if err != .None {
        return {}, err
    }

    b.enrollments[0] = e
    b.record.members[0] = {
        identity          = {1, 1},
        endpoint          = endpoint,
        enabled           = true,
        can_host          = true,
        trusted_authority = true,
        infrastructure    = policy.mode == .Dedicated,
        game_token_hash   = rec.hash(e.token[:]),
    }

    if !bundle_valid(b) {
        return {}, .Invalid
    }

    return b, .None
}

open :: proc(
    r: ^Room,
    bundle: Bundle,
    commit: Commit,
    user: rawptr,
    clock: auth.Clock_Source,
    wire: tr.Transport = {},
    entropy := Entropy{read = random_bytes},
    allocator := context.allocator,
) -> Error {
    if r.ready ||
       r.service.ready ||
       commit == nil ||
       clock.read == nil ||
       entropy.read == nil ||
       !bundle_valid(bundle) {
        return .Invalid
    }

    r.bundle, r.commit, r.user, r.entropy = bundle, commit, user, entropy
    credentials: [auth.MAX_MEMBERS]auth.Credential
    count := 0

    for member, i in bundle.record.members {
        if member.enabled {
            credentials[count] = {member.identity, bundle.enrollments[i].key}
            count += 1
        }
    }

    err := auth.service_init(
        &r.service,
        bundle.record,
        authority_commit,
        r,
        clock,
        wire,
        credentials[:count],
        allocator,
    )
    crypto.zero_explicit(&credentials, size_of(credentials))

    if err != .None {
        close(r)

        if err == .Clock {
            return .Clock
        }

        if err == .Storage {
            return .Storage
        }

        return .Invalid
    }

    // Keep revoked keys separate from admission credentials. They can only
    // authenticate a minimal disabled-member denial, including after restart.
    for member, i in bundle.record.members {
        if member.identity.member != 0 && !member.enabled {
            r.service.disabled_credentials[i] = {member.identity, bundle.enrollments[i].key}
        }
    }

    r.ready = true
    return .None
}

close :: proc(r: ^Room) {
    auth.service_destroy(&r.service)
    crypto.zero_explicit(&r.bundle, size_of(r.bundle))
    r^ = {}
}

creator_grant :: proc(r: ^Room, claim: Secret) -> (Grant, Error) {
    if err := usable(r); err != .None {
        return {}, err
    }

    if !administrator(r, claim) || !r.bundle.record.members[0].enabled {
        return {}, .Denied
    }

    return grant(r.bundle, 0), .None
}

// The creator explicitly chooses whether an invite discloses full authority
// backups. A dedicated room never grants infrastructure authority through an
// invite. ticket_secret is generated before the request so retries are exact.
invite :: proc(r: ^Room, admin, ticket_secret: Secret, role: Role, uses: u8 = 1) -> (Ticket, Error) {
    if err := usable(r); err != .None {
        return {}, err
    }

    if !administrator(r, admin) {
        return {}, .Denied
    }

    s := ticket_secret

    if !nonzero(s[:]) || role > .Trusted_Peer || uses == 0 || uses >= auth.MAX_MEMBERS {
        return {}, .Invalid
    }

    if role == .Trusted_Peer && r.bundle.record.policy.mode == .Dedicated {
        return {}, .Denied
    }

    digest := rec.hash(s[:])

    // Separate secrets for administration, invites, and enrollment retries.
    for e in r.bundle.enrollments {
        if equal_hash(digest, e.claim_hash) {
            return {}, .Invalid
        }
    }

    slot := -1

    for item, i in r.bundle.invites {
        if equal_hash(item.hash, digest) {
            if item.role != role || item.limit != uses {
                return {}, .Denied
            }

            if item.revoked {
                return {}, .Denied
            }

            return {r.bundle.record.room, ticket_secret}, .None
        }

        if item == (Invite{}) && slot < 0 {
            slot = i
        }
    }

    if slot < 0 {
        return {}, .Capacity
    }

    next := r.bundle
    next.invites[slot] = {digest, role, uses, uses, false}

    if err := publish(r, next); err != .None {
        return {}, err
    }

    return {r.bundle.record.room, ticket_secret}, .None
}

revoke :: proc(r: ^Room, admin: Secret, ticket: Ticket) -> Error {
    if err := usable(r); err != .None {
        return err
    }

    if !administrator(r, admin) || ticket.room != r.bundle.record.room {
        return .Denied
    }

    s := ticket.secret
    digest := rec.hash(s[:])

    for item, i in r.bundle.invites {
        if !equal_hash(item.hash, digest) {
            continue
        }

        if item.revoked {
            return .None
        }

        next := r.bundle
        next.invites[i].revoked = true
        return publish(r, next)
    }

    return .Denied
}

// claim is a fresh client-held secret. The same ticket + claim + endpoint
// returns the same credential after a lost reply, including after restart.
// An exhausted/revoked invite cannot add members; already committed enrollment
// retries still work unless that member has been disabled. Slots never recycle.
join :: proc(r: ^Room, ticket: Ticket, claim: Secret, endpoint: auth.Endpoint) -> (Grant, Error) {
    if err := usable(r); err != .None {
        return {}, err
    }

    s, c := ticket.secret, claim

    if ticket.room != r.bundle.record.room || !nonzero(s[:]) || !nonzero(c[:]) {
        return {}, .Denied
    }

    ih, ch := rec.hash(s[:]), rec.hash(c[:])

    for item in r.bundle.invites {
        if equal_hash(item.hash, ch) {
            return {}, .Invalid
        }
    }

    slot := -1

    for e, i in r.bundle.enrollments {
        if equal_hash(e.claim_hash, ch) {
            if i == 0 ||
               !equal_hash(e.invite_hash, ih) ||
               e.endpoint != endpoint ||
               !r.bundle.record.members[i].enabled {
                return {}, .Denied
            }

            return grant(r.bundle, i), .None
        }

        if e == (Enrollment{}) && slot < 0 {
            slot = i
        }
    }

    inv := -1

    for item, i in r.bundle.invites {
        if equal_hash(item.hash, ih) && !item.revoked && item.remaining != 0 {
            inv = i
            break
        }
    }

    if inv < 0 {
        return {}, .Denied
    }

    if slot < 0 {
        return {}, .Capacity
    }

    e, err := new_enrollment(claim, ih, endpoint, r.entropy)

    if err != .None {
        return {}, err
    }

    for previous in r.bundle.enrollments {
        if previous.key == e.key || previous.token == e.token {
            return {}, .Entropy
        }
    }

    next := r.bundle
    next.enrollments[slot] = e
    next.invites[inv].remaining -= 1
    trusted := next.invites[inv].role == .Trusted_Peer
    next.record.members[slot] = {
        identity          = {u64(slot + 1), 1},
        endpoint          = endpoint,
        enabled           = true,
        can_host          = trusted,
        trusted_authority = trusted,
        game_token_hash   = rec.hash(e.token[:]),
    }

    if !bundle_valid(next) {
        return {}, .Invalid
    }

    if err := publish(r, next); err != .None {
        return {}, err
    }

    // Credentials are keyed by member ID, while request budgets use roster index.
    for &credential in r.service.credentials {
        if credential.identity.member == 0 {
            credential = {next.record.members[slot].identity, e.key}
            break
        }
    }

    r.service.budget[slot] = 32
    return grant(r.bundle, slot), .None
}

bundle_valid :: proc(b: Bundle) -> bool {
    b := b

    if b.version != VERSION ||
       !auth.record_valid(b.record) ||
       b.record.members[0].identity.member != 1 ||
       b.record.bootstrap.member != 1 ||
       !nonzero(b.enrollments[0].claim_hash[:]) ||
       b.enrollments[0].invite_hash != ([32]u8{}) {
        return false
    }

    for e, i in b.enrollments {
        e := e
        m := b.record.members[i]

        if m.identity.member == 0 {
            if e != (Enrollment{}) {
                return false
            }

            continue
        }

        if m.identity.member != u64(i + 1) ||
           !nonzero(e.claim_hash[:]) ||
           !nonzero(e.key[:]) ||
           !nonzero(e.token[:]) ||
           rec.hash(e.token[:]) != m.game_token_hash {
            return false
        }

        // Enrollment endpoints remain the original retry payload after rebind.
        probe := b.record
        probe.members[i].endpoint = e.endpoint

        if !auth.record_valid(probe) {
            return false
        }

        for previous in b.enrollments[:i] {
            if previous.claim_hash == e.claim_hash || previous.key == e.key || previous.token == e.token {
                return false
            }
        }

        if i != 0 {
            found := false

            for item in b.invites {
                if item.hash == e.invite_hash && item.hash != ([32]u8{}) {
                    found = true
                }
            }

            if !found {
                return false
            }
        }
    }

    for item, i in b.invites {
        item := item

        if item == (Invite{}) {
            continue
        }

        if !nonzero(item.hash[:]) ||
           item.role > .Trusted_Peer ||
           item.limit == 0 ||
           item.limit >= auth.MAX_MEMBERS ||
           item.remaining > item.limit ||
           (b.record.policy.mode == .Dedicated && item.role == .Trusted_Peer) {
            return false
        }

        for previous in b.invites[:i] {
            if previous.hash == item.hash {
                return false
            }
        }

        used := 0

        for e in b.enrollments {
            if e.claim_hash == item.hash {
                return false
            }

            if e.invite_hash == item.hash {
                used += 1
            }
        }

        if used + int(item.remaining) != int(item.limit) {
            return false
        }
    }

    return true
}

@(private)
random_bytes :: proc(_: rawptr, dst: []u8) -> bool {
    when crypto.HAS_RAND_BYTES {
        crypto.rand_bytes(dst)
        return true
    } else {
        return false
    }
}

@(private)
nonzero :: proc(bytes: []u8) -> bool {
    bits := u8(0)

    for b in bytes {
        bits |= b
    }

    return bits != 0
}

@(private)
equal_hash :: proc(a, b: [32]u8) -> bool {
    a, b := a, b
    return crypto.compare_constant_time(a[:], b[:]) == 1
}

@(private)
administrator :: proc(r: ^Room, claim: Secret) -> bool {
    c := claim
    return(
        r.bundle.record.members[0].enabled &&
        nonzero(c[:]) &&
        equal_hash(rec.hash(c[:]), r.bundle.enrollments[0].claim_hash) \
    )
}

@(private)
usable :: proc(r: ^Room) -> Error {
    if !r.ready {
        return .Not_Ready
    }

    if r.service.coordinator.poisoned {
        return .Storage
    }

    if r.bundle.record != r.service.coordinator.record {
        r.service.coordinator.poisoned = true
        r.service.coordinator.active = false
        return .Storage
    }

    return .None
}

@(private)
new_enrollment :: proc(
    claim: Secret,
    invite_hash: [32]u8,
    endpoint: auth.Endpoint,
    entropy: Entropy,
) -> (
    Enrollment,
    Error,
) {
    c := claim
    e := Enrollment {
        claim_hash  = rec.hash(c[:]),
        invite_hash = invite_hash,
        endpoint    = endpoint,
    }

    if entropy.read == nil ||
       !entropy.read(entropy.user, e.key[:]) ||
       !entropy.read(entropy.user, e.token[:]) ||
       !nonzero(e.key[:]) ||
       !nonzero(e.token[:]) {
        return {}, .Entropy
    }

    return e, .None
}

@(private)
grant :: proc(b: Bundle, slot: int) -> Grant {
    m, e := b.record.members[slot], b.enrollments[slot]
    return {
        b.record.room,
        b.record.content,
        m.identity,
        e.key,
        e.token,
        m.can_host,
        m.trusted_authority,
        m.infrastructure,
    }
}

@(private)
authority_commit :: proc(user: rawptr, expected: u64, record: auth.Record) -> bool {
    r := cast(^Room)user

    if expected != r.bundle.record.revision {
        return false
    }

    next := r.bundle
    next.record = record

    if !bundle_valid(next) || !r.commit(r.user, expected, next) {
        return false
    }

    r.bundle = next
    return true
}

@(private)
publish :: proc(r: ^Room, next: Bundle) -> Error {
    next := next

    if r.bundle.record.revision == max(u64) {
        return .Capacity
    }

    next.record.revision = r.bundle.record.revision + 1

    if !bundle_valid(next) {
        return .Invalid
    }

    if !r.commit(r.user, r.bundle.record.revision, next) {
        r.service.coordinator.poisoned, r.service.coordinator.active = true, false
        return .Storage
    }

    r.bundle, r.service.coordinator.record = next, next.record
    return .None
}
