package replay_net_legacy

import "core:mem"
import r "godot:replay"
import tr "godot:replay/transport"

CHECKPOINT_VERSION :: u16(4)
CHECKPOINT_KIND :: u16(0x434b)
MAX_CHECKPOINT_BYTES :: 1024 * 1024

// A durable, versioned authority archive. It owns every variable-sized array;
// runtime callbacks, connections, presentation history, and allocators are never
// serialized. Copying a live Checkpoint would alias allocations: use by pointer.
Checkpoint :: struct($State, $Control, $Action: typeid, $Seats: int) {
    allocator:   mem.Allocator,
    ready:       bool,
    header:      Checkpoint_Header,
    settings:    Checkpoint_Settings,
    frame:       r.Frame(State),
    held:        [Seats]Control,
    held_views:  [Seats]View_Time,
    peers:       [dynamic]Checkpoint_Peer,
    actions:     [dynamic]Checkpoint_Action(Action),
    inputs:      [dynamic]Checkpoint_Input(Control),
    outcomes:    [dynamic]Checkpoint_Outcome,
    banned:      [dynamic][32]u8,
    policy_data: []u8,
}

Checkpoint_Header :: struct {
    version:                                              u16,
    protocol, content, epoch, contract, generation, tick: u64,
    local_seat:                                           u16,
    joins, leaves, fresh:                                 u64,
    locked:                                               bool,
    policy_id:                                            u64,
    peers, actions, outcomes, bans:                       u16,
    inputs, policy_bytes:                                 u32,
}

Checkpoint_Settings :: struct {
    hz, history, lead, max_future, max_prediction, snapshot_every, watch_delay: u32,
    timeout_ms:                                                                 u64,
    packets_per_pump, bytes_per_pump, snapshot_history:                         u32,
    delta_snapshots:                                                            bool,
    egress_bytes_per_second, egress_bytes_per_pump, unreliable_packet_limit:    u32,
    require_permit:                                                             bool,
    max_rewind, max_view_span, view_slack:                                      u32,
}

Checkpoint_Peer :: struct {
    index, seat:                                         u16,
    spectator, local, active, pending:                   bool,
    token_hash:                                          [32]u8,
    generation, serial, action_received, action_settled: u64,
    incarnation:                                         u64,
}

Checkpoint_Action :: struct($Action: typeid) {
    peer:           u16,
    sequence, tick: u64,
    value:          Action,
    reason:         Action_Reason,
}

Checkpoint_Input :: struct($Control: typeid) {
    peer:  u16,
    tick:  u64,
    value: Control,
    view:  View_Time,
}

Checkpoint_Held :: struct($Control: typeid, $Seats: int) {
    controls: [Seats]Control,
    views:    [Seats]View_Time,
}

Checkpoint_Outcome :: struct {
    peer:    u16,
    outcome: Action_Outcome,
}

Resume_Options :: struct {
    permit:            Permit,
    epoch:             u64, // must be newer: old authority traffic is never admitted after restore
    local_seat:        u16, // zero for a dedicated authority, otherwise an existing seat
    preserve_pending:  bool, // false explicitly retires accepted-but-unexecuted actions
    retain_membership: bool, // true for a driver that pauses simulation until peers rejoin
    policy_id:         u64,
    admission_user:    rawptr,
    admission:         proc(user: rawptr, token_hash: [32]u8, spectator: bool) -> bool,
}

server_set_local_token :: proc(s: ^Server($S, $C, $A, $E, $N), token: Token) -> Error {
    if !s.initialized || !token_valid(token) || s.local_seat == 0 {
        return .Invalid_Input
    }

    hash := token_digest(token)

    for peer in s.peers {
        if !peer.local && peer.phase != .Vacant && peer.token_hash == hash {
            return .Invalid_Input
        }
    }

    for &peer in s.peers {
        if peer.local {
            peer.token_hash = hash
            return .None
        }
    }

    return .Wrong_Phase
}

// Looks up an existing playable reservation. The archive stores a digest, never
// the bearer token; a local save keeps that credential in a separate profile file.
checkpoint_seat :: proc(cp: ^Checkpoint($S, $C, $A, $N), token: Token) -> (seat: u16, found: bool) {
    if !cp.ready || !token_valid(token) {
        return 0, false
    }

    hash := token_digest(token)

    for peer in cp.peers {
        if !peer.spectator && peer.token_hash == hash {
            return peer.seat, true
        }
    }

    return 0, false
}

