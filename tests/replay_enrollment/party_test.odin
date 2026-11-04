package enrollment_test

import "core:testing"
import p "godot:replay/provision"
import rgd "godot:replay/godot"
import auth "godot:replay/authority"
import tr "godot:replay/transport"
import "core:strings"

Party_Ledger :: struct {
    record:         p.Enrollment_Record,
    room, revision: u64,
    conflict:       bool,
    opens, writes:  int,
}

party_load :: proc(user: rawptr) -> (p.Enrollment_Record, bool, p.Enrollment_Error) {
    l := cast(^Party_Ledger)user
    return l.record, l.record.version != 0, .None
}

party_write :: proc(user: rawptr, expected: u64, next: p.Enrollment_Record) -> (u64, p.Enrollment_Error) {
    l := cast(^Party_Ledger)user

    if !p.enrollment_transition(l.record, l.record.version != 0, expected, next) {
        return 0, .Conflict
    }

    l.record = next
    l.writes += 1
    return next.revision, .None
}

party_slot :: proc(user: rawptr, slot: string) -> (rgd.Enrollment_Backing, bool) {
    l := cast(^Party_Ledger)user
    l.opens += 1
    return {user, party_load, party_write}, len(slot) == 81
}

party_cursor :: proc(user: rawptr, key: string) -> (u64, u64, rgd.Party_Error) {
    l := cast(^Party_Ledger)user
    return l.room, l.revision, .None
}

party_select :: proc(user: rawptr, key: string, room, expected: u64) -> rgd.Party_Error {
    l := cast(^Party_Ledger)user

    if l.conflict || l.revision != expected {
        return .Conflict
    }

    l.room, l.revision = room, expected + 1
    return .None
}

party_entropy :: proc(user: rawptr, dst: []u8) -> bool {
    for &b in dst {
        b = 71
    }

    return true
}

party_config :: proc(l: ^Party_Ledger) -> rgd.Party_Config {
    return {
        service = SERVICE,
        namespace = "party-test",
        content = 55,
        endpoint = request().endpoint,
        invite_role = .Trusted_Peer,
        invite_uses = 3,
        entropy = {read = party_entropy},
        storage = {l, party_slot, party_cursor, party_select},
    }
}

@(test)
ready_guest_rejoin_requires_no_provisioning_connection :: proc(t: ^testing.T) {
    l: Party_Ledger
    o: rgd.Party
    defer rgd.party_close(&o)
    url, _ := p.service_url(SERVICE)
    q := request()
    q.verb, q.ticket = .Join, {
            0 = 91,
        }
    l.record = {
        version = p.ENROLLMENT_VERSION,
        revision = 2,
        state = .Ready,
        service = url,
        request = q,
        grant = {room = 44, content = 55, identity = {2, 3}, key = {0 = 51}, token = {0 = 61}},
    }
    l.room, l.revision = 44, 1
    assert(rgd.party_open(&o, party_config(&l)))
    assert(rgd.party_begin(&o, .Rejoin))
    rgd.party_frame(&o)
    g, ready := rgd.party_grant(&o)
    testing.expect(t, ready && g == l.record.grant && !o.connection.ready && l.writes == 0)
    session := rgd.SESSION_OPTIONS
    session.network.content = 55
    options, ok := rgd.party_room_options(&o, session)
    testing.expect(
        t,
        ok && options.automatic_successor && !options.provisioned_incarnation && options.session.token == g.token,
    )
    testing.expect(t, !options.session.replication.accept_checkpoints)
}

@(test)
recent_room_conflict_prevents_transmission_but_keeps_the_durable_pending_request :: proc(t: ^testing.T) {
    l := Party_Ledger {
        conflict = true,
    }
    o: rgd.Party
    defer rgd.party_close(&o)
    assert(rgd.party_open(&o, party_config(&l)))
    assert(rgd.party_begin(&o, .Create))
    rgd.party_frame(&o)
    rgd.party_frame(&o)
    testing.expect(t, o.failed && o.error == .Conflict && !o.connection.ready && !o.connection.client.pending)
    testing.expect(
        t,
        l.writes == 1 && l.record.state == .Pending && l.record.request == o.profile.value.record.request,
    )
    _, ready := rgd.party_grant(&o)
    testing.expect(t, !ready)
}

