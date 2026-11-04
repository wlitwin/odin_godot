package p2p_provision_test

import "core:testing"
import auth "godot:replay/authority"
import adm "godot:replay/p2p/admission"
import pp "godot:replay/p2p/provision"
import p "godot:replay/provision"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

ADMIN :: p.Secret {
    0 = 41,
}
INVITE :: p.Secret {
    0 = 42,
}
CLAIM :: p.Secret {
    0 = 43,
}

Ledger :: struct {
    bundle:         pp.Bundle,
    writes:         int,
    fail, lost_ack: bool,
}

Fixture :: struct {
    room:      pp.Room,
    ledger:    Ledger,
    now:       u64,
    random:    u8,
    memory:    tr.Memory,
    endpoints: [2]tr.Memory_Endpoint,
}

commit :: proc(user: rawptr, expected: u64, next: pp.Bundle) -> bool {
    l := cast(^Ledger)user

    if l.fail ||
       l.bundle.enrollment.record.revision != expected ||
       next.enrollment.record.revision != expected + 1 ||
       !pp.bundle_valid(next) {
        return false
    }

    if expected != 0 &&
       (next.players != l.bundle.players || next.enrollment.record.room != l.bundle.enrollment.record.room) {
        return false
    }

    l.bundle = next
    l.writes += 1
    return !l.lost_ack
}

clock :: proc(user: rawptr) -> (u64, bool) {
    return (cast(^Fixture)user).now, true
}

random :: proc(user: rawptr, dst: []u8) -> bool {
    f := cast(^Fixture)user
    f.random += 1

    for &b in dst {
        b = f.random
    }

    return true
}

address :: proc(port: u16 = 45001) -> auth.Endpoint {
    e, ok := auth.endpoint("127.0.0.1", port)
    assert(ok)
    return e
}

setup :: proc(f: ^Fixture, players: u8 = 2) {
    assert(
        tr.memory_init(
            &f.memory,
            cfg = {2, 128, tr.MAX_PACKET_BYTES, 8192},
            faults = {latency_ticks = 1, retry_ticks = 3},
        ),
    )

    for &e, i in f.endpoints {
        assert(tr.memory_open(&f.memory, &e, tr.Peer_Id(i + 1)))
    }

    b, error := pp.make_room(871, 55, players, ADMIN, address(), {f, random})
    assert(error == .None)
    assert(
        pp.open(&f.room, b, commit, &f.ledger, {f, clock}, tr.memory_transport(&f.endpoints[0]), {f, random}) == .None,
    )
}

destroy :: proc(f: ^Fixture) {
    pp.close(&f.room)

    for &e in f.endpoints {
        wire := tr.memory_transport(&e)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.memory)
}

restart :: proc(f: ^Fixture) {
    pp.close(&f.room)
    assert(
        pp.open(
            &f.room,
            f.ledger.bundle,
            commit,
            &f.ledger,
            {f, clock},
            tr.memory_transport(&f.endpoints[0]),
            {f, random},
        ) ==
        .None,
    )
}

guest :: proc(f: ^Fixture) -> p.Grant {
    ticket, error := pp.invite(&f.room, ADMIN, INVITE)
    assert(error == .None)
    g, err := pp.join(&f.room, ticket, CLAIM, address(45002))
    assert(err == .None)
    return g
}

