package replay_godot

import b "godot:box3d"
import bp "godot:box3d/presentation"
import r "godot:replay"
import net "godot:replay/net"
import ph "godot:replay/physics"
import v "godot:replay/view"

// One public owned-CP bulk cache read guards owner/realm before typed Game is
// accessed. The copied Frame stores no image, callback, allocator or native ID.
physics_presentation_frame :: proc(
    checkpoint: ^r.Complete_Checkpoint($S, $E),
    project: proc(_: S, _: []bp.Binding) -> (u32, bp.Error),
    revision: u64 = 0,
    source: bp.Source = .Predicted,
) -> (
    bp.Frame,
    bp.Error,
    r.Error,
) {
    if checkpoint == nil || project == nil {
        return {}, .Invalid, .Invalid_Config
    }

    bodies: [bp.MAX_BODIES]b.Body_State
    count, error := ph.body_states(checkpoint, bodies[:])

    if error != .None {
        return {}, .None, error
    }

    bindings: [bp.MAX_BODIES]bp.Binding
    binding_count, projection_error := project(checkpoint.frame.state, bindings[:])

    if projection_error != .None {
        return {}, projection_error, .None
    }

    if binding_count > bp.MAX_BODIES {
        return {}, .Capacity, .None
    }

    samples: [bp.MAX_BODIES]bp.Body_Sample

    for state, i in bodies[:count] {
        samples[i] = {
            body  = bp.Body_Key(state.key),
            pose  = {
                {state.pose.position.x, state.pose.position.y, state.pose.position.z},
                {state.pose.rotation.x, state.pose.rotation.y, state.pose.rotation.z, state.pose.rotation.w},
            },
            awake = state.is_awake != 0,
        }
    }

    frame, view_error := bp.frame_make(
        checkpoint.epoch,
        checkpoint.frame.tick,
        revision,
        source,
        bindings[:binding_count],
        samples[:count],
    )
    return frame, view_error, .None
}

// Existing journal change in, value-only observation out. The same original
// change/payload still goes to view/events/CueRoute; no second ledger exists.
physics_effect_observation :: proc(
    change: v.Change($E),
    project: proc(_: E) -> (bp.Identity, bool),
) -> (
    bp.Effect_Observation,
    bool,
) {
    if project == nil {
        return {}, false
    }

    game, ok := project(change.occurrence.value)

    if !ok {
        return {}, false
    }

    id := change.occurrence.id
    kind := bp.Effect_Change_Kind.Begin

    switch change.kind {
    case .Begin:
        kind = .Begin
    case .Update:
        kind = .Update
    case .Cancel:
        kind = .Cancel
    case .Confirm:
        kind = .Confirm
    }

    value := bp.Effect_Observation {
        id        = {id.epoch, id.tick, id.source, id.key},
        game      = game,
        kind      = kind,
        confirmed = change.confirmed,
    }
    return value, bp.effect_valid(value)
}

// Caller supplies alpha from existing scene.session_tick_phase/Tick_Phase.
// No clock wrapper/state, physics step, savepoint or render-time restore.
physics_presentation_status :: proc(session: ^Session($S, $C, $A, $E, $N)) -> (bp.Status, r.Error) {
    if session == nil {
        return {}, .Invalid_Config
    }

    if error := r.owned_context_access(session.ownership.container, session, b.BOX3D_REQUIRE_DOMAIN, .Read);
       error != .None {
        return {}, error
    }

    if !session.ready {
        return {}, .Not_Initialized
    }

    if session.authority {
        stats := session.server.profile_metrics
        return {
                epoch = session.server.cfg.epoch,
                head = session.server.timeline.head,
                confirmed = session.server.timeline.confirmed,
                predicted_frontier = session.server.timeline.head,
                predicted_frontier_available = true,
                accepted_frontier = session.server.timeline.head,
                accepted_frontier_available = true,
                ready = !session.fenced,
                hold = session.fenced,
                error_code = i32(session.server.frame_error),
                timing_available = stats[net.Profile_Metric.Advance].samples != 0 ||
                stats[net.Profile_Metric.Replay].samples != 0,
                normal_peak_ns = stats[net.Profile_Metric.Advance].max_us * 1000,
                repair_peak_ns = stats[net.Profile_Metric.Replay].max_us * 1000,
            },
            .None
    }

    client := &session.client
    result := bp.Status {
        epoch                        = client.cfg.epoch,
        head                         = client.timeline.head,
        confirmed                    = client.timeline.confirmed,
        accepted_frontier            = client.facts_contiguous,
        accepted_frontier_available  = client.has_world,
        predicted_frontier           = client.timeline.head,
        predicted_frontier_available = client.has_world,
        ready                        = client.phase == .Running,
        hold                         = client.phase !=
            .Running || client.timeline.head - client.timeline.confirmed >= u64(client.cfg.max_prediction),
        resync                       = client.phase == .Resyncing,
        error_code                   = i32(client.rejection),
        timing_available             = client.profile_metrics[net.Profile_Metric.Advance].samples !=
            0 || client.profile_metrics[net.Profile_Metric.Replay].samples != 0,
        normal_peak_ns               = client.profile_metrics[net.Profile_Metric.Advance].max_us * 1000,
        repair_peak_ns               = client.profile_metrics[net.Profile_Metric.Replay].max_us * 1000,
    }

    if client.physics != nil {
        result.repair_depth_available = true
        result.repair_depth = u32(min(client.physics.last_planned_depth, u64(max(u32))))
    }

    return result, .None
}

// Configure the existing Session receive-delay/fault adapter at normal open.
// Reliable ordering is still its responsibility; this is not an ENet loss tool.
// A reorder request is represented by nonzero existing jitter, not a new queue.
physics_impairment_options :: proc(options: Session_Options, request: bp.Impairment) -> (Session_Options, bp.Error) {
    if e := bp.impairment_supported(request, {.Latency, .Jitter, .Loss, .Duplicate, .Reorder}); e != .None {
        return options, e
    }

    if request.latency_ms > 10_000 || request.jitter_ms > 10_000 || (request.reorder && request.jitter_ms == 0) {
        return options, .Unsupported
    }

    result := options
    result.latency_ms = request.latency_ms
    result.jitter_ms = request.jitter_ms
    result.loss_permyriad = request.loss_permyriad
    result.duplicate_permyriad = request.duplicate_permyriad
    return result, .None
}
