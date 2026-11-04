package replay_godot

import "core:fmt"
import "core:mem"
import "core:strings"
import gd "godot:godot"
import meter "godot:box3d/godot/meter"
import r "godot:replay"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import auth "godot:replay/authority"
import tr "godot:replay/transport"
import ck "godot:replay/provision/checkpoint"
import a "godot:replay/assets"
import storagegd "godot:replay/godot/storage"
import transportgd "godot:replay/godot/transport"

Room_Control :: enum {
    Enet,
    Websocket,
}

Room_Phase :: enum {
    Connecting,
    Following,
    Hosting,
    Freezing,
    Releasing,
    Claiming,
    Recovering,
    Failed,
}

Room_Recovery :: struct {
    from_epoch, to_epoch, checkpoint_tick, previous_confirmed, known_lost_ticks: u64,
    interruption_ms, archive_bytes:                                              u64,
    install_us:                                                                  u64, // elapsed wall time of the successful authority-runtime replacement
    ready:                                                                       bool,
    from_publication:                                                            bool,
    service_known_tick:                                                          u64,
}

Room_Options :: struct {
    identity:                     auth.Identity,
    key:                          auth.Key,
    room:                         u64,
    coordinator:                  string,
    control_port:                 u16,
    control_backend:              Room_Control,
    control_tls:                  gd.Tls_Options, // optional verified native CA; retained while Room is open
    bootstrap:                    bool,
    provisioned_incarnation:      bool, // true only when a trusted provider already assigned this process identity
    registration_endpoint:        auth.Endpoint, // empty retains the provisioned endpoint
    successor:                    auth.Identity,
    successor_seat:               u16, // optional playable-seat constraint; zero resolves by authenticated identity
    automatic_successor:          bool, // select a connected trusted member from the authenticated roster
    session:                      Session_Options,
    preparation_user:             rawptr,
    preparation_ready:            proc(user: rawptr, point: auth.Point, bytes: []u8) -> bool,
    checkpoint_interval_ms:       u64, // zero disables automatic durable publication
    checkpoint_local_development: bool, // explicit literal-loopback WS opt-in
    restore_published:            bool, // fresh Room may recover a durable world after authority expires
    checkpoint_assets:            ck.Asset_Policy,
    checkpoint_cache:             ^a.Cache, // borrowed; must outlive Room
}

// Coordinator-driven lifecycle. It owns the control connection, lease, prepared
// archives and gameplay Session. Its model stays identical across role changes.
Room :: struct($S, $C, $A, $E: typeid, $N: int) {
    allocator:                                 mem.Allocator,
    ready:                                     bool,
    registered:                                bool,
    removed:                                   bool,
    removal:                                   Room_Removal,
    members:                                   [auth.MAX_MEMBERS]auth.Member,
    last_roster:                               u64,
    backup_observation:                        Room_Backup_Observation,
    last_command:                              auth.Verb,
    last_result:                               auth.Error,
    claim_rejections, busy_claims:             u64,
    options:                                   Room_Options,
    phase:                                     Room_Phase,
    error:                                     net.Error,
    control_error:                             auth.Error,
    clock:                                     auth.Clock_Source,
    browser_clock:                             Browser_Lease_Clock,
    rtc_authorization:                         transportgd.Rtc_Grant_Auth,
    lease:                                     auth.Lease,
    rpc:                                       auth.Rpc_Client,
    control:                                   transportgd.Enet,
    control_websocket:                         transportgd.Websocket,
    control_wire:                              tr.Transport,
    model:                                     net.Model(S, C, A, E, N),
    initial:                                   r.Frame(S),
    session:                                   Session(S, C, A, E, N),
    prepared, candidate:                       auth.Prepared,
    retired:                                   auth.Retirement,
    last_control, last_reconnect, frozen_tick: u64,
    last_game_reconnect:                       u64,
    active_epoch, migrations:                  u64,
    interruption_start:                        u64,
    recovery:                                  Room_Recovery,
    handoff_requested:                         bool,
    control_paused:                            bool, // explicit fault/embedding control; gameplay leases still expire normally
    save:                                      Room_Save,
    restore:                                   Room_Restore,
    checkpoint_codec:                          net.Checkpoint_Codec,
    ownership:                                 Room_Ownership,
    retained:                                  r.Owner_Retains,
    aliases:                                   [2]r.Owned_Context,
    initial_complete:                          r.Complete_Checkpoint(S, net.Net_Event(E)),
    complete_initial, codec_retained, cleanup: bool,
    rpc_meter:                                 ^meter.Context,
    rpc_allocator:                             mem.Allocator,
}