@(test)
revoked_invite_does_not_revoke_a_stored_creator_credential :: proc(t: ^testing.T) {
    Server_Store :: struct {
        bundle: p.Bundle,
        now:    u64,
    }

    commit :: proc(user: rawptr, expected: u64, next: p.Bundle) -> bool {
        s := cast(^Server_Store)user

        if s.bundle.record.revision != expected {
            return false
        }

        s.bundle = next
        return true
    }

    clock :: proc(user: rawptr) -> (u64, bool) {
        return (cast(^Server_Store)user).now, true
    }

    s: Server_Store
    hub: p.Hub
    room: p.Room
    l: Party_Ledger
    o: rgd.Party
    memory: tr.Memory
    endpoints: [2]tr.Memory_Endpoint
    assert(tr.memory_init(&memory, cfg = {2, 128, tr.MAX_PACKET_BYTES, 8192}))
    defer tr.memory_destroy(&memory)

    for &e, i in endpoints {
        tr.memory_open(&memory, &e, tr.Peer_Id(i + 1))
    }

    defer {
        for &e in endpoints {
            wire := tr.memory_transport(&e)
            tr.close(&wire)
        }
    }

    q := request()
    b, error := p.make_room(q.room, q.content, q.claim, q.endpoint)
    assert(error == .None)
    assert(p.open(&room, b, commit, &s, {&s, clock}) == .None)
    g, err := p.creator_grant(&room, q.claim)
    assert(err == .None)
    url, _ := p.service_url(SERVICE)
    l.record = {
        version  = p.ENROLLMENT_VERSION,
        revision = 2,
        state    = .Ready,
        service  = url,
        request  = q,
        grant    = g,
    }
    invite, ok := p.creator_invite(l.record, .Trusted_Peer, 3)
    assert(ok)
    ticket, issued := p.invite(&room, q.claim, invite.ticket, .Trusted_Peer, 3)
    assert(issued == .None)
    assert(p.revoke(&room, q.claim, ticket) == .None)
    p.close(&room)
    cfg := p.HUB_CONFIG
    cfg.content = 55
    existing := [1]p.Bundle{s.bundle}
    assert(p.hub_open(&hub, cfg, existing[:], commit, &s, {&s, clock}, tr.memory_transport(&endpoints[0])) == .None)
    defer p.hub_close(&hub)
    l.room, l.revision = 44, 1
    assert(rgd.party_open(&o, party_config(&l)))
    defer rgd.party_close(&o)
    assert(rgd.party_begin(&o, .Rejoin))
    // Inject the packet transport at the connection boundary; all real protocol
    // and admission checks still run, without requiring an engine in this test.
    o.connection.ready = true
    o.connection.url = strings.clone(SERVICE)
    assert(p.client_open(&o.connection.client, tr.memory_transport(&endpoints[1]), {&s, clock}))

    for _ in 0 ..< 100 {
        s.now += 10
        tr.memory_advance(&memory, s.now / 10)
        rgd.party_frame(&o)
        wire := tr.memory_transport(&endpoints[0])
        bytes: [tr.MAX_PACKET_BYTES]u8
        packet := tr.receive(&wire, bytes[:])

        if packet.state == .Received {
            p.hub_receive(&hub, packet.from, bytes[:packet.count])
        }

        if o.ready {
            break
        }
    }

    grant, ready := rgd.party_grant(&o)
    testing.expect(t, ready && grant == g && !o.failed && !o.invited && o.invite_error == .Denied)
    testing.expect(t, l.writes == 0 && s.bundle.invites[0].revoked)
}
