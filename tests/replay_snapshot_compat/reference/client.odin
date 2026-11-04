package replay_net_legacy

import "core:math"
import "core:reflect"
import r "godot:replay"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import view "godot:replay/view"
import delta "godot:replay/delta"

client_init :: proc(
    c: ^Client($State, $Control, $Action, $Event, $Seats),
    model: Model(State, Control, Action, Event, Seats),
    wire: tr.Transport,
    token: Token,
    spectator: bool = false,
    authority: tr.Peer_Id = 1,
    cfg := DEFAULT_CONFIG,
    allocator := context.allocator,
    permit: Permit = {},
    incarnation: u64 = 0,
) -> Error {
    #assert(Seats >= 1 && Seats <= 8)

    if c.initialized || !config_valid(cfg) || authority == 0 || !token_valid(token) {
        return .Invalid_Config
    }

    if cfg.require_permit && permit.allow == nil {
        return .Fenced
    }

    if (model.step == nil && model.step_view == nil) ||
       model.control_valid == nil ||
       model.hold == nil ||
       model.state_valid == nil ||
       !group_config_valid(model.group) ||
       !replication_config_valid(model.replication) ||
       model.control_timing > .Latest_Observation {
        return .Invalid_Model
    }

    if model.replication.id != 0 && !spectator && model.group.id == 0 {
        return .Invalid_Model
    }

    c.allocator, c.model, c.cfg, c.wire, c.token, c.spectator, c.authority =
        allocator, model, cfg, wire, token, spectator, authority
    c.permit = permit
    c.incarnation = incarnation

    if !codecs_init(&c.codecs, State, Control, Action, Event, Seats, allocator, model.replication.id != 0) {
        client_destroy(c)
        return .Invalid_Model
    }

    if !spectator && c.codecs.state.excluded_fields != 0 && model.replication.id == 0 {
        client_destroy(c)
        return .Invalid_Model
    }

    c.contract = contract_hash(&c.codecs, cfg, Seats, model.control_timing, replication = model.replication.id)

    thunk := proc(state: ^State, input: Batch(Control, Action, Seats), ctx: ^r.Step(Net_Event(Event))) {
        network_step(state, input, ctx)
    }

    if r.init(
           &c.timeline,
           r.Frame(State){},
           thunk,
           cfg = {cfg.history, WIRE_EVENTS},
           epoch = cfg.epoch,
           allocator = allocator,
           user = &c.model,
       ) !=
       .None {
        client_destroy(c)
        return .Invalid_Model
    }

    if view.journal_init(
           &c.journal,
           epoch = cfg.epoch,
           cfg = {cfg.history, WIRE_EVENTS, cfg.history * WIRE_EVENTS * 2},
           allocator = allocator,
       ) !=
       .None {
        client_destroy(c)
        return .Invalid_Model
    }

    client_install_policy(c)
    c.facts = make([]Facts_Packet(Event), cfg.history, allocator)
    c.observed = make([]r.Frame(State), cfg.history, allocator)
    c.observed_valid = make([]bool, cfg.history, allocator)
    c.observed_ids = make([]u64, cfg.history, allocator)
    c.rxb = make([]u8, tr.MAX_PACKET_BYTES, allocator)
    c.txb = make([]u8, tr.MAX_PACKET_BYTES, allocator)
    c.input_scratch = make([]u8, c.codecs.inputs.wire_size, allocator)
    c.input_sent = make([]Input_Sent, cfg.history, allocator)

    if !delta.cache_init(&c.snapshot_rx, c.codecs.snapshot.wire_size, cfg.snapshot_history, allocator) {
        client_destroy(c)
        return .Invalid_Config
    }

    c.snapshot_scratch = make([]u8, c.codecs.snapshot.wire_size, allocator)
    c.snapshot_ticks = make([]u64, cfg.snapshot_history, allocator)
    c.phase, c.initialized = .Joining, true
    c.lead_ticks, c.clock_scale = cfg.lead, 1

    for &held in c.held {
        held = model.neutral
    }

    return .None
}

client_destroy :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats)) {
    r.destroy(&c.timeline)
    view.journal_destroy(&c.journal)
    codecs_destroy(&c.codecs)
    delete(c.facts, c.allocator)
    delete(c.observed, c.allocator)
    delete(c.observed_valid, c.allocator)
    delete(c.observed_ids, c.allocator)
    delete(c.rxb, c.allocator)
    delete(c.txb, c.allocator)
    delete(c.input_scratch, c.allocator)
    delete(c.input_sent, c.allocator)
    delta.cache_destroy(&c.snapshot_rx)
    delete(c.snapshot_scratch, c.allocator)
    delete(c.snapshot_ticks, c.allocator)
    c^ = {}
}