room_open :: proc(
    room: ^Room($S, $C, $A, $E, $N),
    initial: r.Frame(S),
    model: net.Model(S, C, A, E, N),
    options: Room_Options,
) -> net.Error {
    if session_sdk_physics(model) && (!room_managed(room) || !room.complete_initial) {
        return .Invalid_Config
    }

    if options.control_backend > .Websocket ||
       room.ready ||
       options.room == 0 ||
       (options.control_backend == .Enet && options.control_port == 0) ||
       len(options.coordinator) == 0 ||
       !auth.identity_valid(options.identity) {
        return .Invalid_Config
    }

    if options.session.backend == .Rtc &&
       (options.control_backend != .Websocket || len(options.session.rtc.url) == 0) {
        return .Invalid_Config
    }

    if options.checkpoint_interval_ms != 0 &&
       (options.control_backend != .Websocket ||
               options.checkpoint_interval_ms < 1000 ||
               options.checkpoint_interval_ms > 120000) {
        return .Invalid_Config
    }

    if options.checkpoint_interval_ms != 0 &&
       !provision_url_valid(options.coordinator, options.checkpoint_local_development) {
        return .Invalid_Config
    }

    if options.restore_published &&
       (options.control_backend != .Websocket ||
               !provision_url_valid(options.coordinator, options.checkpoint_local_development)) {
        return .Invalid_Config
    }

    when gd.IS_WEB {
        if options.session.backend != .Rtc {
            return .Invalid_Config
        }
    }

    options := options

    if options.session.backend == .Steam {
        when gd.IS_WEB {
            return .Invalid_Config
        }

        config := options.session.steam

        if config.runtime == nil ||
           !config.runtime.ready ||
           config.runtime.steam_id == 0 ||
           config.peer != nil ||
           config.max_peers < 1 ||
           config.max_peers > 4095 {
            return .Invalid_Config
        }

        endpoint, valid := transportgd.steam_endpoint(config.runtime.steam_id, config.virtual_port)

        if !valid {
            return .Invalid_Config
        }

        if options.registration_endpoint != (auth.Endpoint{}) && options.registration_endpoint != endpoint {
            return .Invalid_Config
        }

        options.registration_endpoint = endpoint
    }

    if !room_managed(room) {
        room.allocator = context.allocator
    }

    context.allocator = room.allocator
    room.options = options

    if options.control_tls != nil {
        gd.ref_counted_reference(options.control_tls)
    }

    room.initial = initial
    room.model = model
    room.options.coordinator = strings.clone(options.coordinator, room.allocator)
    room.options.session.address = nil
    room.options.session.rtc.url = strings.clone(options.session.rtc.url, room.allocator)
    room.options.session.rtc.ice_json = strings.clone(options.session.rtc.ice_json, room.allocator)
    room.options.session.rtc.room = ""

    if options.restore_published || options.checkpoint_interval_ms != 0 || options.checkpoint_assets.collect != nil {
        if net.checkpoint_codec_init(&room.checkpoint_codec, S, C, A, E, N, allocator = room.allocator) != .None {
            room_close(room)
            return .Invalid_Schema
        }
    }

    when gd.IS_WEB {
        room.clock = browser_lease_clock(&room.browser_clock)
    } else {
        room.clock = auth.native_clock()
    }

    if error := auth.lease_init(
        &room.lease,
        options.identity,
        options.room,
        options.session.network.content,
        room.clock,
        false,
    ); error != .None {
        gd.print_str(fmt.tprintf("REPLAY_ROOM_OPEN_FAIL stage=lease error=%v", error))
        room_close(room)
        return .Invalid_Config
    }

    if !room_control_connect(room) {
        room_close(room)
        return .Transport
    }

    nonce: auth.Nonce
    ok := true

    when gd.IS_WEB {
        nonce = auth.Nonce(storagegd.session_token())
    } else {
        nonce, ok = auth.rpc_nonce()
    }

    if !ok ||
       !auth.rpc_client_init(
               &room.rpc,
               &room.lease,
               options.key,
               nonce,
               room.control_wire,
               allocator = room_managed(room) ? room.rpc_allocator : room.allocator,
           ) {
        gd.print_str(
            fmt.tprintf(
                "REPLAY_ROOM_OPEN_FAIL stage=rpc entropy_ok=%v nonce_present=%v key_present=%v lease_ready=%v",
                ok,
                nonce != (auth.Nonce{}),
                options.key != (auth.Key{}),
                room.lease.ready,
            ),
        )
        room_close(room)
        return .Invalid_Config
    }

    room.ready, room.phase = true, .Connecting
    room.registered = options.provisioned_incarnation

    if room.registered {
        room.options.session.incarnation = options.identity.incarnation
    }

    return .None
}

