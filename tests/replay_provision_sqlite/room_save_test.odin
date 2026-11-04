package replay_provision_sqlite_test

import "core:fmt"
import "core:testing"
import auth "godot:replay/authority"
import ck "godot:replay/provision/checkpoint"
import db "godot:replay/provision/sqlite"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import f "publication_fixture"

Save_Room :: rgd.Room(f.World, u8, u8, u8, 1)

Save_Gate :: struct {
    base:    tr.Transport,
    server:  ^ck.Server,
    block:   bool,
    dropped: u64,
}

save_gate_send :: proc(user: rawptr, to: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> tr.Send_Result {
    g := cast(^Save_Gate)user

    if g.block && g.server.published > 0 && len(bytes) > 32 {
        meta, _, report := sc.inspect(bytes[:len(bytes) - 32])

        if report.error == .None && (meta.kind == ck.REPLY_KIND || meta.kind == ck.DOWNSTREAM_KIND) {
            g.dropped += 1
            return .Sent
        }
    }

    return tr.send(&g.base, to, channel, bytes)
}

save_gate_wire :: proc(g: ^Save_Gate) -> tr.Transport {
    return {user = g, send = save_gate_send, connected = proc(user: rawptr, peer: tr.Peer_Id) -> bool {
            return tr.peer_connected(&(cast(^Save_Gate)user).base, peer)
        }, generation = proc(user: rawptr, peer: tr.Peer_Id) -> u64 {
            return tr.peer_generation(&(cast(^Save_Gate)user).base, peer)
        }}
}

save_room_open :: proc(room: ^Save_Room, x: ^Protocol_Fixture) {
    room.allocator = context.allocator
    room.ready, room.registered, room.phase = true, true, .Hosting
    room.options = {
        room            = 44,
        identity        = {1, 1},
        control_backend = .Websocket,
        coordinator     = "wss://fixture.invalid",
    }
    room.clock = {x, protocol_clock}
    room.control_wire = tr.memory_transport(&x.endpoints[1])
    room.model = f.model()
    room.lease = x.lease
    room.rpc = x.rpc
    x.rpc = {}
    room.rpc.lease = &room.lease
    room.session.ready, room.session.authority = true, true
    room.session.server = x.base.server
    x.base.server = {}
}

save_room_close :: proc(room: ^Save_Room) {
    net.checkpoint_codec_destroy(&room.checkpoint_codec)
    // Only the transport-independent owners were initialized by this fixture.
    ck.client_close(&room.save.client)
    auth.prepared_destroy(&room.save.prepared)
    auth.rpc_client_destroy(&room.rpc)
    net.server_destroy(&room.session.server)
}

save_room_step :: proc(room: ^Save_Room, x: ^Protocol_Fixture) {
    x.now += 10
    tr.memory_advance(&x.memory, x.now / 10)
    assert(rgd.room_control_pump(room) == .None)
    rgd.room_save_frame(room, x.now)
    ck.server_update(&x.server)
    buffer: [tr.MAX_PACKET_BYTES]u8
    wire := tr.memory_transport(&x.endpoints[0])

    for _ in 0 ..< 32 {
        packet := tr.receive(&wire, buffer[:])

        if packet.state != .Received {
            break
        }

        if !ck.server_receive(&x.server, packet.from, buffer[:packet.count]) {
            auth.service_receive(&x.base.room.service, packet.from, buffer[:packet.count])
        }
    }
}

@(test)
room_save_resolves_lost_commit_reply_without_republishing_or_losing_rpc_reads :: proc(t: ^testing.T) {
    path := fmt.aprintf("%s/room-save-lost-reply.sqlite3", DIRECTORY)
    defer delete(path)
    x := new(Protocol_Fixture)
    defer free(x)
    protocol_open(x, path)
    defer protocol_close(x)
    room := new(Save_Room)
    defer free(room)
    save_room_open(room, x)
    defer save_room_close(room)
    gate := Save_Gate{tr.memory_transport(&x.endpoints[0]), &x.server, true, 0}
    x.server.wire = save_gate_wire(&gate)
    testing.expect_value(t, rgd.room_save(room), ck.Error.None)
    assert(auth.rpc_begin(&room.rpc, {verb = .Renew, epoch = 1, tick = 0}) == .None)

    for _ in 0 ..< 100 {
        save_room_step(room, x)

        if gate.dropped > 0 && !room.rpc.pending {
            break
        }
    }

    testing.expect(
        t,
        x.server.published == 1 && gate.dropped > 0 && room.save.phase == .Uploading && room.save.prepared.ready,
    )
    testing.expect(t, !room.rpc.pending && room.rpc.reply.result == .None && room.rpc.wire.receive != nil)
    point := room.save.prepared.point
    room.control_paused = true
    rgd.room_save_frame(room, x.now)
    testing.expect(t, room.save.phase == .Interrupted && room.save.uncertain && room.save.prepared.point == point)
    // The reply and server's volatile transfer state are gone; the database is
    // the only durable evidence of the successful publication.
    ck.server_close(&x.server)
    assert(ck.server_open(&x.server, &x.base.room.service, db.checkpoint_backend(&x.backend), gate.base))
    room.control_paused = false
    assert(rgd.room_save(room) == .None)

    for _ in 0 ..< 100 {
        save_room_step(room, x)

        if room.save.phase == .Saved {
            break
        }
    }

    testing.expect(
        t,
        room.save.phase == .Saved &&
        !room.save.uncertain &&
        room.save.publication.revision == 1 &&
        room.save.publication.point == point &&
        room.save.completed == 1,
    )
    testing.expect(t, x.server.published == 0 && !room.save.prepared.ready)
}

@(test)
room_save_fences_role_changes_and_plain_remote_websocket_before_publication :: proc(t: ^testing.T) {
    path := fmt.aprintf("%s/room-save-fenced.sqlite3", DIRECTORY)
    defer delete(path)
    x := new(Protocol_Fixture)
    defer free(x)
    protocol_open(x, path)
    defer protocol_close(x)
    room := new(Save_Room)
    defer free(room)
    save_room_open(room, x)
    defer save_room_close(room)
    room.options.coordinator = "ws://example.com"
    testing.expect_value(t, rgd.room_save(room), ck.Error.Denied)
    room.options.coordinator = "ws://127.0.0.1:1234"
    testing.expect_value(t, rgd.room_save(room), ck.Error.Denied)
    room.options.checkpoint_local_development = true
    assert(rgd.room_save(room) == .None)

    for _ in 0 ..< 100 {
        save_room_step(room, x)

        if room.save.phase == .Uploading {
            break
        }
    }

    testing.expect(t, room.save.phase == .Uploading && room.save.prepared.ready)
    room.phase = .Following
    rgd.room_save_frame(room, x.now)
    testing.expect(t, room.save.phase == .Interrupted && !room.save.client.ready)
    testing.expect_value(t, rgd.room_save(room), ck.Error.Denied)
    saved, found, error := db.checkpoint_load(&x.base.store, 44, 55, f.model())
    defer db.stored_checkpoint_destroy(&saved)
    testing.expect(t, !found && error == .None)
}