// Reuse the stable token and outstanding action IDs on a new connection.
client_reconnect :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats), wire: tr.Transport) -> Error {
    if !c.initialized {
        return .Not_Initialized
    }

    c.wire, c.phase, c.hello_sent, c.time_set = wire, .Joining, false, false
    c.rejection = .None
    client_timing_reset(c)
    return .None
}

client_issue :: proc(
    c: ^Client($State, $Control, $Action, $Event, $Seats),
    action: Action,
) -> (
    sequence: u64,
    error: Error,
) {
    if !c.initialized || c.phase != .Running || c.spectator {
        return 0, .Wrong_Phase
    }

    if !permitted(c.cfg.require_permit, c.permit, c.cfg.epoch) {
        return 0, .Fenced
    }

    if c.model.action == nil || c.model.action_valid == nil || !c.model.action_valid(action) {
        return 0, .Invalid_Input
    }

    if c.action_count + c.outcome_count >= ACTION_CAPACITY || c.next_action >= max(u64) >> 8 {
        return 0, .Capacity
    }

    due := c.timeline.head + 1

    for existing in c.actions[:c.action_count] {
        if !existing.predicted {
            due = max(due, existing.tick + 1)
        }
    }

    if due - c.timeline.head > u64(c.cfg.max_future) {
        return 0, .Capacity
    }

    c.next_action += 1
    c.actions[c.action_count] = {
        sequence = c.next_action,
        tick     = due,
        value    = action,
    }
    c.action_count += 1
    client_send_actions(c, false)
    return c.next_action, .None
}

client_step :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats), control: Control) -> Error {
    if !c.initialized || c.phase != .Running || c.spectator {
        return .Wrong_Phase
    }

    if !permitted(c.cfg.require_permit, c.permit, c.cfg.epoch) {
        return .Fenced
    }

    if !c.model.control_valid(control) {
        return .Invalid_Input
    }

    if c.timeline.head - c.timeline.confirmed >= u64(c.cfg.max_prediction) {
        c.stats.stalls += 1
        client_resync(c, .Prediction_Limit, c.timeline.head)
        return .Capacity
    }

    batch := Batch(Control, Action, Seats) {
        controls = c.held,
    }

    if c.model.group.id != 0 {
        batch.prediction_group, batch.prediction_seat = c.model.group.id, c.seat
    }

    for &value, i in batch.controls {
        if i + 1 != int(c.seat) {
            value = c.model.group.id != 0 ? c.model.neutral : c.model.hold(value)
        }
    }

    batch.controls[c.seat - 1] = control
    batch.stamps[c.seat - 1] = c.presented

    if c.presented.valid {
        batch.views[c.seat - 1] = {c.presented.from_tick, c.presented.to_tick, c.presented.fraction, .Historical}
    }

    tick := c.timeline.head + 1
    predicted_index := -1

    for &action, i in c.actions[:c.action_count] {
        if !action.predicted && action.tick <= tick {
            batch.has_action[c.seat - 1] = true
            batch.actions[c.seat - 1] = action.value
            batch.sequences[c.seat - 1] = action.sequence
            action.predicted = true
            predicted_index = i
            break
        }
    }

    gate: r.Commit_Gate

    if c.cfg.require_permit {
        gate = c.permit
    }

    started, timed := profile_start(c.profile_clock)
    result := r.advance(&c.timeline, batch, gate)
    profile_finish(&c.profile_metrics, .Advance, c.profile_clock, started, timed, c.profile_user, c.profile_sample)

    if result.error == .Commit_Rejected {
        if predicted_index >= 0 {
            c.actions[predicted_index].predicted = false
        }

        return .Fenced
    }

    if result.error != .None {
        c.phase = .Failed
        return .Simulation
    }

    c.held = batch.controls

    if err := client_sync_predicted(c, tick); err != .None {
        return err
    }

    client_send_inputs(c)
    return .None
}