room_close :: proc(room: ^Room($S, $C, $A, $E, $N)) {
    if room_managed(room) {
        _ = room_try_close(room)
        return
    }

    room_close_legacy(room)
}

@(private)
room_close_legacy :: proc(room: ^Room($S, $C, $A, $E, $N)) {
    net.checkpoint_codec_destroy(&room.checkpoint_codec)
    room_restore_destroy(&room.restore)
    room_save_destroy(&room.save)
    session_close(&room.session)
    auth.rpc_client_destroy(&room.rpc)
    auth.prepared_destroy(&room.prepared)
    auth.prepared_destroy(&room.candidate)
    tr.close(&room.control_wire)

    if room.options.control_tls != nil {
        gd.release_ref(room.options.control_tls)
    }

    delete(room.options.coordinator, room.allocator)
    delete(room.options.session.rtc.url, room.allocator)
    delete(room.options.session.rtc.ice_json, room.allocator)
    room^ = {}
}

room_handoff :: proc(room: ^Room($S, $C, $A, $E, $N)) -> net.Error {
    if !room.ready ||
       room.removal.phase == .Queued ||
       room.removal.phase == .Waiting ||
       room.phase != .Hosting ||
       !session_link(&room.session)^.outgoing.ready {
        return .Wrong_Phase
    }

    _, live := net.server_connection(&room.session.server, session_link(&room.session)^.outgoing.target)

    if !live {
        return .Invalid_Input
    }

    room.handoff_requested = true
    return .None
}

room_issue :: proc(room: ^Room($S, $C, $A, $E, $N), action: A) -> (u64, net.Error) {
    if !room.ready || room.handoff_requested || (room.phase != .Hosting && room.phase != .Following) {
        return 0, .Fenced
    }

    return session_issue(&room.session, action)
}

