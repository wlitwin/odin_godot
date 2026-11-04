package replay_provision_test

import "core:testing"
import p "godot:replay/provision"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

Hub_Ledger :: struct {
    rooms:    [4]p.Bundle,
    writes:   int,
    fail_ack: bool,
}

Hub_Fixture :: struct {
    hub:       p.Hub,
    ledger:    Hub_Ledger,
    clock:     Clock,
    rng:       Random,
    memory:    tr.Memory,
    endpoints: [2]tr.Memory_Endpoint,
    client:    p.Client,
}

hub_commit :: proc(user: rawptr, expected: u64, next: p.Bundle) -> bool {
    l := cast(^Hub_Ledger)user
    slot := -1

    for b, i in l.rooms {
        if b.record.room == next.record.room {
            slot = i
            break
        }
    }

    if slot < 0 {
        for b, i in l.rooms {
            if b.record.room == 0 {
                slot = i
                break
            }
        }
    }

    if slot < 0 ||
       l.rooms[slot].record.revision != expected ||
       next.record.revision != expected + 1 ||
       !p.bundle_valid(next) {
        return false
    }

    l.rooms[slot] = next
    l.writes += 1
    return !l.fail_ack
}

hub_setup :: proc(f: ^Hub_Fixture, rooms: int = 2, dedicated: bool = false) {
    tr.memory_init(&f.memory, cfg = {2, 128, tr.MAX_PACKET_BYTES, 8192}, faults = {latency_ticks = 1, retry_ticks = 3})

    for &e, i in f.endpoints {
        tr.memory_open(&f.memory, &e, tr.Peer_Id(i + 1))
    }

    cfg := p.HUB_CONFIG
    cfg.content, cfg.rooms = 55, rooms

    if dedicated {
        cfg.policy.mode = .Dedicated
    }

    assert(
        p.hub_open(
            &f.hub,
            cfg,
            nil,
            hub_commit,
            &f.ledger,
            {&f.clock, clock_read},
            tr.memory_transport(&f.endpoints[0]),
            {&f.rng, random_read},
        ) ==
        .None,
    )
    assert(p.client_open(&f.client, tr.memory_transport(&f.endpoints[1]), {&f.clock, clock_read}))
}

hub_destroy :: proc(f: ^Hub_Fixture) {
    p.client_close(&f.client)
    p.hub_close(&f.hub)

    for &e in f.endpoints {
        wire := tr.memory_transport(&e)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.memory)
}

hub_call :: proc(f: ^Hub_Fixture, q: p.Request) -> p.Reply {
    assert(p.client_begin(&f.client, q) == .None)

    for _ in 0 ..< 100 {
        f.clock.now += 10
        tr.memory_advance(&f.memory, f.clock.now / 10)
        assert(p.client_pump(&f.client) == .None)
        wire := tr.memory_transport(&f.endpoints[0])
        buffer: [tr.MAX_PACKET_BYTES]u8

        for _ in 0 ..< 32 {
            packet := tr.receive(&wire, buffer[:])

            if packet.state != .Received {
                break
            }

            p.hub_receive(&f.hub, packet.from, buffer[:packet.count])
        }

        if f.client.complete {
            return f.client.reply
        }
    }

    panic("provision reply missing")
}

create_request :: proc(room: u64 = 44) -> p.Request {
    return {version = p.PROTOCOL, verb = .Create, room = room, content = 55, claim = ADMIN, endpoint = address()}
}