client_pump :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats), now_ms: u64) -> Error {
    if !c.initialized {
        return .Not_Initialized
    }

    started, timed := profile_start(c.profile_clock)
    defer profile_finish(&c.profile_metrics, .Pump, c.profile_clock, started, timed, c.profile_user, c.profile_sample)

    if !permitted(c.cfg.require_permit, c.permit, c.cfg.epoch) {
        tr.poll(&c.wire)
        return .Fenced
    }

    if c.time_set && now_ms < c.now {
        return .Invalid_Time
    }

    dt := c.time_set ? f64(now_ms - c.now) / 1000 : 0

    if !c.time_set {
        c.started, c.last_received = now_ms, now_ms
    }

    // A local pump stall contaminates outstanding turnaround samples. Fresh
    // submissions will calibrate again; the current bootstrap bound is retained.
    if c.time_set && now_ms - c.now > max(u64(250), (u64(c.cfg.snapshot_every) + 2) * 1000 / u64(c.cfg.hz)) {
        client_timing_reset(c)
    }

    c.now, c.time_set = now_ms, true
    tr.poll(&c.wire)

    if tr.status(&c.wire) == .Disconnected {
        c.phase = .Disconnected
        return .None
    }

    if c.phase == .Joining && (!c.hello_sent || c.now - c.last_hello >= 500) {
        packet := Hello_Packet{c.contract, c.token, c.spectator, c.now, c.incarnation}

        if client_send(c, &c.codecs.hello, .Hello, packet, 0, .Reliable) == .Sent {
            c.last_hello = c.now
            c.hello_sent = true
        }
    }

    if c.phase == .Resyncing && (!c.hello_sent || c.now - c.last_hello >= 500) {
        packet := Request_Packet{c.generation, c.serial, c.request_sequence, c.now}

        if client_send(c, &c.codecs.request, .Resync, packet, c.timeline.head, .Reliable) == .Sent {
            c.last_hello = c.now
            c.hello_sent = true
        }
    }

    bytes := 0

    for _ in 0 ..< c.cfg.packets_per_pump {
        packet := tr.receive(&c.wire, c.rxb)

        if packet.state == .Empty || packet.state == .Disconnected {
            break
        }

        if packet.state != .Received || packet.from != c.authority {
            c.stats.rejected_packets += 1
            continue
        }

        bytes += packet.count
        c.stats.rx_packets += 1
        c.stats.rx_bytes += u64(packet.count)

        if bytes > c.cfg.bytes_per_pump {
            c.stats.rejected_packets += 1
            break
        }

        if !permitted(c.cfg.require_permit, c.permit, c.cfg.epoch) {
            return .Fenced
        }

        client_receive(c, c.rxb[:packet.count])
    }

    if c.phase == .Running {
        catchups := c.stats.snapshot_catchups

        if err := client_apply_snapshot(c); err != .None {
            return err
        }

        latest := c.authority_frame.tick
        target := f64(latest > u64(c.cfg.watch_delay) ? max(latest - u64(c.cfg.watch_delay), c.baseline) : c.baseline)
        scale := clamp(1 + (target - c.watch_clock) * 0.05, 0.9, 1.1)
        c.watch_clock = min(c.watch_clock + dt * f64(c.cfg.hz) * scale, f64(latest))
        // A sparse delivery/local stall must not leave the view slowly chasing
        // old snapshots for seconds. Keep it within the declared presentation
        // slack, then skip an interpolation gap wider than the server accepts.
        before_catchup := c.watch_clock
        lag := u64(c.cfg.watch_delay) + u64(c.cfg.view_slack)
        floor := latest > lag ? max(latest - lag, c.baseline) : c.baseline
        c.watch_clock = max(c.watch_clock, f64(floor))

        if a, b, _, found := client_observed(c); found && b.tick - a.tick > u64(c.cfg.max_view_span) {
            c.watch_clock = f64(b.tick)
        }

        if c.watch_clock > before_catchup {
            c.stats.watch_catchups += 1
        }

        watch := max(c.journal.watch_tick, u64(c.watch_clock))

        if err := view.advance_time(&c.journal, c.journal.confirmed, watch); err != .None {
            return client_presentation_failure(c, .Watch, watch, err)
        }

        // Catch-up may confirm a long range containing watched effects. Mature
        // those retained entries before bootstrap prediction wraps their slots.
        if c.stats.snapshot_catchups != catchups {
            if err := client_bootstrap(c); err != .None {
                return err
            }
        }

        if c.now - c.last_action_send >= 500 {
            client_send_actions(c, true)
            c.last_action_send = c.now
        }

        if c.now - c.last_heartbeat >= 500 {
            client_send(
                c,
                &c.codecs.request,
                .Heartbeat,
                Request_Packet{generation = c.generation, serial = c.serial},
                c.timeline.head,
                .Reliable,
            )
            c.last_heartbeat = c.now
            client_ack_snapshot(c)
        }
    }

    if c.phase != .Rejected && c.now - c.last_received > c.cfg.timeout_ms {
        c.phase = .Disconnected
    }

    return .None
}

client_outcomes :: proc(
    c: ^Client($State, $Control, $Action, $Event, $Seats),
    dst: []Action_Outcome,
    recovered: []bool = nil,
) -> int {
    n := min(len(dst), c.outcome_count)

    for i in 0 ..< n {
        index := (c.outcome_head + i) % ACTION_CAPACITY
        dst[i] = c.outcomes[index]

        if i < len(recovered) {
            recovered[i] = c.outcome_recovered[index]
        }
    }

    c.outcome_head = (c.outcome_head + n) % ACTION_CAPACITY
    c.outcome_count -= n
    return n
}