room_frame :: proc(room: ^Room($S, $C, $A, $E, $N), dt: f64, control: C) -> net.Error {
    room.session.control_consumed = false

    if !room.ready {
        return .Not_Initialized
    }

    if room_managed(room) && r.owner_retains_access(&room.retained, .Execute) != .None {
        return .Invalid_Model
    }

    context.allocator = room.allocator

    if room.phase == .Failed {
        return room.error
    }

    now, ok := room.clock.read(room.clock.user)

    if !ok {
        room_fail(room, .Fenced)
        return room.error
    }

    if tr.status(&room.control_wire) == .Disconnected && now - room.last_reconnect >= 300 {
        room_save_interrupt(&room.save)
        room_restore_interrupt(&room.restore)
        tr.close(&room.control_wire)

        if room_control_connect(room) {
            room.rpc.wire = room.control_wire
        }

        room.last_reconnect = now
    }

    if !room.control_paused {
        if err := room_control_pump(room); err != .None && err != .Busy {
            room.control_error = err
        }
    }

    if reply, complete := auth.rpc_completed(&room.rpc); complete && reply.sequence != room.last_roster {
        room.members, room.last_roster = reply.members, reply.sequence
        room.backup_observation = {
            view        = reply.view,
            nominee     = reply.nominee,
            binding     = reply.binding,
            point       = reply.point,
            prepared    = reply.prepared,
            observed_at = room.lease.now,
            ready       = true,
        }
        room.last_command, room.last_result = room.rpc.request.command.verb, reply.result

        if room.phase == .Claiming && room.last_command == .Claim && reply.result != .None {
            // A failed attempt did not grant authority. Resume preparation so a
            // Busy/Stale/Too_Old response cannot pin an obsolete recovery point.
            room.phase = .Following
            room.claim_rejections += 1

            if reply.result == .Busy {
                room.busy_claims += 1
            }
        }
    }

    room_removal_observe(room)
    room_moderation_roster(room)

    if room.removed {
        return .None
    }

    if !room.registered {
        reply, complete := auth.rpc_completed(&room.rpc)

        if complete && room.rpc.request.command.verb == .Rebind && reply.result == .None {
            room.registered = true
            room.options.identity = room.lease.identity
            room.options.session.incarnation = room.lease.identity.incarnation
        } else {
            if !room.rpc.pending && now - room.last_control >= 150 {
                command := auth.Command {
                    verb     = .Challenge,
                    endpoint = room.options.registration_endpoint,
                }

                if complete && room.rpc.request.command.verb == .Challenge && reply.result == .None {
                    command = {
                        verb        = .Rebind,
                        challenge   = reply.challenge,
                        incarnation = reply.registration_identity.incarnation,
                        endpoint    = room.options.registration_endpoint,
                    }
                }

                room.control_error = auth.rpc_begin(&room.rpc, command)
                room.last_control = now
            }

            return .None
        }
    }

    if room.rpc.reply.prepared && room.candidate.ready && room.rpc.reply.point == room.candidate.point {
        auth.prepared_destroy(&room.prepared)
        room.prepared, room.candidate = room.candidate, {} // ownership transfer
    }

    room_restore_frame(room, now)
    grant := room.lease.view
    target := room_transport(room, grant)
    current :=
        room.session.ready ? (room.session.authority ? room.session.server.cfg.epoch : room.session.client.cfg.epoch) : 0
    previous_confirmed :=
        room.session.ready ? (room.session.authority ? room.session.server.timeline.confirmed : room.session.client.timeline.confirmed) : 0

    if current != 0 && room.session.fenced && room.interruption_start == 0 {
        room.interruption_start = now
    }

    if grant.epoch != 0 && grant.remaining_ms != 0 {
        if grant.owner == room.options.identity {
            room.lease.require_owner = true

            if auth.lease_live(&room.lease, grant.epoch) && grant.epoch > current {
                if room.candidate.ready && room.candidate.point == grant.recovered {
                    auth.prepared_destroy(&room.prepared)
                    room.prepared, room.candidate = room.candidate, {}
                }

                options := room.options.session

                if err := migration_transport(&options, &room.lease, &target); err != .None {
                    room_fail(room, err)
                    return err
                }

                options.network.epoch, options.network.require_permit, options.permit =
                    grant.epoch, true, room_permit(room)
                options.role, options.port, options.replication.room =
                    room.options.session.role == .Server ? .Server : .Host, grant.endpoint.port, room.options.room

                if !room.session.ready && grant.epoch == 1 && room.options.bootstrap {
                    if err := room_session_open(room, options); err != .None {
                        room_fail(room, err)
                        return err
                    }
                } else if !room.session.ready &&
                   room.restore.prepared.ready &&
                   room.restore.prepared.point == grant.recovered &&
                   room.restore.phase == .Granted &&
                   room.restore.renewed_epoch == grant.epoch {
                    if err := room_restore_install(room, options, now); err != .None {
                        return room_transition_error(room, err)
                    }
                } else if room.session.ready && room.prepared.ready && room.prepared.point == grant.recovered {
                    install_start := gd.time_get_ticks_usec(gd.singleton_time())

                    if err := session_takeover(
                        &room.session,
                        &room.prepared,
                        &room.lease,
                        &target,
                        dedicated = room.options.session.role == .Server,
                    ); err != .None {
                        if err != .Presentation {
                            return room_transition_error(room, err)
                        }
                    } else {
                        room.migrations += 1
                        room_recovered(room, current, previous_confirmed, grant, now)
                        room.recovery.install_us = gd.time_get_ticks_usec(gd.singleton_time()) - install_start
                    }
                } else {
                    room.control_error = .No_Checkpoint
                }

                if room.session.ready && room.session.authority && room.session.server.cfg.epoch == grant.epoch {
                    room.phase, room.active_epoch, room.handoff_requested = .Hosting, grant.epoch, false
                }
            }
        } else {
            room.lease.require_owner = false

            if auth.lease_live(&room.lease, grant.epoch) {
                if !room.session.ready {
                    options := room.options.session

                    if err := migration_transport(&options, &room.lease, &target); err != .None {
                        room_fail(room, err)
                        return err
                    }

                    options.role, options.port =
                        room.options.session.role == .Observer || room.options.session.role == .Server ? .Observer : .Client,
                        grant.endpoint.port
                    options.address = fmt.ctprintf("%s", string(cast(cstring)&grant.endpoint.host[0]))
                    options.network.epoch, options.network.require_permit, options.permit =
                        grant.epoch, true, room_permit(room)
                    options.replication.room = room.options.room

                    if err := room_session_open(room, options); err != .None {
                        room_fail(room, err)
                        return err
                    }

                    room.phase, room.active_epoch = .Following, grant.epoch
                } else if grant.epoch > current && now - room.last_game_reconnect >= 300 {
                    err :=
                        room.session.authority ? session_rejoin(&room.session, &room.lease, &target) : room_redirect(room, &target)
                    room.last_game_reconnect = now

                    if err != .None && err != .Presentation && err != .Transport {
                        return room_transition_error(room, err)
                    }

                    if err == .None {
                        room.phase, room.active_epoch, room.handoff_requested = .Following, grant.epoch, false
                        room.migrations += 1
                        room_recovered(room, current, previous_confirmed, grant, now)
                        auth.prepared_destroy(&room.prepared)
                        auth.prepared_destroy(&room.candidate)
                    }
                } else if !room.session.authority &&
                   (room.session.client.phase == .Disconnected ||
                           (room.session.client.phase == .Rejected && room.session.client.rejection == .Denied)) &&
                   now - room.last_game_reconnect >= 300 {
                    err := room_redirect(room, &target)
                    room.last_game_reconnect = now

                    if err != .None && err != .Presentation && err != .Transport && err != .Wrong_Phase {
                        return room_transition_error(room, err)
                    }
                }
            }
        }
    }

    if room.session.ready {
        if room.session.authority && session_link(&room.session)^.outgoing.ready {
            connection, connected := net.server_connection(
                &room.session.server,
                session_link(&room.session)^.outgoing.target,
            )
            allowed := false

            for member in room.members {
                if connected &&
                   member.enabled &&
                   member.can_host &&
                   member.trusted_authority &&
                   (!connection.spectator || member.infrastructure) &&
                   member.identity != room.options.identity &&
                   (grant.policy.mode != .Dedicated || member.infrastructure) &&
                   member.game_token_hash == connection.token_hash &&
                   member.identity.incarnation == connection.incarnation {
                    allowed = true
                    break
                }
            }

            if connected && !allowed {
                rec.link_untarget(session_link(&room.session))
            }
        }

        // Role changes can rebuild Session with a lease-only permit. Reinstall
        // the phase gate so a later handoff also freezes the restored authority.
        room.session.options.permit = room_permit(room)

        if room.session.authority {
            room.session.server.permit = room.session.options.permit
        } else {
            room.session.client.permit = room.session.options.permit
        }

        if room.session.authority {
            room.session.server.identity_user = room
            room.session.server.identity_check = proc(user: rawptr, token_hash: [32]u8, incarnation: u64) -> bool {
                return room_identity(cast(^Room(S, C, A, E, N))user, token_hash, incarnation)
            }
        }

        room_moderation_roster(room)
        input := control

        if room.handoff_requested {
            input = room.model.neutral
        }

        if err := session_frame(&room.session, dt, input); err != .None {
            room_fail(room, err)
            return err
        }

        // The phase-aware permit freezes gameplay while the final checkpoint is
        // transferred. Control renewal keeps this frozen owner reserved until it
        // can retire and release the exact prepared final point.
        if room.phase == .Freezing || room.phase == .Releasing {
            if err := net.server_drain_fenced(&room.session.server); err != .None {
                room_fail(room, err)
                return err
            }

            rec.link_server(
                session_link(&room.session),
                &room.session.server,
                u64(gd.time_get_ticks_msec(gd.singleton_time())),
            )
            _, live := net.server_connection(&room.session.server, session_link(&room.session)^.outgoing.target)

            if !live || session_link(&room.session)^.outgoing.phase == .Failed {
                room.retired, room.control_error = auth.lease_retire(&room.lease)
                auth.prepared_destroy(&room.prepared)
                room.control_error = auth.prepared_capture(
                    &room.prepared,
                    &room.session.server,
                    room.options.room,
                    room.options.identity.incarnation,
                )
                room.phase, room.handoff_requested = .Recovering, false
            }
        }
    }

    if room.recovery.to_epoch != 0 &&
       !room.recovery.ready &&
       room.session.ready &&
       !room.session.fenced &&
       (room.session.authority || room.session.client.phase == .Running) &&
       room.session.reset_index >= len(room.session.reset_changes) {
        room.recovery.ready = true
        room.recovery.interruption_ms = now - room.interruption_start
        room.interruption_start = 0
    }

    room_save_frame(room, now)

    if room.control_paused || room.rpc.pending || room.lease.pending || now - room.last_control < 150 {
        return .None
    }

    if room.removal.phase == .Queued && !room.removal.refresh && room.phase == .Hosting {
        // Renew first if the current local lease cannot cover one bounded attempt.
        // Unsupported coordinators must not starve ordinary lease maintenance.
        reserve := u64(room.lease.view.policy.lease_ms) / 2

        if room.lease.deadline <= now || room.lease.deadline - now < reserve {
            room.control_error = auth.rpc_begin(
                &room.rpc,
                {verb = .Renew, epoch = grant.epoch, tick = room.session.server.timeline.head},
            )
            room.last_control = now
            return .None
        }

        room.removal.rpc_timeout = room.rpc.timeout_ms
        room.rpc.timeout_ms = max(room.rpc.retry_ms, min(u64(500), reserve / 2))
        room.control_error = auth.rpc_remove(&room.rpc, room.removal.epoch, room.removal.target)

        if room.control_error == .None {
            room.removal.phase = .Waiting
            room.removal.sequence = room.rpc.request.sequence
            room.removal.attempts += 1
        } else {
            room.rpc.timeout_ms = room.removal.rpc_timeout
        }

        if room.control_error != .None && room.control_error != .Busy {
            room.removal.phase = .Failed
            room.removal.error = room.control_error
        }

        room.last_control = now
        return .None
    }

    command := auth.Command {
        verb = .Query,
    }

    if room.phase == .Connecting && room.options.bootstrap && grant.epoch == 0 {
        command.verb = .Start
    }

    if room.phase == .Hosting {
        if room.options.automatic_successor {
            room_select_successor(room)
        }

        connection, live := room_successor_connection(room)
        successor: auth.Identity

        for member in room.members {
            if member.identity.member == room.options.successor.member &&
               member.enabled &&
               member.can_host &&
               member.trusted_authority &&
               member.game_token_hash == connection.token_hash &&
               member.identity.incarnation == connection.incarnation {
                successor = member.identity
                break
            }
        }

        live = live && auth.identity_valid(successor) && successor != room.options.identity

        if room.handoff_requested && !live {
            room.handoff_requested = false
            room.control_error = .No_Checkpoint
        }

        if live {
            if !session_link(&room.session)^.outgoing.ready ||
               session_link(&room.session)^.outgoing.target != connection.peer ||
               session_link(&room.session)^.outgoing.scope.binding != connection.generation {
                if err := session_backup_peer(&room.session, connection.peer, max(room.session.server.cfg.hz / 2, 1));
                   err != .None {
                    room_fail(room, err)
                    return err
                }
            }

            if room.rpc.reply.nominee != successor || room.rpc.reply.binding != connection.generation {
                command = {
                    verb      = .Nominate,
                    epoch     = grant.epoch,
                    successor = successor,
                    binding   = connection.generation,
                }
            }
        }

        if command.verb == .Query {
            command = {
                verb  = .Renew,
                epoch = grant.epoch,
                tick  = room.session.server.timeline.head,
            }
        }

        local_pending := false

        for peer in room.session.server.peers {
            if peer.local && peer.action_count != 0 {
                local_pending = true
            }
        }

        if room.handoff_requested &&
           !local_pending &&
           live &&
           room.rpc.reply.nominee == successor &&
           room.rpc.reply.binding == connection.generation {
            room.frozen_tick, room.phase = room.session.server.timeline.head, .Freezing
            room.interruption_start = now
            rec.sender_cancel(&session_link(&room.session)^.outgoing)
            session_link(&room.session)^.publish_now = true
            command = {
                verb  = .Renew,
                epoch = grant.epoch,
                tick  = room.frozen_tick,
            }
        }
    }

    if room.phase == .Following && room.session.ready && room.rpc.reply.nominee == room.options.identity {
        if !room.candidate.ready {
            receipt, valid := rec.receiver_latest(&session_link(&room.session)^.incoming)

            if valid && (!room.prepared.ready || receipt.archive.sequence > room.prepared.point.archive.sequence) {
                room.control_error = auth.prepared_copy(
                    &room.candidate,
                    &session_link(&room.session)^.incoming,
                    receipt.archive,
                )
            }
        }

        can_prepare :=
            room.candidate.ready &&
            (room.options.preparation_ready == nil ||
                    room.options.preparation_ready(
                        room.options.preparation_user,
                        room.candidate.point,
                        room.candidate.bytes,
                    ))

        if room.candidate.ready && !can_prepare {
            // Do not remain pinned to an obsolete incomplete candidate while the
            // source continues producing newer checkpoints. The approved older
            // point remains separately retained throughout this replacement.
            latest, valid := rec.receiver_latest(&session_link(&room.session)^.incoming)

            if valid && latest.archive.sequence > room.candidate.point.archive.sequence {
                next: auth.Prepared

                if err := auth.prepared_copy(&next, &session_link(&room.session)^.incoming, latest.archive);
                   err == .None {
                    auth.prepared_destroy(&room.candidate)
                    room.candidate, next = next, {}
                    can_prepare = room.options.preparation_ready(
                        room.options.preparation_user,
                        room.candidate.point,
                        room.candidate.bytes,
                    )
                } else {
                    room.control_error = err
                }

                auth.prepared_destroy(&next)
            }
        }

        if can_prepare {
            command = {
                verb  = .Prepare,
                point = room.candidate.point,
            }
        }

        if !can_prepare &&
           room.prepared.ready &&
           room.rpc.reply.prepared &&
           room.rpc.reply.point == room.prepared.point &&
           (room.rpc.reply.released || grant.remaining_ms == 0) {
            // A newer archive with unavailable external dependencies does not
            // invalidate the previously approved recovery point.
            auth.prepared_destroy(&room.candidate)
            command = {
                verb  = .Claim,
                epoch = grant.epoch,
                point = room.prepared.point,
            }
            room.phase = .Claiming
        }
    }

    if room.phase == .Claiming {
        if room.prepared.ready {
            command = {
                verb  = .Claim,
                epoch = grant.epoch,
                point = room.prepared.point,
            }
        }
    }

    if room.phase == .Recovering &&
       room.prepared.ready &&
       grant.owner == room.options.identity &&
       grant.epoch == room.prepared.point.scope.epoch {
        command = {
            verb  = .Recover_Owner,
            epoch = grant.epoch,
            point = room.prepared.point,
        }
    }

    if room.phase == .Freezing || room.phase == .Releasing {
        if room.phase == .Freezing {
            command = {
                verb  = .Renew,
                epoch = grant.epoch,
                tick  = room.frozen_tick,
            }
        }

        ack := session_link(&room.session)^.outgoing.acknowledged.archive

        if ack.sequence != 0 &&
           ack.tick == room.frozen_tick &&
           room.rpc.reply.prepared &&
           room.rpc.reply.point.archive == ack &&
           room.rpc.reply.point.scope == session_link(&room.session)^.outgoing.scope {
            if room.phase == .Freezing {
                room.retired, room.control_error = auth.lease_retire(&room.lease)
            }

            if room.control_error == .None {
                command = {
                    verb    = .Release,
                    retired = room.retired,
                    point   = room.rpc.reply.point,
                }
                room.phase = .Releasing
            }
        }
    }

    // Coordinator restart can fence an otherwise surviving owner. Preserve its
    // current world, or use the exact older archive in an unconsumed durable grant.
    if grant.owner == room.options.identity &&
       grant.epoch != 0 &&
       grant.remaining_ms == 0 &&
       room.phase != .Freezing &&
       room.phase != .Releasing &&
       !room.handoff_requested {
        if room.session.ready &&
           room.session.authority &&
           room.session.server.cfg.epoch == grant.epoch &&
           room.phase != .Recovering {
            auth.prepared_destroy(&room.prepared)
            room.control_error = auth.prepared_capture(
                &room.prepared,
                &room.session.server,
                room.options.room,
                room.options.identity.incarnation,
            )
        }

        if room.prepared.ready {
            room.phase = .Recovering
            command = {
                verb  = .Recover_Owner,
                epoch = grant.epoch,
                point = room.prepared.point,
            }
        }
    }

    // Keep an already granted authority reservation alive while presentation
    // cancellation drains or the approved runtime is being installed.
    if grant.owner == room.options.identity && grant.epoch > current && grant.remaining_ms != 0 {
        // A delayed reply can have a stale local deadline while the coordinator
        // still reserves this actor. Requesting renewal grants no local authority.
        command = {
            verb  = .Renew,
            epoch = grant.epoch,
            tick  = grant.last_known_tick,
        }
    }

    room.control_error = auth.rpc_begin(&room.rpc, command)
    room.last_control = now
    return .None
}