@(test)
protocol_create_join_retries_are_correlated_and_do_not_recreate_rooms :: proc(t: ^testing.T) {
    f: Hub_Fixture
    hub_setup(&f)
    defer hub_destroy(&f)
    q := create_request()
    creator := hub_call(&f, q)
    testing.expect_value(t, creator.result, p.Error.None)
    before := f.ledger.writes
    retry := hub_call(&f, q)
    testing.expect_value(t, retry.grant, creator.grant)
    testing.expect_value(t, f.ledger.writes, before)
    q.endpoint = address(45002)
    testing.expect_value(t, hub_call(&f, q).result, p.Error.Denied)
    q = {
        version = p.PROTOCOL,
        verb    = .Invite,
        room    = 44,
        content = 55,
        claim   = ADMIN,
        ticket  = INVITE,
        role    = .Trusted_Peer,
        uses    = 1,
    }
    testing.expect_value(t, hub_call(&f, q).result, p.Error.None)
    q = {
        version  = p.PROTOCOL,
        verb     = .Join,
        room     = 44,
        content  = 55,
        claim    = CLAIM,
        ticket   = INVITE,
        endpoint = address(45002),
    }
    guest := hub_call(&f, q)
    testing.expect_value(t, guest.result, p.Error.None)
    testing.expect(t, guest.grant.identity.member == 2 && guest.grant.can_host && guest.grant.key != creator.grant.key)
    before = f.ledger.writes
    testing.expect_value(t, hub_call(&f, q).grant, guest.grant)
    testing.expect_value(t, f.ledger.writes, before)
    // A valid old reply from the TLS endpoint is still not a reply to a new request.
    q.claim = {
        0 = 66,
    }
    assert(p.client_begin(&f.client, q) == .None)
    bytes: [p.PACKET_BYTES]u8
    count := sc.HEADER_BYTES + f.hub.codecs.reply.wire_size
    assert(
        sc.pack(&f.hub.codecs.reply, guest, {kind = p.REPLY_KIND, epoch = 1, content = 55}, bytes[:count]).error ==
        .None,
    )
    testing.expect(t, !p.client_receive(&f.client, 1, bytes[:count]) && f.client.pending)
}

@(test)
hub_limits_and_invalid_packets_do_not_allocate_or_write :: proc(t: ^testing.T) {
    f: Hub_Fixture
    hub_setup(&f, 1)
    defer hub_destroy(&f)
    q := create_request()
    testing.expect_value(t, hub_call(&f, q).result, p.Error.None)
    testing.expect_value(t, hub_call(&f, create_request(45)).result, p.Error.Capacity)
    before := f.ledger.writes
    q.uses = 1
    testing.expect_value(t, p.client_begin(&f.client, q), p.Error.Invalid)
    bytes: [p.PACKET_BYTES]u8
    count := sc.HEADER_BYTES + f.hub.codecs.request.wire_size
    assert(
        sc.pack(&f.hub.codecs.request, q, {kind = p.REQUEST_KIND, epoch = 1, content = 55}, bytes[:count]).error ==
        .None,
    )
    testing.expect(t, !p.hub_receive(&f.hub, 2, bytes[:count]))
    testing.expect_value(t, f.ledger.writes, before)
    limited := false

    for _ in 0 ..< 20 {
        if hub_call(&f, create_request()).result == .Rate_Limited {
            limited = true
        }
    }

    testing.expect(t, limited && f.hub.limited > 0 && f.ledger.writes == before)
}

@(test)
uncertain_create_fences_hub_until_durable_inventory_is_reloaded :: proc(t: ^testing.T) {
    f: Hub_Fixture
    hub_setup(&f)
    defer hub_destroy(&f)
    f.ledger.fail_ack = true
    testing.expect_value(t, hub_call(&f, create_request()).result, p.Error.Storage)
    testing.expect(t, f.hub.poisoned && f.ledger.rooms[0].record.room == 44)
    f.ledger.fail_ack = false
    testing.expect_value(t, hub_call(&f, create_request()).result, p.Error.Storage)
    p.hub_close(&f.hub)
    cfg := p.HUB_CONFIG
    cfg.content, cfg.rooms = 55, 2
    assert(
        p.hub_open(
            &f.hub,
            cfg,
            f.ledger.rooms[:1],
            hub_commit,
            &f.ledger,
            {&f.clock, clock_read},
            tr.memory_transport(&f.endpoints[0]),
            {&f.rng, random_read},
        ) ==
        .None,
    )
    reply := hub_call(&f, create_request())
    testing.expect(t, reply.result == .None && reply.grant.key == f.ledger.rooms[0].enrollments[0].key)
    testing.expect_value(t, f.ledger.rooms[0].record.coordinator_generation, u64(2))
}

@(test)
public_create_cannot_assign_infrastructure_authority :: proc(t: ^testing.T) {
    f: Hub_Fixture
    hub_setup(&f, dedicated = true)
    defer hub_destroy(&f)
    reply := hub_call(&f, create_request())
    testing.expect_value(t, reply.result, p.Error.Denied)
    testing.expect_value(t, reply.grant, p.Grant{})
    testing.expect(t, f.ledger.writes == 0 && p.hub_room(&f.hub, 44) == nil)
}