// Authoritative sparse frames for watched views. Never use predicted history as
// an opponent's observed truth; interpolation stays entirely in presentation.
client_observed :: proc(
    c: ^Client($State, $Control, $Action, $Event, $Seats),
) -> (
    a, b: r.Frame(State),
    alpha: f32,
    ok: bool,
) {
    if c.phase != .Running {
        return
    }

    lower, upper := -1, -1

    for frame, i in c.observed {
        if !c.observed_valid[i] {
            continue
        }

        if f64(frame.tick) <= c.watch_clock && (lower < 0 || frame.tick > c.observed[lower].tick) {
            lower = i
        }

        if f64(frame.tick) >= c.watch_clock && (upper < 0 || frame.tick < c.observed[upper].tick) {
            upper = i
        }
    }

    if lower < 0 {
        lower = upper
    }

    if upper < 0 {
        upper = lower
    }

    if lower < 0 {
        return
    }

    a = c.observed[lower]
    b = c.observed[upper]

    if b.tick > a.tick {
        alpha = f32(clamp((c.watch_clock - f64(a.tick)) / f64(b.tick - a.tick), 0, 1))
    }

    return a, b, alpha, true
}

@(private)
client_receive :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats), bytes: []u8) {
    meta, _, report := sc.inspect(bytes)

    if report.error != .None {
        c.stats.rejected_packets += 1
        return
    }

    expected := sc.Envelope_Meta {
        kind    = meta.kind,
        epoch   = c.cfg.epoch,
        content = c.cfg.content,
    }

    #partial switch Kind(meta.kind) {
    case .Reject:
        if c.phase != .Joining {
            return
        }

        packet: Reject_Packet
        _, report = sc.unpack(&c.codecs.reject, &packet, bytes, expected)

        if report.error != .None {
            c.stats.rejected_packets += 1
            return
        }

        c.phase, c.rejection = .Rejected, packet.reason
    case .Welcome:
        packet: Welcome_Packet(State, Control, Seats)
        _, report = sc.unpack(&c.codecs.welcome, &packet, bytes, expected)

        if report.error != .None ||
           packet.generation == 0 ||
           packet.serial == 0 ||
           int(packet.seat) > Seats ||
           (packet.seat == 0) != c.spectator ||
           packet.frame.tick != meta.tick ||
           packet.completed_count > ACTION_CAPACITY ||
           !replica_valid(c.model, packet.frame.state, packet.held, Recipient{packet.seat, c.spectator}) ||
           !welcome_valid(packet) {
            c.stats.rejected_packets += 1
            return
        }

        if packet.generation < c.generation ||
           (packet.generation == c.generation && packet.serial <= c.serial && c.phase != .Joining) {
            return
        }

        client_welcome(c, packet)
    case .Removed:
        packet: Removed_Packet
        _, report = sc.unpack(&c.codecs.removed, &packet, bytes, expected)

        if report.error != .None || packet.generation != c.generation || packet.serial != c.serial {
            c.stats.rejected_packets += 1
            return
        }

        c.phase, c.rejection = .Rejected, packet.reason
    case .Facts:
        if c.phase != .Running {
            return
        }

        packet: Facts_Packet(Event)

        if !unpack_facts(&c.codecs, &packet, bytes, expected) ||
           packet.generation != c.generation ||
           packet.serial != c.serial ||
           packet.tick != meta.tick ||
           packet.count > WIRE_EVENTS {
            c.stats.rejected_packets += 1
            return
        }

        if packet.tick <= c.baseline || packet.tick <= c.journal.confirmed {
            return
        }

        if packet.tick - c.journal.confirmed >= u64(c.cfg.history) {
            client_resync(c, .Facts_Overflow, packet.tick)
            return
        }

        for occurrence, i in packet.events[:packet.count] {
            if occurrence.id.tick != packet.tick || occurrence.id.epoch != c.cfg.epoch {
                c.stats.rejected_packets += 1
                return
            }

            for prior in packet.events[:i] {
                if prior.id == occurrence.id {
                    c.stats.rejected_packets += 1
                    return
                }
            }
        }

        slot := &c.facts[packet.tick % u64(c.cfg.history)]

        if slot.tick == packet.tick && !reflect.equal(slot^, packet) {
            c.stats.rejected_packets += 1
            return
        }

        slot^ = packet

        for c.facts_contiguous < max(u64) {
            next := c.facts_contiguous + 1

            if c.facts[next % u64(c.cfg.history)].tick != next {
                break
            }

            c.facts_contiguous = next
        }

        c.last_received = c.now
    case .Snapshot, .Snapshot_Delta:
        if c.phase != .Running {
            return
        }

        client_snapshot(c, bytes, expected, meta.kind == u16(Kind.Snapshot_Delta))
    case:
        c.stats.rejected_packets += 1
    }
}

