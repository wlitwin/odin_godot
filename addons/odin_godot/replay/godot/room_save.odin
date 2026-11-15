package replay_godot

import auth "godot:replay/authority"
import ck "godot:replay/provision/checkpoint"
import net "godot:replay/net"
import tr "godot:replay/transport"

Room_Save_Phase :: enum u8 {
    Idle,
    Checking,
    Uploading,
    Saved,
    Interrupted,
    Failed,
}

Room_Save :: struct {
    phase:                                     Room_Save_Phase,
    error:                                     ck.Error,
    publication:                               ck.Publication, // last authenticated durable publication observed
    serial, attempts, completed, last_started: u64,
    uncertain:                                 bool, // an interrupted upload may already have committed
    status_checked:                            bool,
    capture_after:                             u64,
    client:                                    ck.Client,
    prepared:                                  auth.Prepared,
}

@(private)
room_save_destroy :: proc(s: ^Room_Save) {
    ck.client_close(&s.client)
    auth.prepared_destroy(&s.prepared)
    s^ = {}
}

@(private)
room_save_interrupt :: proc(s: ^Room_Save) {
    if s.phase == .Checking || s.phase == .Uploading {
        s.uncertain = s.uncertain || s.phase == .Uploading
        s.phase, s.error = .Interrupted, .Stale
    }

    ck.client_close(&s.client)
}

@(private)
room_save_allowed :: proc(room: ^Room($S, $C, $A, $E, $N)) -> bool {
    return(
        room.ready &&
        room.registered &&
        room.phase == .Hosting &&
        !room.handoff_requested &&
        !room.control_paused &&
        room.options.control_backend == .Websocket &&
        room.session.ready &&
        room.session.authority &&
        provision_url_valid(room.options.coordinator, room.options.checkpoint_local_development) &&
        room.session.server.initialized &&
        auth.lease_live(&room.lease, room.session.server.cfg.epoch) \
    )
}

// Request an asynchronous durable checkpoint. Gameplay, lease renewal and live
// successor backups continue. A successful call means started, not saved.
room_save :: proc(room: ^Room($S, $C, $A, $E, $N)) -> ck.Error {
    if !room_save_allowed(room) {
        return .Denied
    }

    s := &room.save

    if s.phase == .Checking || s.phase == .Uploading {
        return .Busy
    }

    if s.serial == max(u64) {
        return .Capacity
    }

    if !room.checkpoint_codec.ready &&
       net.checkpoint_codec_init(&room.checkpoint_codec, S, C, A, E, N, allocator = room.allocator) != .None {
        return .Schema
    }

    now, ok := room.clock.read(room.clock.user)

    if !ok {
        return .Clock
    }

    ck.client_close(&s.client)

    if !ck.client_open(&s.client, room.rpc.key, room.clock, room.control_wire, allocator = room.allocator) {
        return .Invalid
    }

    s.serial += 1
    q := ck.Request {
        version    = ck.VERSION,
        verb       = .Status,
        room       = room.options.room,
        content    = room.session.server.cfg.content,
        sequence   = s.serial,
        generation = room.lease.view.coordinator_generation,
        identity   = room.lease.identity,
        nonce      = room.rpc.nonce,
        contract   = room.session.server.contract,
    }

    if error := ck.client_begin(&s.client, q); error != .None {
        ck.client_close(&s.client)
        return error
    }

    s.phase, s.error, s.last_started = .Checking, .None, now
    s.attempts += 1
    s.status_checked = false
    return .None
}

// The single owner of control reads dispatches both protocols. The borrowed RPC
// transport copy cannot consume checkpoint packets a second time.
room_control_pump :: proc(room: ^Room($S, $C, $A, $E, $N)) -> auth.Error {
    tr.poll(&room.control_wire)

    for _ in 0 ..< 32 {
        packet := tr.receive(&room.control_wire, room.rpc.rxb[:])

        if packet.state == .Empty || packet.state == .Disconnected {
            break
        }

        if packet.state != .Received {
            room.rpc.stats.rejected += 1
            continue
        }

        if !ck.client_receive(&room.restore.client, packet.from, room.rpc.rxb[:packet.count]) &&
           !ck.client_receive(&room.save.client, packet.from, room.rpc.rxb[:packet.count]) {
            auth.rpc_client_receive(&room.rpc, packet.from, room.rpc.rxb[:packet.count])
        }
    }

    original := room.rpc.wire

    defer {
        room.rpc.wire = original
    }

    room.rpc.wire.receive, room.rpc.wire.poll = nil, nil
    return auth.rpc_client_pump(&room.rpc)
}

