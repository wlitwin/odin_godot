package replay_provision_sqlite_test

import "core:fmt"
import "core:testing"
import auth "godot:replay/authority"
import ck "godot:replay/provision/checkpoint"
import db "godot:replay/provision/sqlite"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import f "publication_fixture"

@(test)
delayed_restore_grant_renews_before_install_without_another_takeover :: proc(t: ^testing.T) {
    path := fmt.aprintf("%s/delayed-restore-renew.sqlite3", DIRECTORY)
    defer delete(path)
    x := new(Protocol_Fixture)
    defer free(x)
    protocol_open(x, path)
    defer protocol_close(x)
    point, bytes := f.checkpoint(&x.base, 1)
    defer delete(bytes)
    _, error := db.checkpoint_publish(&x.base.store, x.base.room.bundle.record, 0, point, bytes, f.model())
    assert(error == .None)
    x.now = 2500
    restore_fresh_owner(x)
    room := new(Save_Room)
    defer free(room)
    restore_room_open(room, x)
    defer restore_room_close(room)

    for _ in 0 ..< 100 {
        restore_room_step(room, x)

        if room.restore.phase == .Requesting {
            break
        }
    }

    testing.expect_value(t, room.restore.phase, rgd.Room_Restore_Phase.Requesting)
    // Delay delivery before the coordinator commits its grant. Local lease time
    // is anchored to request start, so that reply arrives already locally expired
    // while the coordinator still has an active reservation for this same actor.
    x.now += 2400

    for _ in 0 ..< 20 {
        restore_room_step(room, x)

        if room.restore.phase == .Granted {
            break
        }
    }

    testing.expect_value(t, room.restore.phase, rgd.Room_Restore_Phase.Granted)
    testing.expect_value(t, x.base.room.bundle.record.epoch, u64(2))
    testing.expect(t, !auth.lease_live(&room.lease, 2) && room.lease.view.remaining_ms > 0)
    testing.expect(t, room.restore.prepared.ready && !room.session.ready)
    before := room.restore.prepared.point
    testing.expect_value(t, rgd.room_frame(room, 0, 0), net.Error.None)
    testing.expect_value(t, room.rpc.request.command.verb, auth.Verb.Renew)
    testing.expect_value(t, room.rpc.request.command.epoch, u64(2))

    for _ in 0 ..< 30 {
        restore_room_step(room, x)

        if room.restore.renewed_epoch == 2 {
            break
        }
    }

    fmt.printf(
        "RESTORE_GRANT_REFRESH epoch=%d renewed=%d live=%v phase=%v\n",
        x.base.room.bundle.record.epoch,
        room.restore.renewed_epoch,
        auth.lease_live(&room.lease, 2),
        room.restore.phase,
    )
    testing.expect_value(t, room.restore.renewed_epoch, u64(2))
    testing.expect(t, auth.lease_live(&room.lease, 2) && room.restore.prepared.point == before && !room.session.ready)
    testing.expect_value(t, x.base.room.bundle.record.epoch, u64(2))
}

@(test)
expired_coordinator_reservation_cannot_be_revived_by_a_renewal_request :: proc(t: ^testing.T) {
    path := fmt.aprintf("%s/expired-restore-renew.sqlite3", DIRECTORY)
    defer delete(path)
    x := new(Protocol_Fixture)
    defer free(x)
    protocol_open(x, path)
    defer protocol_close(x)
    point, bytes := f.checkpoint(&x.base, 1)
    defer delete(bytes)
    _, error := db.checkpoint_publish(&x.base.store, x.base.room.bundle.record, 0, point, bytes, f.model())
    assert(error == .None)
    x.now = 2500
    restore_fresh_owner(x)
    room := new(Save_Room)
    defer free(room)
    restore_room_open(room, x)
    defer restore_room_close(room)

    for _ in 0 ..< 100 {
        restore_room_step(room, x)

        if room.restore.phase == .Requesting {
            break
        }
    }

    testing.expect_value(t, room.restore.phase, rgd.Room_Restore_Phase.Requesting)
    // Delay delivery before the coordinator commits its grant. Local lease time
    // is anchored to request start, so that reply arrives already locally expired
    // while the coordinator still has an active reservation for this same actor.
    x.now += 2400

    for _ in 0 ..< 20 {
        restore_room_step(room, x)

        if room.restore.phase == .Granted {
            break
        }
    }

    testing.expect_value(t, room.restore.phase, rgd.Room_Restore_Phase.Granted)
    testing.expect_value(t, x.base.room.bundle.record.epoch, u64(2))
    testing.expect(t, !auth.lease_live(&room.lease, 2) && room.lease.view.remaining_ms > 0)
    testing.expect(t, room.restore.prepared.ready && !room.session.ready)
    before := room.restore.prepared.point
    x.now += u64(room.lease.view.policy.lease_ms) + 1 // Coordinator reservation has also expired.
    testing.expect_value(t, rgd.room_frame(room, 0, 0), net.Error.None)
    testing.expect_value(t, room.rpc.request.command.verb, auth.Verb.Renew)
    testing.expect_value(t, room.rpc.request.command.epoch, u64(2))

    for _ in 0 ..< 30 {
        restore_room_step(room, x)

        if reply, complete := auth.rpc_completed(&room.rpc);
           complete && room.rpc.request.command.verb == .Renew && reply.result != .None {
            break
        }
    }

    reply, complete := auth.rpc_completed(&room.rpc)
    testing.expect(t, complete && room.rpc.request.command.verb == .Renew && reply.result != .None)
    testing.expect_value(t, room.restore.renewed_epoch, u64(0))
    testing.expect(t, !auth.lease_live(&room.lease, 2) && room.restore.prepared.point == before && !room.session.ready)
    testing.expect_value(t, x.base.room.bundle.record.epoch, u64(2))
    fmt.printf(
        "RESTORE_GRANT_REFUSED result=%v live=%v renewed=%d\n",
        reply.result,
        auth.lease_live(&room.lease, 2),
        room.restore.renewed_epoch,
    )
}