@(test)
fixed_roster_reserves_invite_capacity_and_publishes_only_when_full :: proc(t: ^testing.T) {
    error: p.Error
    f: Fixture
    setup(&f, 3)
    defer destroy(&f)
    _, error = pp.registry(&f.room)
    testing.expect_value(t, error, p.Error.Not_Ready)
    creator: p.Grant
    creator, error = pp.creator_grant(&f.room, ADMIN)
    testing.expect(t, error == .None && !creator.can_host && !creator.trusted_authority && !creator.infrastructure)
    ticket: p.Ticket
    ticket, error = pp.invite(&f.room, ADMIN, INVITE, 2)
    testing.expect_value(t, error, p.Error.None)
    _, error = pp.invite(&f.room, ADMIN, {0 = 90})
    testing.expect_value(t, error, p.Error.Capacity)
    _, error = pp.invite(&f.room, {0 = 99}, {0 = 90})
    testing.expect_value(t, error, p.Error.Denied)
    g: p.Grant
    g, error = pp.join(&f.room, ticket, CLAIM, address(45002))
    testing.expect_value(t, error, p.Error.None)
    _, error = pp.registry(&f.room)
    testing.expect_value(t, error, p.Error.Not_Ready)
    _, error = pp.invite(&f.room, ADMIN, INVITE, 2)
    testing.expect_value(t, error, p.Error.None)
    last: p.Grant
    last, error = pp.join(&f.room, ticket, {0 = 44}, address(45003))
    testing.expect_value(t, error, p.Error.None)
    reg: adm.Registry
    reg, error = pp.registry(&f.room)
    testing.expect(
        t,
        error == .None &&
        reg.match.session == 871 &&
        reg.match.count == 3 &&
        reg.match.members == ([8]u64{0 = 1, 1 = 2, 2 = 3}),
    )
    testing.expect(t, reg.credentials[1].key == g.key && reg.credentials[2].identity == last.identity)
    before := f.ledger.writes
    retry: p.Grant
    retry, error = pp.join(&f.room, ticket, CLAIM, address(45002))
    testing.expect_value(t, retry, g)
    testing.expect(t, error == .None && f.ledger.writes == before)
    _, error = pp.join(&f.room, ticket, {0 = 45}, address(45004))
    testing.expect_value(t, error, p.Error.Denied)
    restart(&f)
    restored: adm.Registry
    restored, error = pp.registry(&f.room)
    testing.expect_value(t, restored, reg)
    testing.expect(t, error == .None && f.ledger.bundle.players == 3 && f.ledger.bundle.enrollment.record.epoch == 0)
}

@(test)
revocation_releases_only_unused_reservations_and_never_recycles_members :: proc(t: ^testing.T) {
    error: p.Error
    f: Fixture
    setup(&f, 3)
    defer destroy(&f)
    ticket, _ := pp.invite(&f.room, ADMIN, INVITE, 2)
    g: p.Grant
    g, error = pp.join(&f.room, ticket, CLAIM, address(45002))
    testing.expect_value(t, error, p.Error.None)
    testing.expect_value(t, pp.revoke(&f.room, ADMIN, ticket), p.Error.None)
    _, error = pp.invite(&f.room, ADMIN, {0 = 70}, 2)
    testing.expect_value(t, error, p.Error.Capacity)
    replacement: p.Ticket
    replacement, error = pp.invite(&f.room, ADMIN, {0 = 70})
    testing.expect_value(t, error, p.Error.None)
    _, error = pp.join(&f.room, ticket, {0 = 71}, address(45003))
    testing.expect_value(t, error, p.Error.Denied)
    retry: p.Grant
    retry, error = pp.join(&f.room, ticket, CLAIM, address(45002))
    testing.expect_value(t, retry, g)
    testing.expect_value(t, error, p.Error.None)
    third: p.Grant
    third, error = pp.join(&f.room, replacement, {0 = 71}, address(45003))
    testing.expect(t, error == .None && third.identity.member == 3)
    _, error = pp.invite(&f.room, ADMIN, {0 = 72})
    testing.expect_value(t, error, p.Error.Capacity)
}

@(test)
ambiguous_join_never_exposes_uncommitted_registry_and_retry_recovers :: proc(t: ^testing.T) {
    error: p.Error

    for lost_ack in ([2]bool{false, true}) {
        f: Fixture
        setup(&f)
        ticket, _ := pp.invite(&f.room, ADMIN, INVITE)
        before := f.room.bundle
        f.ledger.fail, f.ledger.lost_ack = !lost_ack, lost_ack
        g: p.Grant
        g, error = pp.join(&f.room, ticket, CLAIM, address(45002))
        testing.expect(t, error == .Storage && g == (p.Grant{}) && f.room.bundle == before)
        _, error = pp.registry(&f.room)
        testing.expect_value(t, error, p.Error.Storage)
        f.ledger.fail, f.ledger.lost_ack = false, false
        restart(&f)
        g, error = pp.join(&f.room, ticket, CLAIM, address(45002))
        testing.expect_value(t, error, p.Error.None)
        reg: adm.Registry
        reg, error = pp.registry(&f.room)
        testing.expect(t, error == .None && reg.credentials[1].key == g.key && f.ledger.bundle.players == 2)
        destroy(&f)
    }
}