checkpoint_destroy :: proc(cp: ^Checkpoint($S, $C, $A, $N)) {
    delete(cp.peers)
    delete(cp.actions)
    delete(cp.inputs)
    delete(cp.outcomes)
    delete(cp.banned)
    delete(cp.policy_data, cp.allocator)
    cp^ = {}
}

checkpoint_capture :: proc(
    s: ^Server($S, $C, $A, $E, $N),
    cp: ^Checkpoint(S, C, A, N),
    policy_id: u64 = 0,
    policy_data: []u8 = nil,
    allocator := context.allocator,
) -> Error {
    if !s.initialized || s.timeline.busy || !checkpoint_empty(cp) {
        return .Wrong_Phase
    }

    if (s.admission != nil) != (policy_id != 0) || len(policy_data) > 65536 {
        return .Checkpoint_Policy
    }

    if policy_id == 0 && len(policy_data) != 0 {
        return .Checkpoint_Policy
    }

    for peer in s.peers {
        if peer.phase == .Vacant {
            continue
        }

        if !hash_present(peer.token_hash) {
            return .Invalid_Checkpoint
        }
    }

    cp.allocator = allocator
    cp.frame, _ = r.current(&s.timeline)
    cp.header = {
        version    = CHECKPOINT_VERSION,
        protocol   = PROTOCOL_VERSION,
        content    = s.cfg.content,
        epoch      = s.cfg.epoch,
        contract   = s.contract,
        generation = s.generation,
        tick       = cp.frame.tick,
        local_seat = s.local_seat,
        joins      = s.joins,
        leaves     = s.leaves,
        fresh      = s.fresh,
        locked     = s.locked,
        policy_id  = policy_id,
    }
    cp.settings = checkpoint_settings(s.cfg)
    cp.held = s.held
    cp.held_views = s.held_views
    cp.peers = make([dynamic]Checkpoint_Peer, 0, MAX_PEERS, allocator)
    cp.actions = make([dynamic]Checkpoint_Action(A), 0, MAX_PEERS * ACTION_CAPACITY, allocator)
    cp.inputs = make([dynamic]Checkpoint_Input(C), 0, MAX_PEERS * int(s.cfg.max_future), allocator)
    cp.outcomes = make([dynamic]Checkpoint_Outcome, 0, MAX_PEERS * ACTION_CAPACITY, allocator)
    cp.banned = make([dynamic][32]u8, 0, s.banned_count, allocator)

    for peer, i in s.peers {
        if peer.phase == .Vacant {
            continue
        }

        append(
            &cp.peers,
            Checkpoint_Peer {
                index = u16(i),
                seat = peer.seat,
                spectator = peer.spectator,
                local = peer.local,
                active = peer.phase == .Running || peer.phase == .Pending,
                pending = peer.phase == .Pending,
                token_hash = peer.token_hash,
                generation = peer.generation,
                serial = peer.serial,
                action_received = peer.action_received,
                action_settled = peer.action_settled,
                incarnation = peer.incarnation,
            },
        )

        for j in 0 ..< peer.action_count {
            action := peer.actions[(peer.action_head + j) % ACTION_CAPACITY]
            append(
                &cp.actions,
                Checkpoint_Action(A){u16(i), action.sequence, action.tick, action.value, action.reason},
            )
        }

        for slot in s.inputs[i * s.cfg.history:(i + 1) * s.cfg.history] {
            if slot.tick > cp.frame.tick {
                append(&cp.inputs, Checkpoint_Input(C){u16(i), slot.tick, slot.value, slot.view})
            }
        }

        for j in 0 ..< peer.recent_count {
            append(&cp.outcomes, Checkpoint_Outcome{u16(i), peer.recent[(peer.recent_head + j) % ACTION_CAPACITY]})
        }
    }

    append(&cp.banned, ..s.banned[:s.banned_count])
    cp.policy_data = make([]u8, len(policy_data), allocator)
    copy(cp.policy_data, policy_data)
    cp.header.peers, cp.header.actions, cp.header.outcomes, cp.header.bans =
        u16(len(cp.peers)), u16(len(cp.actions)), u16(len(cp.outcomes)), u16(len(cp.banned))
    cp.header.inputs, cp.header.policy_bytes = u32(len(cp.inputs)), u32(len(cp.policy_data))
    cp.ready = true

    if !checkpoint_valid(cp, s.model) {
        checkpoint_destroy(cp)
        return .Invalid_Checkpoint
    }

    return .None
}

