package p2p_provision_test

import "core:testing"
import auth "godot:replay/authority"
import pp "godot:replay/p2p/provision"
import p "godot:replay/provision"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

Hub_Fixture :: struct {
    base:   Fixture,
    hub:    pp.Hub,
    client: p.Client,
}

hub_setup :: proc(f: ^Hub_Fixture) {
    b := &f.base
    assert(
        tr.memory_init(
            &b.memory,
            cfg = {2, 128, tr.MAX_PACKET_BYTES, 8192},
            faults = {latency_ticks = 1, retry_ticks = 3},
        ),
    )

    for &e, i in b.endpoints {
        assert(tr.memory_open(&b.memory, &e, tr.Peer_Id(i + 1)))
    }

    cfg := pp.HUB_CONFIG
    cfg.content, cfg.rooms = 55, 1
    assert(
        pp.hub_open(
            &f.hub,
            cfg,
            nil,
            commit,
            &b.ledger,
            {b, clock},
            tr.memory_transport(&b.endpoints[0]),
            {b, random},
        ) ==
        .None,
    )
    assert(p.client_open(&f.client, tr.memory_transport(&b.endpoints[1]), {b, clock}))
}

hub_destroy :: proc(f: ^Hub_Fixture) {
    p.client_close(&f.client)
    pp.hub_close(&f.hub)
    destroy(&f.base)
}

hub_call :: proc(f: ^Hub_Fixture, q: p.Request) -> p.Reply {
    assert(p.client_begin(&f.client, q) == .None)

    for _ in 0 ..< 100 {
        b := &f.base
        b.now += 10
        assert(tr.memory_advance(&b.memory, b.now / 10))
        assert(p.client_pump(&f.client) == .None)
        wire := tr.memory_transport(&b.endpoints[0])
        buffer: [tr.MAX_PACKET_BYTES]u8

        for _ in 0 ..< 32 {
            packet := tr.receive(&wire, buffer[:])

            if packet.state != .Received {
                break
            }

            pp.hub_receive(&f.hub, packet.from, buffer[:packet.count])
        }

        if f.client.complete {
            return f.client.reply
        }
    }

    panic("P2P enrollment reply missing")
}

create_request :: proc(room: u64 = 871) -> p.Request {
    return {version = p.PROTOCOL, verb = .Create, room = room, content = 55, claim = ADMIN, endpoint = address()}
}

@(test)
existing_enrollment_client_creates_invites_and_joins_fixed_p2p_room :: proc(t: ^testing.T) {
    f: Hub_Fixture
    hub_setup(&f)
    defer hub_destroy(&f)
    creator := hub_call(&f, create_request())
    testing.expect(t, creator.result == .None && !creator.grant.can_host && !creator.grant.trusted_authority)
    before := f.base.ledger.writes
    retry := hub_call(&f, create_request())
    testing.expect(t, retry.grant == creator.grant && f.base.ledger.writes == before)
    testing.expect_value(t, hub_call(&f, create_request(872)).result, p.Error.Capacity)
    q := p.Request {
        version = p.PROTOCOL,
        verb    = .Invite,
        room    = 871,
        content = 55,
        claim   = ADMIN,
        ticket  = INVITE,
        role    = .Trusted_Peer,
        uses    = 1,
    }
    testing.expect_value(t, hub_call(&f, q).result, p.Error.Denied)
    q.role = .Player
    testing.expect_value(t, hub_call(&f, q).result, p.Error.None)
    q = {
        version  = p.PROTOCOL,
        verb     = .Join,
        room     = 871,
        content  = 55,
        claim    = CLAIM,
        ticket   = INVITE,
        endpoint = address(45002),
    }
    joined := hub_call(&f, q)
    testing.expect(t, joined.result == .None && joined.grant.identity == (auth.Identity{2, 1}))
    before = f.base.ledger.writes
    testing.expect_value(t, hub_call(&f, q).grant, joined.grant)
    testing.expect_value(t, f.base.ledger.writes, before)
    room := pp.hub_room(&f.hub, 871)
    assert(room != nil)
    reg, error := pp.registry(room)
    testing.expect(t, error == .None && reg.match.session == 871 && reg.match.count == 2)
    // Existing durable client enrollment records accept the no-authority grant.
    journal: p.Enrollment_Journal
    assert(p.enrollment_open(&journal, "wss://example.invalid/p2p", 55))
    defer p.enrollment_close(&journal)
    assert(p.enrollment_loaded(&journal, {}, false, 0))
    assert(p.enrollment_begin(&journal, q))
    assert(p.enrollment_receipt(&journal, 1))
    assert(p.enrollment_accept(&journal, joined))
    assert(p.enrollment_receipt(&journal, 2))
    granted, ready := p.enrollment_grant(&journal)
    testing.expect(t, ready && granted == joined.grant)
}

@(test)
hub_refuses_malformed_requests_rate_limits_and_fences_uncertain_creation :: proc(t: ^testing.T) {
    f: Hub_Fixture
    hub_setup(&f)
    defer hub_destroy(&f)
    f.base.ledger.lost_ack = true
    testing.expect_value(t, hub_call(&f, create_request()).result, p.Error.Storage)
    testing.expect(t, f.hub.poisoned && f.base.ledger.bundle.enrollment.record.room == 871)
    f.base.ledger.lost_ack = false
    testing.expect_value(t, hub_call(&f, create_request()).result, p.Error.Storage)
    pp.hub_close(&f.hub)
    cfg := pp.HUB_CONFIG
    cfg.content, cfg.rooms = 55, 1
    existing := [1]pp.Bundle{f.base.ledger.bundle}
    cfg.players = 3
    testing.expect_value(
        t,
        pp.hub_open(
            &f.hub,
            cfg,
            existing[:],
            commit,
            &f.base.ledger,
            {&f.base, clock},
            tr.memory_transport(&f.base.endpoints[0]),
            {&f.base, random},
        ),
        p.Error.Invalid,
    )
    cfg.players = 2
    assert(
        pp.hub_open(
            &f.hub,
            cfg,
            existing[:],
            commit,
            &f.base.ledger,
            {&f.base, clock},
            tr.memory_transport(&f.base.endpoints[0]),
            {&f.base, random},
        ) ==
        .None,
    )
    testing.expect_value(t, hub_call(&f, create_request()).result, p.Error.None)
    before := f.base.ledger.writes
    q := create_request()
    q.uses = 1
    bytes: [p.PACKET_BYTES]u8
    count := sc.HEADER_BYTES + f.hub.codecs.request.wire_size
    assert(
        sc.pack(&f.hub.codecs.request, q, {kind = p.REQUEST_KIND, epoch = u64(p.PROTOCOL), content = 55}, bytes[:count]).error ==
        .None,
    )
    testing.expect(t, !pp.hub_receive(&f.hub, 2, bytes[:count]) && f.base.ledger.writes == before)
    limited := false

    for _ in 0 ..< 20 {
        if hub_call(&f, create_request()).result == .Rate_Limited {
            limited = true
        }
    }

    testing.expect(t, limited && f.hub.limited > 0 && f.base.ledger.writes == before)
}
