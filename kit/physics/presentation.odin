package kit_physics

import b "godot:box3d"
import bp "godot:box3d/presentation"
import k "godot:kit/sim"

// Caller captures/stores epoch with this complete checkpoint. World_Checkpoint
// has no public epoch field: this helper never substitutes current Lane epoch.
// project is borrowed only during this call and must not retain/allocate per body.
presentation_frame :: proc(
	checkpoint: ^k.World_Checkpoint,
	epoch: u64,
	$Side: typeid,
	project: proc(_: Side, _: []bp.Binding) -> (u32, bp.Error),
	revision: u64 = 0,
	source: bp.Source = .Predicted,
) -> (
	bp.Frame,
	bp.Error,
	k.World_Error,
) {
	if checkpoint == nil || project == nil || epoch == 0 {return {}, .Invalid, .Invalid}
	side, error := checkpoint_side(checkpoint, Side)
	if error != .Ok {return {}, .None, error}
	bodies: [bp.MAX_BODIES]b.Body_State
	count, cache_error := checkpoint_body_states(checkpoint, bodies[:], Side)
	if cache_error != .Ok {return {}, .None, cache_error}
	bindings: [bp.MAX_BODIES]bp.Binding
	binding_count, projection_error := project(side, bindings[:])
	if projection_error != .None {return {}, projection_error, .Ok}
	if binding_count > bp.MAX_BODIES {return {}, .Capacity, .Ok}
	samples: [bp.MAX_BODIES]bp.Body_Sample
	for state, i in bodies[:count] {samples[i] = {
			body  = bp.Body_Key(state.key),
			pose  = {
				{state.pose.position.x, state.pose.position.y, state.pose.position.z},
				{
					state.pose.rotation.x,
					state.pose.rotation.y,
					state.pose.rotation.z,
					state.pose.rotation.w,
				},
			},
			awake = state.is_awake != 0,
		}}
	frame, view_error := bp.frame_make(
		epoch,
		checkpoint.tick,
		revision,
		source,
		bindings[:binding_count],
		samples[:count],
	)
	return frame, view_error, .Ok
}

// The caller obtains these public metadata VALUES under its existing protected
// Lane owner. No new typed Lane/userdata cast or allocator/context is retained.
// Kit exposes no actual accepted-tick frontier here: leave it unavailable.
presentation_status :: proc(
	epoch, head, confirmed: u64,
	network: k.World_Network_Status,
	work: k.World_Work_Stats,
) -> bp.Status {
	result := bp.Status {
		epoch                        = epoch,
		head                         = head,
		confirmed                    = confirmed,
		predicted_frontier           = head,
		predicted_frontier_available = epoch != 0,
		ready                        = epoch != 0 && !network.needs_resync,
		hold                         = network.needs_resync,
		resync                       = network.needs_resync,
		error_code                   = i32(network.error),
		timing_available             = epoch != 0,
		normal_ns                    = work.normal_latest_ns,
		repair_ns                    = work.correction_latest_ns,
		normal_peak_ns               = work.normal_peak_ns,
		repair_peak_ns               = work.correction_peak_ns,
	}
	if network.error !=
	   .Unsupported {result.ready = network.ready; result.hold = network.needs_resync || !network.ready}
	return result
}

// Call ONLY from the existing actual postcommit effect callback, with its
// stable game lifetime/serial projection. This validates/labels an observation;
// it does not deliver/deduplicate expected checkpoint effects or scan history.
presentation_effect :: proc(
	epoch, tick: u64,
	kind: u16,
	key: u64,
	game: bp.Identity,
) -> (
	bp.Effect_Observation,
	bool,
) {
	value := bp.Effect_Observation {
		id        = {epoch, tick, u64(kind), key},
		game      = game,
		kind      = .Committed,
		confirmed = true,
	}
	return value, bp.effect_valid(value)
}

// Prepare arguments for the EXISTING netgd.wire_set_latency call made by the
// owner. No socket/context is borrowed and this function applies no side effect.
// That adapter models loss in whole percentages and has no duplicate toggle.
presentation_impairment :: proc(
	request: bp.Impairment,
) -> (
	latency, jitter, loss_percent: int,
	error: bp.Error,
) {
	if e := bp.impairment_supported(request, {.Latency, .Jitter, .Loss});
	   e != .None {return 0, 0, 0, e}
	if request.loss_permyriad > 9500 ||
	   request.loss_permyriad % 100 != 0 {return 0, 0, 0, .Unsupported}
	return int(request.latency_ms),
		int(request.jitter_ms),
		int(request.loss_permyriad / 100),
		.None
}