@(private)
client_welcome :: proc(
    c: ^Client($State, $Control, $Action, $Event, $Seats),
    packet: Welcome_Packet(State, Control, Seats),
) {
    packet := packet
    changing_epoch := c.recovering

    if changing_epoch && c.journal.queue_count != 0 {
        c.stats.rejected_packets += 1
        return
    }

    if (c.phase == .Joining || c.phase == .Resyncing) && packet.echo_ms <= c.now {
        rtt := min(c.now - packet.echo_ms, c.cfg.timeout_ms)
        measured := u32((rtt * u64(c.cfg.hz) + 999) / 1000) + 4
        c.lead_ticks = clamp(
            max(measured, c.cfg.lead),
            c.cfg.lead,
            min(c.cfg.max_future - 2, c.cfg.max_prediction - 2),
        )
    }

    prediction, projected := group_frame(c.model, packet.frame, packet.seat, c.spectator)

    if !projected {
        c.phase = .Failed
        return
    }

    if r.reset_checkpoint(&c.timeline, prediction, c.cfg.epoch) != .None {
        c.stats.rejected_packets += 1
        return
    }

    if changing_epoch {
        client_reconcile_actions(c, packet)
    } else {
        for outcome in packet.completed[:packet.completed_count] {
            client_outcome(c, outcome, true)
        }

        client_retire(c, packet.action_settled)
        c.next_action = max(c.next_action, packet.action_received)
        c.last_outcome = max(c.last_outcome, packet.action_settled)
    }

    client_timing_reset(c)
    c.generation, c.serial, c.seat = packet.generation, packet.serial, packet.seat
    c.baseline, c.facts_contiguous = packet.frame.tick, packet.frame.tick
    c.authority_frame = packet.frame
    c.held = packet.held
    c.watch_clock = f64(packet.frame.tick)
    c.has_pending = false
    c.presented = {}
    c.correction = {}
    delta.cache_clear(&c.snapshot_rx)
    c.snapshot_latest, c.snapshot_latest_hash, c.baseline_request_id = 0, 0, 0

    for &fact in c.facts {
        fact = {}
    }

    for &valid in c.observed_valid {
        valid = false
    }

    client_note_observed(c, packet.frame)

    if changing_epoch {
        if view.journal_reset(&c.journal, c.cfg.epoch, packet.frame.tick) != .None {
            c.phase = .Failed
            return
        }
    } else {
        // All still-pending outcomes need the new presentation route after
        // this journal is discarded, including facts queued before the reset.
        for i in 0 ..< c.outcome_count {
            c.outcome_recovered[(c.outcome_head + i) % ACTION_CAPACITY] = true
        }

        view.journal_destroy(&c.journal)
        view.journal_init(
            &c.journal,
            epoch = c.cfg.epoch,
            baseline = packet.frame.tick,
            cfg = {c.cfg.history, WIRE_EVENTS, c.cfg.history * WIRE_EVENTS * 2},
            allocator = c.allocator,
        )
    }

    client_install_policy(c)
    c.phase, c.last_received = .Running, c.now
    c.has_world = true
    c.view_reset += 1

    // Bootstrap lead with held neutral inputs, without sampling fresh action edges
    // into ticks that are already in transit behind the authority.
    if err := client_bootstrap(c); err != .None && err != .Fenced {
        c.phase = .Failed
        return
    }

    if !changing_epoch {
        for &action in c.actions[:c.action_count] {
            action.sent = false
        }

        client_send_actions(c, false)
    }
}

@(private)
client_bootstrap :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats)) -> Error {
    if c.spectator {
        return .None
    }

    for _ in 0 ..< c.lead_ticks {
        batch := Batch(Control, Action, Seats) {
            controls = c.held,
        }

        if c.model.group.id != 0 {
            batch.prediction_group, batch.prediction_seat = c.model.group.id, c.seat
        }

        for &control, i in batch.controls {
            control = c.model.group.id != 0 && i + 1 != int(c.seat) ? c.model.neutral : c.model.hold(control)
        }

        gate: r.Commit_Gate

        if c.cfg.require_permit {
            gate = c.permit
        }

        result := r.advance(&c.timeline, batch, gate)

        if result.error == .Commit_Rejected {
            return .Fenced
        }

        if result.error != .None {
            return .Simulation
        }

        c.held = batch.controls

        if err := client_sync_predicted(c, c.timeline.head); err != .None {
            return err
        }
    }

    return .None
}