@(test)
private_bundle_rejects_authority_rosters_and_roundtrips_fixed_count :: proc(t: ^testing.T) {
    error: p.Error
    f: Fixture
    setup(&f)
    defer destroy(&f)
    guest(&f)

    for variation in 0 ..< 7 {
        b := f.room.bundle

        switch variation {
        case 0:
            b.players = 1
        case 1:
            b.players = 9
        case 2:
            b.enrollment.record.members[0].can_host = true
        case 3:
            b.enrollment.record.members[1].trusted_authority = true
        case 4:
            b.enrollment.record.members[1].infrastructure = true
        case 5:
            b.enrollment.invites[0].role = .Trusted_Peer
        case 6:
            b.enrollment.record.policy.lease_ms += 1
        }

        testing.expect(t, !pp.bundle_valid(b))
    }

    codec: sc.Schema
    assert(sc.init(&codec, pp.Bundle).error == .None)
    defer sc.destroy(&codec)
    bytes := make([]u8, sc.HEADER_BYTES + codec.wire_size)
    defer delete(bytes)
    testing.expect(
        t,
        sc.pack(&codec, f.room.bundle, {kind = 0x5050, epoch = u64(pp.VERSION), content = 55}, bytes).error == .None,
    )
    decoded: pp.Bundle
    _, report := sc.unpack(&codec, &decoded, bytes, {kind = 0x5050, epoch = u64(pp.VERSION), content = 55})
    testing.expect(t, report.error == .None && decoded == f.room.bundle && pp.bundle_valid(decoded))
}

init_rpc :: proc(f: ^Fixture, g: p.Grant, lease: ^auth.Lease, rpc: ^auth.Rpc_Client, nonce: u8 = 17) {
    assert(auth.lease_init(lease, g.identity, g.room, g.content, {f, clock}, false) == .None)
    assert(auth.rpc_client_init(rpc, lease, g.key, {0 = nonce}, tr.memory_transport(&f.endpoints[1])))
}

call :: proc(f: ^Fixture, rpc: ^auth.Rpc_Client, command: auth.Command) -> auth.Reply {
    assert(auth.rpc_begin(rpc, command) == .None)
    assert(pp.control_receive(&f.room, 2, rpc.txb[:rpc.count]))

    for _ in 0 ..< 10 {
        f.now += 10
        assert(tr.memory_advance(&f.memory, f.now / 10))
        assert(auth.rpc_client_pump(rpc) == .None)
        reply, done := auth.rpc_completed(rpc)

        if done {
            return reply
        }
    }

    panic("missing P2P registration reply")
}

@(test)
authenticated_roster_query_and_rebind_fence_old_proof_without_changing_match :: proc(t: ^testing.T) {
    error: p.Error
    f: Fixture
    setup(&f)
    defer destroy(&f)
    g := guest(&f)
    lease: auth.Lease
    rpc: auth.Rpc_Client
    init_rpc(&f, g, &lease, &rpc)
    defer auth.rpc_client_destroy(&rpc)
    reply := call(&f, &rpc, {verb = .Query})
    match: adm.Match
    match, error = pp.match_from_reply(reply, 871, 55, 2, g.identity)
    testing.expect_value(t, error, p.Error.None)
    reg, _ := pp.registry(&f.room)
    testing.expect_value(t, match, reg.match)
    challenge := auth.Nonce {
        0 = 67,
    }
    old := adm.proof(match, g.identity, g.key, challenge, false)
    reply = call(&f, &rpc, {verb = .Challenge})
    testing.expect(t, reply.result == .None && reply.registration_identity.incarnation == 2)
    reply = call(
        &f,
        &rpc,
        {verb = .Rebind, challenge = reply.challenge, incarnation = reply.registration_identity.incarnation},
    )
    testing.expect_value(t, reply.result, auth.Error.None)
    testing.expect_value(t, lease.identity, (auth.Identity{2, 2}))
    reg, error = pp.registry(&f.room)
    testing.expect_value(t, error, p.Error.None)
    _, _, denied := adm.verify(&reg, old[:], challenge, false)
    testing.expect_value(t, denied, auth.Error.Denied)
    fresh := adm.proof(reg.match, lease.identity, g.key, challenge, false)
    identity, code, accepted := adm.verify(&reg, fresh[:], challenge, false)
    testing.expect(t, accepted == .None && identity == lease.identity && code == adm.code(match))
    restart(&f)
    restored, _ := pp.registry(&f.room)
    testing.expect_value(t, restored, reg)
    retry: p.Grant
    retry, error = pp.join(&f.room, {871, INVITE}, CLAIM, address(45002))
    testing.expect(t, error == .None && retry.identity == lease.identity && retry.key == g.key)
}

