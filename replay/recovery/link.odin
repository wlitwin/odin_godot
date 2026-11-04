package replay_recovery

import "core:mem"
import r "godot:replay"
import tf "godot:replay/transfer"
import net "godot:replay/net"
import tr "godot:replay/transport"

Application_Route :: struct {
    user:    rawptr,
    handles: proc(user: rawptr, from: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> bool,
}

MAX_APPLICATION_ROUTES :: tr.MAX_ROUTER_LANES - 3

Link_Config :: struct {
    room:                u64,
    accept_checkpoints:  bool,
    transport:           tr.Router_Config,
    transfer:            Config,
    applications:        [MAX_APPLICATION_ROUTES]Application_Route,
    application_user:    rawptr,
    application_handles: proc(user: rawptr, from: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> bool,
}

DEFAULT_LINK_CONFIG :: Link_Config {
    room      = 1,
    transport = tr.DEFAULT_ROUTER_CONFIG,
    transfer  = DEFAULT_CONFIG,
}

// Gameplay and checkpoint replication share one transport and a combined output
// budget. Initialization does not choose a successor or grant authority. An
// application/coordinator explicitly selects a live admitted connection to trust.
Link_Ownership :: struct {
    allocator, container, config, wire, policy, application, lane_user: r.Owned_Context,
    route_users:                                                        [MAX_APPLICATION_ROUTES]r.Owned_Context,
    outgoing:                                                           tf.Ownership,
    incoming:                                                           Receiver_Ownership,
    codec:                                                              net.Container_Ownership,
    // Returns a NEW owning token, retaining exact lane storage + parent graph.
    lane_owner:                                                         proc(
        user: rawptr,
        router: ^tr.Router,
        wire: tr.Transport,
    ) -> (
        r.Owned_Context,
        net.Error,
    ),
}

Link :: struct($S, $C, $A, $E: typeid, $N: int) {
    ownership:                    Link_Ownership,
    retained:                     r.Owner_Retains,
    cleanup:                      bool,
    game_owner, background_owner: r.Owned_Context,
    allocator:                    mem.Allocator,
    ready:                        bool,
    cfg:                          Link_Config,
    router:                       tr.Router,
    background:                   tr.Transport,
    outgoing:                     Sender,
    incoming:                     Receiver(S, C, A, E, N),
    publish_codec:                net.Checkpoint_Codec,
    interval:                     u32,
    last_published:               u64,
    sequence:                     u64, // survives untarget/re-target on a still-live connection
    publish_now:                  bool,
    policy_id:                    u64,
    policy_data:                  []u8,
    policy_user:                  rawptr,
    policy_valid:                 proc(user: rawptr, id: u64, bytes: []u8) -> bool,
    error:                        Error,
    model_error:                  net.Error,
    ignored:                      u64,
    rxb:                          [CHUNK_BYTES + 128]u8,
}

link_init :: proc(
    l: ^Link($S, $C, $A, $E, $N),
    wire: tr.Transport,
    cfg := DEFAULT_LINK_CONFIG,
    allocator := context.allocator,
    ownership: Link_Ownership = {},
) -> bool {
    if link_owner_entry(l, .Read) != .None || l.cleanup {
        return false
    }

    if l.ready || !config_valid({cfg.room, 1, 1, 1}, 1, cfg.transfer) {
        return false
    }

    managed := !r.owner_is_nil(ownership.container.owner)

    if managed && (r.owner_is_nil(ownership.allocator.owner) || ownership.lane_owner == nil) {
        return false
    }

    if r.owner_contexts_check(
           {owner = ownership.allocator.owner, owner_allocator_data = ownership.allocator.data},
           allocator,
       ) !=
       .None {
        return false
    }

    bindings := [?]r.Owned_Context {
        ownership.allocator,
        ownership.config,
        ownership.wire,
        ownership.policy,
        ownership.application,
        ownership.lane_user,
        ownership.container,
    }
    values := [?]rawptr {
        allocator.data,
        &l.cfg,
        wire.user,
        l.policy_user,
        cfg.application_user,
        ownership.lane_user.data,
        l,
    }

    for binding, index in bindings {
        if r.owned_context_access(binding, values[index], managed, .Execute) != .None {
            return false
        }
    }

    for route, index in cfg.applications {
        if r.owned_context_access(ownership.route_users[index], route.user, managed, .Execute) != .None {
            return false
        }
    }

    l.ownership = ownership
    owners: [16]r.Owner
    n := 0

    for binding in bindings {
        owners[n] = binding.owner
        n += 1
    }

    for binding in ownership.route_users {
        owners[n] = binding.owner
        n += 1
    }

    if r.owner_retains_acquire(&l.retained, owners[:n]) != .None {
        retained := l.retained
        l^ = {}

        if r.owner_retains_drop(&retained) != .None {
            l.retained = retained
            l.cleanup = true
        }

        return false
    }

    committed := false

    defer if !committed {
        link_destroy(l)
    }

    l.allocator, l.cfg = allocator, cfg
    lanes := cfg.application_handles != nil ? 3 : 2

    for route, i in cfg.applications {
        if route.handles != nil {
            lanes = i + 4
        }
    }

    if !tr.router_init(
        &l.router,
        wire,
        link_classify,
        cfg.transport,
        user = &l.cfg,
        allocator = allocator,
        lane_count = lanes,
    ) {
        return false
    }

    l.background = tr.router_transport(&l.router, 1)

    if managed {
        game, error := ownership.lane_owner(ownership.lane_user.data, &l.router, tr.router_transport(&l.router, 0))

        if error != .None {
            return false
        }

        l.game_owner = game
        background, background_error := ownership.lane_owner(ownership.lane_user.data, &l.router, l.background)

        if background_error != .None {
            return false
        }

        l.background_owner = background
    }

    committed = true
    l.ready = true
    return true
}

link_destroy :: proc(l: ^Link($S, $C, $A, $E, $N)) -> net.Error {
    if error := link_owner_entry(l, .Read); error != .None {
        return error
    }

    if !l.cleanup {
        if sender_destroy(&l.outgoing) != .None {
            return .Wrong_Phase
        }

        // An SDK host has no incoming Receiver. Do not enter a never-constructed
        // child that intentionally has no managed context; partial owned children
        // retain their headers and must still finish their complete cleanup.
        if l.incoming.ready ||
           l.incoming.receiver_retains.count != 0 ||
           l.incoming.receiver_cleanup ||
           l.incoming.archive_codec.ready ||
           l.incoming.transfer.bytes != nil {
            if receiver_destroy(&l.incoming) != .None {
                return .Wrong_Phase
            }
        }

        if net.checkpoint_codec_destroy(&l.publish_codec) != .None {
            return .Wrong_Phase
        }

        delete(l.policy_data, l.allocator)
        l.policy_data = nil
        tr.router_destroy(&l.router)

        if r.owner_drop(&l.game_owner.owner) != .None || r.owner_drop(&l.background_owner.owner) != .None {
            return .Wrong_Phase
        }
    }

    retained := l.retained
    l^ = {}

    if r.owner_retains_drop(&retained) != .None {
        l.retained = retained
        l.cleanup = true
        return .Wrong_Phase
    }

    return .None
}

link_game_owner :: proc(l: ^Link($S, $C, $A, $E, $N)) -> r.Owned_Context {
    return link_owner_entry(l) == .None ? l.game_owner : r.Owned_Context{}
}

link_background_owner :: proc(l: ^Link($S, $C, $A, $E, $N)) -> r.Owned_Context {
    return link_owner_entry(l) == .None ? l.background_owner : r.Owned_Context{}
}

link_game_transport :: proc(l: ^Link($S, $C, $A, $E, $N)) -> tr.Transport {
    if error := link_owner_entry(l); error != .None {
        return {}
    }

    return tr.router_transport(&l.router, 0)
}

// Optional application content traffic shares this link's total budget and
// primary reserve. The caller services this borrowed lane, including while the
// gameplay runner is fenced; application receive still validates admission.
link_application_transport :: proc(l: ^Link($S, $C, $A, $E, $N)) -> tr.Transport {
    if error := link_owner_entry(l); error != .None {
        return {}
    }

    return tr.router_transport(&l.router, 2)
}

// Add independent bounded consumers before link_init. Lane 2 remains available
// to the original single-application API. Repeating an identical route is idempotent.
link_add_application :: proc(cfg: ^Link_Config, route: Application_Route) -> (lane: int, ok: bool) {
    if route.handles == nil {
        return -1, false
    }

    for existing, i in cfg.applications {
        if existing.handles == route.handles && existing.user == route.user {
            return i + 3, true
        }
    }

    for &existing, i in cfg.applications {
        if existing.handles == nil {
            existing = route
            return i + 3, true
        }
    }

    return -1, false
}

link_application_lane :: proc(l: ^Link($S, $C, $A, $E, $N), lane: int) -> tr.Transport {
    if error := link_owner_entry(l); error != .None {
        return {}
    }

    if lane < 3 || lane >= tr.MAX_ROUTER_LANES {
        return {}
    }

    return tr.router_transport(&l.router, lane)
}

link_pump :: proc(l: ^Link($S, $C, $A, $E, $N), now_ms: u64) -> bool {
    if error := link_owner_entry(l); error != .None {
        return false
    }

    return l.ready && tr.router_pump(&l.router, now_ms)
}

link_target :: proc(
    l: ^Link($S, $C, $A, $E, $N),
    server: ^net.Server(S, C, A, E, N),
    peer: tr.Peer_Id,
    interval_ticks: u32 = 0,
    policy_id: u64 = 0,
    policy_data: []u8 = nil,
) -> net.Error {
    if error := link_owner_entry(l); error != .None {
        return error
    }

    if !l.ready || !server.initialized || server.wire.user != link_game_transport(l).user {
        return .Wrong_Phase
    }

    connection, live := net.server_connection(server, peer)

    if !live {
        return .Invalid_Input
    }

    if (server.admission != nil) != (policy_id != 0) ||
       len(policy_data) > 65536 ||
       (policy_id == 0 && len(policy_data) != 0) {
        return .Checkpoint_Policy
    }

    if !l.publish_codec.ready {
        if err := net.checkpoint_codec_init(
            &l.publish_codec,
            S,
            C,
            A,
            E,
            N,
            allocator = l.allocator,
            ownership = l.ownership.codec,
        ); err != .None {
            return err
        }
    }

    scope := Scope{l.cfg.room, server.cfg.epoch, connection.generation, server.cfg.content}

    if !l.outgoing.ready || l.outgoing.target != peer || l.outgoing.scope != scope {
        if sender_destroy(&l.outgoing) != .None {
            return .Wrong_Phase
        }

        owned := l.ownership.outgoing
        owned.wire = l.background_owner

        if sender_init(&l.outgoing, scope, peer, l.background, l.cfg.transfer, l.allocator, ownership = owned) !=
           .None {
            return .Invalid_Config
        }

        l.outgoing.next_sequence = l.sequence
    }

    data := make([]u8, len(policy_data), l.allocator)
    copy(data, policy_data)
    delete(l.policy_data, l.allocator)
    l.policy_id, l.policy_data = policy_id, data
    l.interval = interval_ticks == 0 ? server.cfg.hz : interval_ticks
    l.publish_now = true
    l.error, l.model_error = .None, .None
    return .None
}

link_untarget :: proc(l: ^Link($S, $C, $A, $E, $N)) -> net.Error {
    if error := link_owner_entry(l); error != .None {
        return error
    }

    if sender_destroy(&l.outgoing) != .None {
        return .Wrong_Phase
    }

    delete(l.policy_data, l.allocator)
    l.policy_data = nil
    l.policy_id, l.publish_now, l.interval = 0, false, 0
    return .None
}

// Call after gameplay pumping/steps. Failure of the backup path is observable in
// Link.error/model_error and does not stop the active game's simulation.
link_server :: proc(l: ^Link($S, $C, $A, $E, $N), server: ^net.Server(S, C, A, E, N), now_ms: u64) {
    if error := link_owner_entry(l); error != .None {
        return
    }

    if !l.ready || !server.initialized {
        return
    }

    connection, live := net.server_connection(server, l.outgoing.target)
    live =
        live &&
        l.outgoing.ready &&
        connection.generation == l.outgoing.scope.binding &&
        server.cfg.epoch == l.outgoing.scope.epoch

    for _ in 0 ..< l.cfg.transport.packets_per_lane {
        packet := tr.receive(&l.background, l.rxb[:])

        if packet.state == .Empty || packet.state == .Disconnected {
            break
        }

        if packet.state != .Received {
            l.ignored += 1
            continue
        }

        if live {
            sender_receive(&l.outgoing, packet.from, l.rxb[:packet.count], now_ms)
        } else {
            l.ignored += 1
        }
    }

    if !l.outgoing.ready {
        return
    }

    if !live {
        l.error = .Transport
        return // the last receipt stays inspectable, but this successor is unavailable
    }

    if l.outgoing.phase != .Sending && (l.publish_now || server.timeline.head - l.last_published >= u64(l.interval)) {
        l.outgoing.compress = net.server_checkpoint_compression(server, l.outgoing.target)
        l.outgoing.shuffle = net.server_checkpoint_shuffle(server, l.outgoing.target)
        cp: net.Checkpoint(S, C, A, N)
        defer net.checkpoint_destroy(&cp)
        l.last_published, l.publish_now = server.timeline.head, false
        l.model_error = net.checkpoint_capture(server, &cp, l.policy_id, l.policy_data, l.allocator)

        if l.model_error == .None {
            if err := sender_publish(
                &l.outgoing,
                &cp,
                server.model,
                now_ms,
                &l.publish_codec,
                net.server_checkpoint_reliable(server, l.outgoing.target) ? tr.Channel.Reliable : tr.Channel.Unreliable,
            ); err != .None {
                l.error = err
            }

            l.sequence = max(l.sequence, l.outgoing.next_sequence)
        } else {
            l.error = .Invalid_Archive
        }
    }

    if err := sender_update(&l.outgoing, now_ms); err != .None {
        l.error = err
    }

    if l.outgoing.phase == .Failed {
        l.error = l.outgoing.error
    }
}

link_client :: proc(l: ^Link($S, $C, $A, $E, $N), client: ^net.Client(S, C, A, E, N), now_ms: u64) {
    if error := link_owner_entry(l); error != .None {
        return
    }

    if !l.ready || !client.initialized {
        return
    }

    if l.cfg.accept_checkpoints && client.phase == .Running {
        scope := Scope{l.cfg.room, client.cfg.epoch, client.generation, client.cfg.content}

        if !l.incoming.ready || l.incoming.source != client.authority || l.incoming.scope != scope {
            if receiver_destroy(&l.incoming) != .None {
                l.error = .Wrong_Phase
                return
            }

            owned := l.ownership.incoming
            owned.transfer.wire = l.background_owner

            if err := receiver_init(
                &l.incoming,
                scope,
                client.authority,
                l.background,
                client.model,
                l.cfg.transfer,
                l.allocator,
                ownership = owned,
            ); err != .None {
                l.error = err
                return
            }

            l.incoming.policy_user, l.incoming.policy_valid = l.policy_user, l.policy_valid
        }
    }

    for _ in 0 ..< l.cfg.transport.packets_per_lane {
        packet := tr.receive(&l.background, l.rxb[:])

        if packet.state == .Empty || packet.state == .Disconnected {
            break
        }

        if packet.state != .Received {
            l.ignored += 1
            continue
        }

        if l.incoming.ready && l.cfg.accept_checkpoints {
            receiver_receive(&l.incoming, packet.from, l.rxb[:packet.count], now_ms, packet.channel)
        } else {
            l.ignored += 1
        }
    }

    if l.incoming.ready && l.cfg.accept_checkpoints {
        if err := receiver_update(&l.incoming, now_ms); err != .None {
            l.error = err
        }

        if !l.incoming.active && l.incoming.failure != .None {
            l.error = l.incoming.failure == .Timeout ? .Timeout : .Invalid_Archive
        }
    }
}

@(private)
link_classify :: proc(user: rawptr, from: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> int {
    // Oversized lookalikes go through the gameplay runner's malformed-packet
    // path; they cannot lodge a Buffer_Too_Small packet in the background queue.
    if channel <= .Unreliable && len(bytes) <= CHUNK_BYTES + 128 && handles(bytes) {
        return 1
    }

    cfg := cast(^Link_Config)user

    if cfg.application_handles != nil && cfg.application_handles(cfg.application_user, from, channel, bytes) {
        return 2
    }

    for route, i in cfg.applications {
        if route.handles != nil && route.handles(route.user, from, channel, bytes) {
            return i + 3
        }
    }

    return 0
}

@(private)
link_owner_entry :: proc(l: ^Link($S, $C, $A, $E, $N), access: r.Owner_Access = .Execute) -> net.Error {
    if l == nil || r.owner_retains_access(&l.retained, access) != .None {
        return .Invalid_Model
    }

    if l.cleanup {
        return access == .Read ? net.Error.None : net.Error.Wrong_Phase
    }

    managed := !r.owner_is_nil(l.ownership.container.owner)
    bindings := [?]r.Owned_Context {
        l.ownership.container,
        l.ownership.config,
        l.ownership.wire,
        l.ownership.policy,
        l.ownership.application,
        l.ownership.lane_user,
    }
    values := [?]rawptr {
        l,
        &l.cfg,
        l.router.wire.user,
        l.policy_user,
        l.cfg.application_user,
        l.ownership.lane_user.data,
    }

    for binding, index in bindings {
        if r.owned_context_access(binding, values[index], managed, access) != .None {
            return .Invalid_Model
        }
    }

    for route, index in l.cfg.applications {
        if r.owned_context_access(l.ownership.route_users[index], route.user, managed, access) != .None {
            return .Invalid_Model
        }
    }

    return .None
}