@(private)
client_apply_snapshot :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats)) -> Error {
    if !c.has_pending || c.pending.frame.tick > c.facts_contiguous {
        // Reliable facts and unordered snapshots can arrive at different rates.
        // A newer incomplete snapshot must not starve an older usable correction.
        best := -1

        for id, i in c.snapshot_rx.ids {
            tick := c.snapshot_ticks[i]

            if id != 0 &&
               tick > c.timeline.confirmed &&
               tick <= c.facts_contiguous &&
               (best < 0 || tick > c.snapshot_ticks[best]) {
                best = i
            }
        }

        if best < 0 {
            return .None
        }

        bytes, _, found := delta.cache_find(&c.snapshot_rx, c.snapshot_rx.ids[best])

        if !found || sc.decode(&c.codecs.snapshot, &c.pending, bytes).error != .None {
            return .Invalid_Frame
        }

        c.has_pending = true
    }

    truth := c.pending.frame

    if truth.tick <= c.journal.confirmed {
        c.has_pending = false
        return .None
    }

    previous := c.journal.confirmed
    ahead := !c.spectator && truth.tick > c.timeline.head
    forecast := Remote_Forecast(Control, Seats) {
        held    = c.pending.held,
        seat    = c.seat,
        hold    = c.model.hold,
        grouped = c.model.group.id != 0,
        neutral = c.model.neutral,
    }

    if !c.spectator && truth.tick > c.timeline.confirmed {
        prediction, projected := group_frame(c.model, truth, c.seat, false)

        if !projected {
            c.phase = .Failed
            return .Invalid_Model
        }

        if ahead {
            // Complete state plus contiguous retained facts is sufficient to catch
            // up after a short local stall. Preserve the event journal and queues.
            if r.reset_checkpoint(&c.timeline, prediction, c.cfg.epoch) != .None {
                return .Simulation
            }

            c.stats.snapshot_catchups += 1
            c.view_reset += 1
            c.correction = {}
        } else {
            before, _ := r.current(&c.timeline)
            fact := &c.facts[truth.tick % u64(c.cfg.history)]
            rewrite := r.Input_Rewrite(Batch(Control, Action, Seats)) {
                user = &forecast,
                apply = proc(
                    user: rawptr,
                    tick: u64,
                    original: Batch(Control, Action, Seats),
                ) -> Batch(Control, Action, Seats) {
                    f := cast(^Remote_Forecast(Control, Seats))user
                    input := original

                    for &control, i in input.controls {
                        if i + 1 != int(f.seat) {
                            f.held[i] = f.grouped ? f.neutral : f.hold(f.held[i])
                            control = f.held[i]
                        }
                    }

                    return input // local controls, action IDs and aiming context stay exact
                },
            }
            started, timed := profile_start(c.profile_clock)
            result := r.correct(&c.timeline, prediction, fact.events[:fact.count], rewrite)
            profile_replay(
                &c.stats,
                c.profile_clock,
                started,
                timed,
                result.steps,
                &c.profile_metrics,
                c.profile_user,
                c.profile_sample,
            )

            if result.error == .History_Missing {
                client_resync(c, truth.tick > c.timeline.head ? .Snapshot_Ahead : .History_Missing, truth.tick)
                return .None
            }

            if result.error != .None {
                c.phase = .Failed
                return .Simulation
            }

            c.stats.corrections += 1
            c.stats.replayed_ticks += u64(result.steps)
            after, _ := r.current(&c.timeline)
            c.correction = {c.stats.corrections, truth.tick, before, after, u32(result.steps)}
        }
    } else if c.spectator {
        if r.reset_checkpoint(&c.timeline, truth, c.cfg.epoch) != .None {
            return .Simulation
        }
    }

    for tick := previous + 1; tick <= truth.tick; tick += 1 {
        fact := &c.facts[tick % u64(c.cfg.history)]

        if fact.tick != tick {
            client_resync(c, .Facts_Missing, tick)
            return .None
        }

        if err := view.sync_tick(&c.journal, tick, fact.events[:fact.count]); err != .None {
            return client_presentation_failure(c, .Authority_Batch, tick, err)
        }

        for occurrence in fact.events[:fact.count] {
            e := occurrence.value

            if e.kind == .Action_Result && e.seat == c.seat {
                client_outcome(c, Action_Outcome{e.sequence, tick, e.applied, e.reason})
            }
        }
    }

    if err := view.advance_time(&c.journal, truth.tick, c.journal.watch_tick); err != .None {
        return client_presentation_failure(c, .Confirmation, truth.tick, err)
    }

    for tick := truth.tick + 1; tick <= c.timeline.head; tick += 1 {
        if err := client_sync_predicted(c, tick); err != .None {
            return err
        }
    }

    c.authority_frame = truth
    c.held = forecast.held
    client_input_feedback(c, c.pending.input_newest, truth.tick)
    client_note_observed(c, truth, c.pending.snapshot_id)
    client_retire(c, c.pending.action_settled)
    c.has_pending = false
    // The pump advances the watched clock before rebuilding an ahead snapshot's
    // prediction lead; otherwise its ring may overwrite unpresented history.
    return .None
}