@(private)
room_permit :: proc(room: ^Room($S, $C, $A, $E, $N)) -> net.Permit {
    return {user = room, allow = proc(user: rawptr, epoch: u64) -> bool {
            r := cast(^Room(S, C, A, E, N))user

            if r.session.authority && r.phase != .Hosting {
                return false
            }

            return auth.lease_live(&r.lease, epoch)
        }}
}

// Transition preflight and the operation each sample the lease. A valid clock
// may reach the deadline between them. Preserve the old runtime/prepared point
// and wait for fresh control progress; a poisoned clock remains a hard failure.
@(private)
room_transition_error :: proc(room: ^Room($S, $C, $A, $E, $N), error: net.Error) -> net.Error {
    if error == .Fenced && room.lease.ready && !room.lease.poisoned && room.lease.now >= room.lease.deadline {
        room.session.fenced = true

        if room.interruption_start == 0 {
            room.interruption_start = room.lease.now
        }

        if room.session.ready {
            r.clock_init(
                &room.session.clock,
                room.session.authority ? room.session.server.cfg.hz : room.session.client.cfg.hz,
            )
        }

        return .None
    }

    room_fail(room, error)
    return error
}

@(private)
room_fail :: proc(room: ^Room($S, $C, $A, $E, $N), error: net.Error) {
    room.phase, room.error = .Failed, error
}