@(test)
valid_creator_mac_cannot_start_authority_or_invoke_removal_extension :: proc(t: ^testing.T) {
    error: p.Error
    f: Fixture
    setup(&f)
    defer destroy(&f)
    guest(&f)
    g, _ := pp.creator_grant(&f.room, ADMIN)

    for verb in ([7]auth.Verb{.Start, .Renew, .Nominate, .Prepare, .Release, .Claim, .Recover_Owner}) {
        lease: auth.Lease
        rpc: auth.Rpc_Client
        init_rpc(&f, g, &lease, &rpc)
        assert(auth.rpc_begin(&rpc, {verb = verb}) == .None)
        before := f.ledger.writes
        testing.expect(t, !pp.control_receive(&f.room, 2, rpc.txb[:rpc.count]))
        testing.expect(t, f.ledger.writes == before && f.room.bundle.enrollment.record.epoch == 0)
        auth.rpc_client_destroy(&rpc)
    }

    lease: auth.Lease
    rpc: auth.Rpc_Client
    init_rpc(&f, g, &lease, &rpc)
    defer auth.rpc_client_destroy(&rpc)
    assert(auth.rpc_remove(&rpc, 1, {2, 1}) == .None)
    before := f.ledger.writes
    testing.expect(t, !pp.control_receive(&f.room, 2, rpc.txb[:rpc.count]) && f.ledger.writes == before)
    q := p.Request {
        version = p.PROTOCOL,
        verb = .Invite,
        room = 871,
        content = 55,
        claim = ADMIN,
        ticket = {0 = 90},
        role = .Trusted_Peer,
        uses = 1,
    }
    grant: p.Grant
    ticket: p.Ticket
    grant, ticket, error = pp.request(&f.room, q)
    testing.expect(t, error == .Denied && grant == (p.Grant{}) && ticket == (p.Ticket{}) && f.ledger.writes == before)
}

@(test)
roster_reply_requires_complete_enabled_and_matching_participants :: proc(t: ^testing.T) {
    error: p.Error
    f: Fixture
    setup(&f)
    defer destroy(&f)
    g, _ := pp.creator_grant(&f.room, ADMIN)
    lease: auth.Lease
    rpc: auth.Rpc_Client
    init_rpc(&f, g, &lease, &rpc)
    defer auth.rpc_client_destroy(&rpc)
    reply := call(&f, &rpc, {verb = .Query})
    _, error = pp.match_from_reply(reply, 871, 55, 2, g.identity)
    testing.expect_value(t, error, p.Error.Not_Ready)
    guest(&f)
    reply = call(&f, &rpc, {verb = .Query})

    for variation in 0 ..< 7 {
        altered := reply

        switch variation {
        case 0:
            altered.view.room += 1
        case 1:
            altered.view.content += 1
        case 2:
            altered.view.epoch = 1
        case 3:
            altered.members[1].enabled = false
        case 4:
            altered.members[1].can_host = true
        case 5:
            altered.members[2] = altered.members[1]
        case 6:
            altered.members[0].identity.incarnation += 1
        }

        _, error = pp.match_from_reply(altered, 871, 55, 2, g.identity)
        testing.expect(t, error != .None)
    }
}