@(private)
Remote_Forecast :: struct($C: typeid, $N: int) {
    held:    [N]C,
    seat:    u16,
    hold:    proc(c: C) -> C,
    grouped: bool,
    neutral: C,
}

@(private)
client_sync_predicted :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats), tick: u64) -> Error {
    storage: [WIRE_EVENTS]r.Occurrence(Net_Event(Event))
    n, err := r.copy_events(&c.timeline, tick, storage[:])

    if err != .None {
        return .Simulation
    }

    if err := view.sync_tick(&c.journal, tick, storage[:n]); err != .None {
        return client_presentation_failure(c, .Predicted_Batch, tick, err)
    }

    return .None
}

@(private)
client_send_inputs :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats)) {
    if c.model.control_timing == .Latest_Observation {
        if input, ok := r.read_input(&c.timeline, c.timeline.head); ok {
            packet := Observation_Packet(Control) {
                c.generation,
                c.serial,
                {c.timeline.head, input.controls[c.seat - 1], input.stamps[c.seat - 1]},
            }
            client_send(c, &c.codecs.observation, .Observation, packet, c.timeline.head, .Unreliable)
        }

        return
    }

    packet := Inputs_Packet(Control) {
        generation = c.generation,
        serial     = c.serial,
    }

    for &sample in packet.samples {
        sample.value = c.model.neutral
    }

    first := max(c.timeline.confirmed + 1, c.timeline.head >= INPUT_WINDOW ? c.timeline.head - INPUT_WINDOW + 1 : 1)

    for tick := first; tick <= c.timeline.head; tick += 1 {
        if input, ok := r.read_input(&c.timeline, tick); ok {
            packet.samples[packet.count] = {tick, input.controls[c.seat - 1], input.stamps[c.seat - 1]}
            packet.count += 1
        }
    }

    if packet.count > 0 {
        client_send_input_packet(c, packet)
    }
}

@(private)
client_send_input_packet :: proc(c: ^Client($S, $C, $A, $E, $N), packet: Inputs_Packet(C)) {
    if !permitted(c.cfg.require_permit, c.permit, c.cfg.epoch) {
        return
    }

    if sc.encode(&c.codecs.inputs, packet, c.input_scratch).error != .None {
        return
    }

    meta := sc.Envelope_Meta {
        kind    = u16(Kind.Inputs_Compact),
        epoch   = c.cfg.epoch,
        tick    = c.timeline.head,
        content = c.cfg.content,
    }
    n, compact := compact_inputs_encode(&c.codecs, c.input_scratch, packet.count, c.txb[sc.HEADER_BYTES:])

    if !compact || n >= len(c.input_scratch) {
        meta.kind = u16(Kind.Inputs)
        n = len(c.input_scratch)

        if sc.pack_bytes(c.codecs.inputs.fingerprint, meta, c.input_scratch, c.txb).error != .None {
            return
        }
    } else if sc.pack_bytes(c.codecs.inputs.fingerprint, meta, c.txb[sc.HEADER_BYTES:sc.HEADER_BYTES + n], c.txb).error !=
       .None {
        return
    }

    bytes := c.txb[:sc.HEADER_BYTES + n]

    if tr.send(&c.wire, c.authority, .Unreliable, bytes) == .Sent {
        c.stats.tx_packets += 1
        c.stats.tx_bytes += u64(len(bytes))

        for i in 0 ..< int(packet.count) {
            client_note_input_sent(c, packet.samples[i].tick)
        }
    }
}

@(private)
client_send_actions :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats), retry: bool) {
    if c.phase != .Running {
        return
    }

    for &action in c.actions[:c.action_count] {
        if action.sent && !retry {
            continue
        }

        packet := Action_Packet(Action){c.generation, c.serial, action.sequence, action.tick, action.value}

        if client_send(c, &c.codecs.action, .Action, packet, action.tick, .Reliable) == .Sent {
            action.sent = true
        } else {
            break
        }
    }
}