@(private)
room_identity :: proc(room: ^Room($S, $C, $A, $E, $N), token_hash: [32]u8, incarnation: u64) -> bool {
    if incarnation == 0 {
        return false
    }

    for member in room.members {
        if member.enabled && member.identity.incarnation == incarnation && member.game_token_hash == token_hash {
            return true
        }
    }

    return false
}

@(private)
room_recovered :: proc(room: ^Room($S, $C, $A, $E, $N), old_epoch, confirmed: u64, grant: auth.View, now: u64) {
    if room.interruption_start == 0 {
        room.interruption_start = now
    }

    tick := grant.recovered.archive.tick
    room.recovery = {
        from_epoch         = old_epoch,
        to_epoch           = grant.epoch,
        checkpoint_tick    = tick,
        previous_confirmed = confirmed,
        known_lost_ticks   = confirmed > tick ? confirmed - tick : 0,
        archive_bytes      = u64(grant.recovered.archive.bytes),
    }
}


@(private)
room_control_connect :: proc(room: ^Room($S, $C, $A, $E, $N)) -> bool {
    switch room.options.control_backend {
    case .Enet:
        if !transportgd.enet_join(
            &room.control,
            fmt.ctprintf("%s", room.options.coordinator),
            room.options.control_port,
        ) {
            return false
        }

        room.control_wire = transportgd.enet_transport(&room.control)
    case .Websocket:
        if !transportgd.websocket_join(
            &room.control_websocket,
            room.options.coordinator,
            tls = room.options.control_tls,
        ) {
            return false
        }

        room.control_wire = transportgd.websocket_transport(&room.control_websocket)
    }

    return true
}


@(private)
room_transport :: proc(room: ^Room($S, $C, $A, $E, $N), view: auth.View) -> Migration_Transport {
    target := Migration_Transport {
        backend = room.options.session.backend,
    }

    if target.backend == .Steam {
        target.steam = room.options.session.steam
    }

    if target.backend == .Rtc {
        room.rtc_authorization = {
            view     = view,
            identity = room.options.identity,
            key      = room.options.key,
        }
        target.rtc = transportgd.rtc_grant_config(
            &room.rtc_authorization,
            room.options.session.rtc.url,
            view.owner == room.options.identity,
        )
        target.rtc.ice_json = room.options.session.rtc.ice_json
        target.rtc.ice_user, target.rtc.ice_source =
            room.options.session.rtc.ice_user, room.options.session.rtc.ice_source
        target.rtc.native_extension = room.options.session.rtc.native_extension
    }

    return target
}