@(private)
room_save_fail :: proc(s: ^Room_Save, error: ck.Error) {
    s.uncertain = s.uncertain || s.phase == .Uploading
    s.phase, s.error = .Failed, error
    ck.client_close(&s.client)
}

@(private)
room_save_finished :: proc(s: ^Room_Save, publication: ck.Publication) {
    s.publication, s.phase, s.error, s.uncertain = publication, .Saved, .None, false
    s.completed += 1
    auth.prepared_destroy(&s.prepared)
    ck.client_close(&s.client)
}

room_save_frame :: proc(room: ^Room($S, $C, $A, $E, $N), now: u64) {
    s := &room.save

    if !room_save_allowed(room) {
        room_save_interrupt(s)
        return
    }

    if s.phase != .Checking && s.phase != .Uploading {
        interval := room.options.checkpoint_interval_ms

        if interval != 0 && now >= s.last_started && now - s.last_started >= interval {
            room_save(room)
        }

        return
    }

    q := s.client.lane.request

    if q.identity != room.lease.identity ||
       q.nonce != room.rpc.nonce ||
       q.generation != room.lease.view.coordinator_generation ||
       (s.phase == .Uploading && q.point.scope.epoch != room.session.server.cfg.epoch) {
        room_save_interrupt(s)
        return
    }

    error := ck.client_update(&s.client)
    missing :=
        s.phase == .Checking && s.client.phase == .Failed && s.client.error == .Missing && s.client.reply.request == q

    if !missing && (error != .None || s.client.phase == .Failed) {
        room_save_fail(s, s.client.error)
        return
    }

    if s.phase == .Checking && (missing || s.client.phase == .Complete) {
        publication := missing ? ck.Publication{} : s.client.reply.publication
        s.publication = publication

        if !missing &&
           s.prepared.ready &&
           publication.publisher == room.lease.identity &&
           publication.point == s.prepared.point {
            room_save_finished(s, publication)
            return
        }

        if !s.status_checked {
            s.status_checked = true
            s.capture_after = room.lease.sequence
        }

        refreshed := false

        if reply, complete := auth.rpc_completed(&room.rpc);
           complete &&
           reply.result == .None &&
           room.rpc.request.sequence > s.capture_after &&
           room.rpc.request.command.verb == .Renew &&
           reply.view.epoch == room.session.server.cfg.epoch &&
           reply.view.owner == room.lease.identity {
            refreshed = true
        }

        if !refreshed {
            if !room.rpc.pending && !room.lease.pending {
                room.control_error = auth.rpc_begin(
                    &room.rpc,
                    {verb = .Renew, epoch = room.session.server.cfg.epoch, tick = room.session.server.timeline.head},
                )
                room.last_control = now
            }

            return
        }

        // A current save can supersede an unacknowledged older attempt. Preserve
        // only the authenticated latest receipt, then capture the current world.
        auth.prepared_destroy(&s.prepared)

        if s.serial == max(u64) ||
           publication.revision == max(u64) ||
           (publication.point.scope.epoch == room.session.server.cfg.epoch &&
                   publication.point.archive.sequence == max(u64)) {
            room_save_fail(s, .Capacity)
            return
        }

        if auth.prepared_capture(
               &s.prepared,
               &room.session.server,
               room.options.room,
               room.lease.identity.incarnation,
               codec = &room.checkpoint_codec,
           ) !=
           .None {
            room_save_fail(s, .Schema)
            return
        }

        if publication.point.scope.epoch == room.session.server.cfg.epoch {
            s.prepared.point.archive.sequence = publication.point.archive.sequence + 1
        }

        s.serial += 1
        q.verb, q.sequence, q.revision, q.point = .Upload, s.serial, publication.revision, s.prepared.point
        payload, packaged := ck.package_encode(
            s.prepared.bytes,
            s.prepared.point,
            room.options.checkpoint_cache,
            room.options.checkpoint_assets,
            room.allocator,
            codec = &room.checkpoint_codec,
        )
        defer delete(payload, room.allocator)

        if packaged != .None {
            room_save_fail(s, packaged)
            return
        }

        bytes := s.prepared.bytes

        if len(payload) > 0 {
            q.payload = ck.payload_for(q.point, payload)
            bytes = payload
        }

        if e := ck.client_begin(&s.client, q, bytes); e != .None {
            room_save_fail(s, e)
            return
        }

        s.phase, s.error, s.uncertain = .Uploading, .None, false
    } else if s.phase == .Uploading && s.client.phase == .Complete {
        room_save_finished(s, s.client.reply.publication)
    }
}