// Validation happens before changing the destination server. The checkpoint's
// settings are restored exactly; callers may explicitly retune afterward.
server_restore :: proc(
    s: ^Server($S, $C, $A, $E, $N),
    cp: ^Checkpoint(S, C, A, N),
    model: Model(S, C, A, E, N),
    wire: tr.Transport,
    options: Resume_Options,
    allocator := context.allocator,
) -> Error {
    if s.initialized || !checkpoint_valid(cp, model) {
        return .Invalid_Checkpoint
    }

    if options.epoch <= cp.header.epoch || int(options.local_seat) > N {
        return .Invalid_Config
    }

    if cp.header.policy_id != options.policy_id || (options.admission != nil) != (cp.header.policy_id != 0) {
        return .Checkpoint_Policy
    }

    found_local := options.local_seat == 0

    for peer in cp.peers {
        if !peer.spectator && peer.seat == options.local_seat {
            found_local = true
        }
    }

    if !found_local {
        return .Invalid_Input
    }

    cfg := checkpoint_config(cp.header, cp.settings)
    cfg.epoch = options.epoch

    if err := server_init(s, cp.frame, model, wire, cfg, allocator = allocator, permit = options.permit);
       err != .None {
        return err
    }

    if s.contract != cp.header.contract {
        server_destroy(s)
        return .Checkpoint_Contract
    }

    s.local_seat, s.generation = options.local_seat, cp.header.generation
    s.locked, s.banned_count = cp.header.locked, len(cp.banned)
    copy(s.banned[:], cp.banned[:])
    s.admission_user, s.admission = options.admission_user, options.admission
    s.joins, s.leaves, s.fresh = cp.header.joins, cp.header.leaves, cp.header.fresh
    s.held = cp.held
    s.held_views = cp.held_views

    for saved in cp.peers {
        peer := &s.peers[saved.index]
        peer^ = {
            phase           = .Disconnected,
            seat            = saved.seat,
            spectator       = saved.spectator,
            token_hash      = saved.token_hash,
            generation      = saved.generation,
            serial          = saved.serial,
            action_received = saved.action_received,
            action_settled  = saved.action_settled,
            incarnation     = saved.incarnation,
        }

        if !saved.spectator && saved.seat == options.local_seat {
            peer.local, peer.phase = true, .Running
            s.leaves &= ~(u64(1) << uint(saved.seat - 1))

            if !saved.active {
                s.joins |= u64(1) << uint(saved.seat - 1)
            }
        } else if saved.active && saved.seat != 0 && !options.retain_membership {
            s.leaves |= u64(1) << uint(saved.seat - 1)
            s.joins &= ~(u64(1) << uint(saved.seat - 1))
            s.fresh &= ~(u64(1) << uint(saved.seat - 1))
            s.held[saved.seat - 1] = model.neutral
        }
    }

    for saved in cp.actions {
        peer := &s.peers[saved.peer]
        reason, tick := saved.reason, saved.tick

        if !options.preserve_pending {
            reason, tick = .Disconnected, cp.frame.tick + 1
        }

        peer.actions[peer.action_count] = {
            sequence = saved.sequence,
            tick     = tick,
            value    = saved.value,
            reason   = reason,
        }
        peer.action_count += 1
    }

    if options.preserve_pending {
        for saved in cp.inputs {
            if s.peers[saved.peer].local {
                continue
            } // the promoted seat now samples local controls

            s.inputs[int(saved.peer) * cfg.history + int(saved.tick % u64(cfg.history))] = {
                saved.tick,
                saved.value,
                saved.view,
            }
        }
    }

    for saved in cp.outcomes {
        peer := &s.peers[saved.peer]
        peer.recent[peer.recent_count] = saved.outcome
        peer.recent_count += 1
    }

    return .None
}

checkpoint_valid :: proc(cp: ^Checkpoint($S, $C, $A, $N), model: Model(S, C, A, $E, N)) -> bool {
    return checkpoint_valid_protocol(cp, model, PROTOCOL_VERSION)
}