@(private)
client_send :: proc(
    c: ^Client($State, $Control, $Action, $Event, $Seats),
    schema: ^sc.Schema,
    kind: Kind,
    value: $Packet,
    tick: u64,
    channel: tr.Channel,
) -> tr.Send_Result {
    if !permitted(c.cfg.require_permit, c.permit, c.cfg.epoch) {
        return .Backpressure
    }

    meta := sc.Envelope_Meta {
        kind    = u16(kind),
        epoch   = c.cfg.epoch,
        tick    = tick,
        content = c.cfg.content,
    }

    if sc.pack(schema, value, meta, c.txb).error != .None {
        return .Invalid
    }

    bytes := c.txb[:sc.HEADER_BYTES + schema.wire_size]
    result := tr.send(&c.wire, c.authority, channel, bytes)

    if result == .Sent {
        c.stats.tx_packets += 1
        c.stats.tx_bytes += u64(len(bytes))
    }

    return result
}

@(private)
client_resync :: proc(
    c: ^Client($State, $Control, $Action, $Event, $Seats),
    reason: Resync_Reason,
    incoming_tick: u64,
) {
    if c.phase == .Resyncing {
        return
    }

    c.phase, c.hello_sent, c.has_pending = .Resyncing, false, false
    c.request_sequence += 1
    c.stats.resyncs += 1
    c.resync_notice = {
        c.stats.resyncs,
        reason,
        c.timeline.head,
        c.journal.confirmed,
        c.facts_contiguous,
        incoming_tick,
        c.now,
    }
}

@(private)
client_note_observed :: proc(
    c: ^Client($State, $Control, $Action, $Event, $Seats),
    frame: r.Frame(State),
    id: u64 = 0,
) {
    index := int(frame.tick % u64(c.cfg.history))
    c.observed[index] = frame
    c.observed_valid[index] = true
    c.observed_ids[index] = id
}

@(private)
client_retire :: proc(c: ^Client($State, $Control, $Action, $Event, $Seats), through: u64) {
    kept := 0

    for action in c.actions[:c.action_count] {
        if action.sequence > through {
            c.actions[kept] = action
            kept += 1
        }
    }

    c.action_count = kept
}

@(private)
client_outcome :: proc(
    c: ^Client($State, $Control, $Action, $Event, $Seats),
    outcome: Action_Outcome,
    recovered: bool = false,
) {
    if outcome.sequence <= c.last_outcome {
        return
    }

    wanted := false

    for action in c.actions[:c.action_count] {
        if action.sequence == outcome.sequence {
            wanted = true
            break
        }
    }

    if wanted && c.outcome_count < ACTION_CAPACITY {
        index := (c.outcome_head + c.outcome_count) % ACTION_CAPACITY
        c.outcomes[index] = outcome
        c.outcome_recovered[index] = recovered
        c.outcome_count += 1
    }

    c.last_outcome = outcome.sequence
}

@(private)
set_observer_policy :: proc(j: ^view.Journal(Net_Event($Event))) {
    policy := proc(event: Net_Event(Event)) -> view.Policy {
        return .Watched
    }

    view.journal_set_policy(j, policy)
}

// Local effects answer prediction; remote effects mature at the same observed
// clock used by client_present. Gameplay ownership comes from Model.event_owner.
client_remote_observed :: proc(c: ^Client($S, $C, $A, $E, $N)) {
    c.mixed_presentation = true
    client_install_policy(c)
}

@(private)
client_install_policy :: proc(c: ^Client($S, $C, $A, $E, $N)) {
    c.journal.policy, c.journal.context_policy, c.journal.policy_user = nil, nil, nil

    if c.model.event_policy == nil && !c.mixed_presentation {
        if c.spectator {
            set_observer_policy(&c.journal)
        }

        return
    }

    c.journal.policy_user = c
    c.journal.context_policy = proc(user: rawptr, event: Net_Event(E)) -> view.Policy {
        client := cast(^Client(S, C, A, E, N))user

        if client.spectator {
            return .Watched
        }

        policy := view.Policy.Speculative

        if event.kind == .Gameplay && client.model.event_policy != nil {
            policy = client.model.event_policy(event.value)
        }

        if policy == .Speculative && client.mixed_presentation && event.seat != client.seat {
            return .Watched
        }

        return policy
    }
}

@(private)
client_presentation_failure :: proc(
    c: ^Client($S, $C, $A, $E, $N),
    stage: Presentation_Stage,
    tick: u64,
    err: view.Error,
) -> Error {
    j := &c.journal
    c.presentation_failure = {
        serial      = c.presentation_failure.serial + 1,
        stage       = stage,
        error       = err,
        epoch       = j.epoch,
        tick        = tick,
        head        = c.timeline.head,
        confirmed   = j.confirmed,
        watch_tick  = j.watch_tick,
        queue_count = j.queue_count,
    }

    if len(j.batches) > 0 {
        slot := &j.batches[tick % u64(len(j.batches))]
        c.presentation_failure.slot_valid, c.presentation_failure.slot_tick, c.presentation_failure.slot_count =
            slot.valid, slot.tick, slot.count
    }

    return .Presentation
}
