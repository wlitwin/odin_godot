package replay_provision_sqlite_test

import "core:fmt"
import "core:testing"
import auth "godot:replay/authority"
import ck "godot:replay/provision/checkpoint"
import db "godot:replay/provision/sqlite"
import p "godot:replay/provision"
import net "godot:replay/net"
import r "godot:replay"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"
import f "publication_fixture"

Checkpoint_Hub_Fixture :: struct {
    now:       u64,
    store:     db.Store,
    provision: p.Hub,
    hub:       ck.Hub,
    backend:   db.Checkpoint_Backend(f.World, u8, u8, u8, 1),
    memory:    tr.Memory,
    endpoints: [2]tr.Memory_Endpoint,
    leases:    [2]auth.Lease,
    rpcs:      [2]auth.Rpc_Client,
    clients:   [2]ck.Client,
}

checkpoint_hub_clock :: proc(user: rawptr) -> (u64, bool) {
    return (cast(^Checkpoint_Hub_Fixture)user).now, true
}

checkpoint_hub_open :: proc(x: ^Checkpoint_Hub_Fixture, path: string) {
    assert(db.open(&x.store, path, true) == .None)
    tr.memory_init(&x.memory, cfg = {2, 128, tr.MAX_PACKET_BYTES, 8192}, faults = {latency_ticks = 1, retry_ticks = 3})

    for &e, i in x.endpoints {
        tr.memory_open(&x.memory, &e, tr.Peer_Id(i + 1))
    }

    cfg := p.HUB_CONFIG
    cfg.content, cfg.rooms = 55, 2
    assert(
        p.hub_open(
            &x.provision,
            cfg,
            nil,
            db.commit,
            &x.store,
            {x, checkpoint_hub_clock},
            tr.memory_transport(&x.endpoints[0]),
        ) ==
        .None,
    )
    x.backend = {
        store = &x.store,
        model = f.model(),
    }
    assert(ck.hub_open(&x.hub, &x.provision, db.checkpoint_backend(&x.backend)) == .None)
}

checkpoint_hub_close :: proc(x: ^Checkpoint_Hub_Fixture) {
    for &c in x.clients {
        ck.client_close(&c)
    }

    for &c in x.rpcs {
        auth.rpc_client_destroy(&c)
    }

    ck.hub_close(&x.hub)
    p.hub_close(&x.provision)
    db.close(&x.store)

    for &e in x.endpoints {
        wire := tr.memory_transport(&e)
        tr.close(&wire)
    }

    tr.memory_destroy(&x.memory)
}

checkpoint_hub_create :: proc(x: ^Checkpoint_Hub_Fixture, room: u64) {
    bytes: [p.PACKET_BYTES]u8
    q := p.Request {
        version = p.PROTOCOL,
        verb = .Create,
        room = room,
        content = 55,
        claim = p.Secret{0 = u8(room)},
        endpoint = address(),
    }
    n := p.request_pack(&x.provision.codecs, q, bytes[:])
    assert(n > 0 && p.hub_receive(&x.provision, 2, bytes[:n]))
    assert(ck.hub_sync(&x.hub) == .None)
}

checkpoint_hub_step :: proc(x: ^Checkpoint_Hub_Fixture) {
    x.now += 10
    tr.memory_advance(&x.memory, x.now / 10)

    for &c in x.clients {
        if c.ready {
            ck.client_update(&c)
        }
    }

    assert(ck.hub_update(&x.hub) == .None)
    buffer: [tr.MAX_PACKET_BYTES]u8

    for i in 0 ..< 2 {
        wire := tr.memory_transport(&x.endpoints[i])

        for _ in 0 ..< 32 {
            packet := tr.receive(&wire, buffer[:])

            if packet.state != .Received {
                break
            }

            if i == 0 {
                ck.hub_receive(&x.hub, packet.from, buffer[:packet.count])
            } else {
                for &c in x.clients {
                    if c.ready && ck.client_receive(&c, packet.from, buffer[:packet.count]) {
                        break
                    }
                }
            }
        }
    }
}

@(test)
checkpoint_hub_mirrors_admitted_rooms_without_starting_coordinators_or_lazy_routing :: proc(t: ^testing.T) {
    path := fmt.aprintf("%s/checkpoint-hub-inventory.sqlite3", DIRECTORY)
    defer delete(path)
    x := new(Checkpoint_Hub_Fixture)
    defer free(x)
    checkpoint_hub_open(x, path)
    defer checkpoint_hub_close(x)
    testing.expect(t, len(x.hub.servers) == 2 && x.hub.servers[0] == nil && x.hub.servers[1] == nil)
    q := ck.Request {
        version = ck.VERSION,
        verb = .Status,
        room = 99,
        content = 55,
        sequence = 1,
        generation = 1,
        identity = {1, 1},
        nonce = {0 = 1},
    }
    bytes: [ck.PACKET_BYTES]u8
    n := ck.request_pack(&x.hub.codecs, q, auth.Key{0 = 1}, bytes[:])
    testing.expect(t, !ck.hub_receive(&x.hub, 2, bytes[:n]) && x.hub.servers[0] == nil && x.provision.rooms[0] == nil)
    checkpoint_hub_create(x, 44)
    before := x.provision.rooms[0].bundle.record
    first := x.hub.servers[0]
    testing.expect(
        t,
        first != nil && first.authority == &x.provision.rooms[0].service && before.coordinator_generation == 1,
    )
    testing.expect_value(t, ck.hub_sync(&x.hub), ck.Error.None)
    testing.expect(t, x.hub.servers[0] == first && x.provision.rooms[0].bundle.record == before)
    checkpoint_hub_create(x, 45)
    testing.expect(
        t,
        x.hub.servers[1] != nil && x.hub.servers[1] != first && x.provision.rooms[0].bundle.record == before,
    )
    x.provision.poisoned = true
    testing.expect_value(t, ck.hub_update(&x.hub), ck.Error.Storage)
    testing.expect(t, !ck.hub_receive(&x.hub, 2, bytes[:n]))
}