@(private)
checkpoint_valid_protocol :: proc(
    cp: ^Checkpoint($S, $C, $A, $N),
    model: Model(S, C, A, $E, N),
    protocol: u64,
) -> bool {
    #assert(N >= 1 && N <= 8)

    if !cp.ready ||
       cp.header.version != CHECKPOINT_VERSION ||
       cp.header.protocol != protocol ||
       cp.header.epoch == 0 ||
       cp.frame.tick != cp.header.tick ||
       cp.frame.tick == max(u64) ||
       cp.header.generation == max(u64) ||
       int(cp.header.local_seat) > N ||
       !config_valid(checkpoint_config(cp.header, cp.settings)) ||
       model.state_valid == nil ||
       !replication_config_valid(model.replication) ||
       !model.state_valid(cp.frame.state) {
        return false
    }

    if len(cp.peers) != int(cp.header.peers) ||
       len(cp.actions) != int(cp.header.actions) ||
       len(cp.inputs) != int(cp.header.inputs) ||
       len(cp.outcomes) != int(cp.header.outcomes) ||
       len(cp.banned) != int(cp.header.bans) ||
       len(cp.policy_data) != int(cp.header.policy_bytes) ||
       len(cp.peers) > MAX_PEERS ||
       len(cp.actions) > MAX_PEERS * ACTION_CAPACITY ||
       len(cp.inputs) > MAX_PEERS * int(cp.settings.max_future) ||
       len(cp.outcomes) > MAX_PEERS * ACTION_CAPACITY ||
       len(cp.banned) > 64 ||
       len(cp.policy_data) > 65536 {
        return false
    }

    if cp.header.policy_id == 0 && len(cp.policy_data) != 0 {
        return false
    }

    mask := (u64(1) << uint(N)) - 1

    if (cp.header.joins | cp.header.leaves | cp.header.fresh) & ~mask != 0 || cp.header.fresh & ~cp.header.joins != 0 {
        return false
    }

    if model.control_valid == nil || model.control_timing > .Latest_Observation {
        return false
    }

    for held in cp.held {
        if !model.control_valid(held) {
            return false
        }
    }

    for v in cp.held_views {
        if !view_time_valid(v, cp.frame.tick, cp.settings.max_view_span) {
            return false
        }
    }

    used: [MAX_PEERS]bool
    records: [MAX_PEERS]Checkpoint_Peer
    seats: [N + 1]bool
    counts, outcomes: [MAX_PEERS]int
    next: [MAX_PEERS]u64
    locals := 0

    for peer, i in cp.peers {
        if peer.index >= MAX_PEERS ||
           used[peer.index] ||
           int(peer.seat) > N ||
           !hash_present(peer.token_hash) ||
           peer.generation > cp.header.generation ||
           peer.action_settled > peer.action_received ||
           peer.action_received > max(u64) >> 8 ||
           peer.action_received - peer.action_settled > ACTION_CAPACITY {
            return false
        }

        if peer.spectator != (peer.seat == 0) ||
           (peer.spectator && (peer.action_received != 0 || peer.local)) ||
           (peer.pending && (!peer.active || peer.local)) ||
           peer.serial == max(u64) {
            return false
        }

        if peer.seat != 0 {
            if seats[peer.seat] {
                return false
            }

            seats[peer.seat] = true
        }

        for previous in cp.peers[:i] {
            if previous.token_hash == peer.token_hash {
                return false
            }
        }

        if peer.local {
            locals += 1

            if peer.seat != cp.header.local_seat || !peer.active {
                return false
            }
        }

        used[peer.index] = true
        records[peer.index] = peer
        next[peer.index] = peer.action_settled + 1
    }

    if locals != (cp.header.local_seat == 0 ? 0 : 1) {
        return false
    }

    for action in cp.actions {
        if action.peer >= MAX_PEERS ||
           !used[action.peer] ||
           action.sequence != next[action.peer] ||
           records[action.peer].spectator ||
           action.reason > .Disconnected ||
           action.reason == .Predicate ||
           action.tick == 0 ||
           (action.tick > cp.frame.tick && action.tick - cp.frame.tick > u64(cp.settings.max_future)) {
            return false
        }

        if action.reason == .None &&
           (model.action == nil || model.action_valid == nil || !model.action_valid(action.value)) {
            return false
        }

        next[action.peer] += 1
        counts[action.peer] += 1

        if counts[action.peer] > ACTION_CAPACITY {
            return false
        }
    }

    for peer in cp.peers {
        if next[peer.index] != peer.action_received + 1 {
            return false
        }
    }

    input_slots: [MAX_PEERS][1024]bool

    for input in cp.inputs {
        if input.peer >= MAX_PEERS ||
           !used[input.peer] ||
           input.tick <= cp.frame.tick ||
           records[input.peer].spectator ||
           records[input.peer].local ||
           input.tick - cp.frame.tick > u64(cp.settings.max_future) ||
           !model.control_valid(input.value) ||
           !view_time_valid(input.view, cp.frame.tick, cp.settings.max_view_span) {
            return false
        }

        // max_future < history, so two valid ticks collide in this ring slot only
        // when they are duplicates. Validation stays linear at the input limit.
        slot := input.tick % u64(cp.settings.history)

        if input_slots[input.peer][slot] {
            return false
        }

        input_slots[input.peer][slot] = true
    }

    for saved, i in cp.outcomes {
        if saved.peer >= MAX_PEERS ||
           !used[saved.peer] ||
           records[saved.peer].spectator ||
           saved.outcome.tick == 0 ||
           saved.outcome.tick > cp.frame.tick ||
           saved.outcome.sequence == 0 ||
           saved.outcome.sequence > records[saved.peer].action_settled ||
           saved.outcome.reason > .Disconnected ||
           saved.outcome.applied != (saved.outcome.reason == .None) {
            return false
        }

        outcomes[saved.peer] += 1

        if outcomes[saved.peer] > ACTION_CAPACITY {
            return false
        }

        settled := records[saved.peer].action_settled

        if saved.outcome.sequence != settled - min(settled, ACTION_CAPACITY) + u64(outcomes[saved.peer]) {
            return false
        }

        for previous in cp.outcomes[:i] {
            if previous.peer == saved.peer &&
               (previous.outcome.sequence >= saved.outcome.sequence || previous.outcome.tick > saved.outcome.tick) {
                return false
            }
        }
    }

    for peer in cp.peers {
        if u64(outcomes[peer.index]) != min(peer.action_settled, ACTION_CAPACITY) {
            return false
        }
    }

    for hash, i in cp.banned {
        if !hash_present(hash) {
            return false
        }

        for previous in cp.banned[:i] {
            if previous == hash {
                return false
            }
        }
    }

    return true
}

