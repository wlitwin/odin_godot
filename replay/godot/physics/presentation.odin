package replay_godot_physics

import b "godot:box3d"
import bp "godot:box3d/presentation"
import r "godot:replay"
import ph "godot:replay/physics"

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