@(test)
two_checkpoint_rooms_publish_independently_on_one_registered_transport :: proc(t: ^testing.T) {
    path := fmt.aprintf("%s/checkpoint-hub-routing.sqlite3", DIRECTORY)
    defer delete(path)
    x := new(Checkpoint_Hub_Fixture)
    defer free(x)
    checkpoint_hub_open(x, path)
    defer checkpoint_hub_close(x)

    for i in 0 ..< 2 {
        room_id := u64(44 + i)
        checkpoint_hub_create(x, room_id)
        room := p.hub_room(&x.provision, room_id)
        assert(auth.coordinator_start(&room.service.coordinator, {1, 1}, 1, x.now) == .None)
        key := room.bundle.enrollments[0].key
        wire := tr.memory_transport(&x.endpoints[1])
        assert(auth.lease_init(&x.leases[i], {1, 1}, room_id, 55, {x, checkpoint_hub_clock}, true) == .None)
        assert(auth.rpc_client_init(&x.rpcs[i], &x.leases[i], key, auth.Nonce{0 = u8(room_id)}, wire))
        assert(auth.rpc_begin(&x.rpcs[i], {verb = .Query}) == .None)

        for _ in 0 ..< 30 {
            x.now += 10
            tr.memory_advance(&x.memory, x.now / 10)
            auth.rpc_client_pump(&x.rpcs[i])
            buffer: [tr.MAX_PACKET_BYTES]u8
            server_wire := x.provision.wire

            for _ in 0 ..< 32 {
                packet := tr.receive(&server_wire, buffer[:])

                if packet.state != .Received {
                    break
                }

                p.hub_control_receive(&x.provision, packet.from, buffer[:packet.count])
            }

            if !x.rpcs[i].pending {
                break
            }
        }

        assert(!x.rpcs[i].pending && x.rpcs[i].reply.result == .None)
        assert(ck.client_open(&x.clients[i], key, {x, checkpoint_hub_clock}, wire))
        game := new(f.Server)
        defer free(game)
        defer net.server_destroy(game)
        cfg := net.DEFAULT_CONFIG
        cfg.content, cfg.require_permit = 55, true
        assert(
            net.server_init(
                game,
                r.Frame(f.World){state = {value = u32(7 + i)}},
                f.model(),
                {},
                cfg,
                local_seat = 1,
                permit = auth.lease_permit(&x.leases[i]),
            ) ==
            .None,
        )
        assert(net.server_set_local_token(game, room.bundle.enrollments[0].token) == .None)
        net.server_local(game, 1)
        assert(net.server_step(game) == .None)
        prepared: auth.Prepared
        defer auth.prepared_destroy(&prepared)
        assert(auth.prepared_capture(&prepared, game, room_id, 7) == .None)
        q := ck.Request {
            version    = ck.VERSION,
            verb       = .Upload,
            room       = room_id,
            content    = 55,
            sequence   = 1,
            generation = room.bundle.record.coordinator_generation,
            identity   = {1, 1},
            nonce      = x.rpcs[i].nonce,
            contract   = game.contract,
            point      = prepared.point,
        }
        assert(ck.client_begin(&x.clients[i], q, prepared.bytes) == .None)
    }

    for _ in 0 ..< 150 {
        checkpoint_hub_step(x)

        if x.clients[0].phase == .Complete && x.clients[1].phase == .Complete {
            break
        }
    }

    for &client, i in x.clients {
        testing.expect(t, client.phase == .Complete && client.reply.publication.point.scope.room == u64(44 + i))
        saved, found, error := db.checkpoint_load(&x.store, u64(44 + i), 55, f.model())
        defer db.stored_checkpoint_destroy(&saved)
        testing.expect(t, found && error == .None && saved.publication.revision == 1)
        cp: net.Checkpoint(f.World, u8, u8, 1)
        defer net.checkpoint_destroy(&cp)
        testing.expect_value(t, net.checkpoint_decode(&cp, saved.bytes, f.model(), 55), net.Error.None)
        testing.expect_value(t, cp.frame.state.value, u32(8 + i))
    }
}