@(private)
checkpoint_empty :: proc(cp: ^Checkpoint($S, $C, $A, $N)) -> bool {
    return(
        !cp.ready &&
        cap(cp.peers) == 0 &&
        cap(cp.actions) == 0 &&
        cap(cp.inputs) == 0 &&
        cap(cp.outcomes) == 0 &&
        cap(cp.banned) == 0 &&
        len(cp.policy_data) == 0 \
    )
}

@(private)
hash_present :: proc(hash: [32]u8) -> bool {
    bits := u8(0)

    for b in hash {
        bits |= b
    }

    return bits != 0
}

@(private)
checkpoint_settings :: proc(c: Config) -> Checkpoint_Settings {
    return {
        c.hz,
        u32(c.history),
        c.lead,
        c.max_future,
        c.max_prediction,
        c.snapshot_every,
        c.watch_delay,
        c.timeout_ms,
        u32(c.packets_per_pump),
        u32(c.bytes_per_pump),
        u32(c.snapshot_history),
        c.delta_snapshots,
        u32(c.egress_bytes_per_second),
        u32(c.egress_bytes_per_pump),
        u32(c.unreliable_packet_limit),
        c.require_permit,
        c.max_rewind,
        c.max_view_span,
        c.view_slack,
    }
}

checkpoint_config :: proc(h: Checkpoint_Header, s: Checkpoint_Settings) -> Config {
    return {
        epoch = h.epoch,
        content = h.content,
        hz = s.hz,
        history = int(s.history),
        lead = s.lead,
        max_future = s.max_future,
        max_prediction = s.max_prediction,
        snapshot_every = s.snapshot_every,
        watch_delay = s.watch_delay,
        timeout_ms = s.timeout_ms,
        packets_per_pump = int(s.packets_per_pump),
        bytes_per_pump = int(s.bytes_per_pump),
        snapshot_history = int(s.snapshot_history),
        delta_snapshots = s.delta_snapshots,
        egress_bytes_per_second = int(s.egress_bytes_per_second),
        egress_bytes_per_pump = int(s.egress_bytes_per_pump),
        unreliable_packet_limit = int(s.unreliable_packet_limit),
        require_permit = s.require_permit,
        max_rewind = s.max_rewind,
        max_view_span = s.max_view_span,
        view_slack = s.view_slack,
    }
}
