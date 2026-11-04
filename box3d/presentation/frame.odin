package box3d_presentation

import "core:math"

@(private)
finite :: proc "contextless" (value: f32) -> bool {return(
		!math.is_nan(value) &&
		!math.is_inf(value) \
	)}
@(private)
pose_normalize :: proc "contextless" (value: Pose) -> (Pose, bool) {
	for v in value.position {if !finite(v) {return {}, false}}
	largest := f32(0)
	for v in value.rotation {if !finite(v) {return {}, false}; largest = max(largest, abs(v))}
	if largest == 0 {return {}, false}
	result := value
	result.rotation /= largest
	magnitude := f32(0); for v in result.rotation {magnitude += v * v}
	magnitude = math.sqrt(magnitude)
	if !finite(magnitude) || magnitude == 0 {return {}, false}
	result.rotation /= magnitude
	return result, true
}
@(private)
identity_valid :: proc "contextless" (id: Identity) -> bool {return(
		id.entity != 0 &&
		id.lifetime != 0 \
	)}

// Bindings are a projection of Game/Side from the SAME owned CP as samples.
// Native identity certification occurs in the public bulk reader, not here.
frame_make :: proc "contextless" (
	epoch, tick, revision: u64,
	source: Source,
	bindings: []Binding,
	samples: []Body_Sample,
) -> (
	frame: Frame,
	error: Error,
) {
	if epoch == 0 || source > .Observed {return {}, .Invalid}
	if len(bindings) > MAX_BODIES || len(samples) > MAX_BODIES {return {}, .Capacity}
	for sample, i in samples {
		if sample.body == 0 {return {}, .Invalid}
		for prior in samples[:i] {if prior.body == sample.body {return {}, .Duplicate}}
	}
	result := Frame {
		epoch    = epoch,
		tick     = tick,
		revision = revision,
		source   = source,
	}
	for binding in bindings {
		if !binding.alive {continue}
		if !identity_valid(binding.id) ||
		   binding.body == 0 ||
		   binding.asset == 0 {return {}, .Invalid}
		for prior in result.rows[:result.count] {if prior.id.entity == binding.id.entity || prior.body == binding.body {return {}, .Duplicate}}
		found := false
		for sample in samples {
			if sample.body != binding.body {continue}
			normalized, ok := pose_normalize(sample.pose); if !ok {return {}, .Invalid}
			result.rows[result.count] = {
				id    = binding.id,
				body  = binding.body,
				asset = binding.asset,
				seat  = binding.seat,
				pose  = normalized,
				awake = sample.awake,
			}
			result.count += 1; found = true; break
		}
		if !found {return {}, .Missing_Body}
	}
	return result, .None
}
@(private)
frame_valid :: proc "contextless" (frame: ^Frame) -> bool {
	if frame == nil ||
	   frame.epoch == 0 ||
	   frame.count > MAX_BODIES ||
	   frame.source > .Observed {return false}
	for row, i in frame.rows[:frame.count] {
		if !identity_valid(row.id) || row.body == 0 || row.asset == 0 {return false}
		if _, ok := pose_normalize(row.pose); !ok {return false}
		for prior in frame.rows[:i] {if prior.id.entity == row.id.entity || prior.body == row.body {return false}}
	}
	return true
}
@(private)
row_same_binding :: proc "contextless" (a, b: Row) -> bool {return(
		a.id == b.id &&
		a.body == b.body &&
		a.asset == b.asset \
	)}
@(private)
interpolated_row :: proc "contextless" (
	previous: ^Frame,
	current: ^Frame,
	row: Row,
	alpha: f32,
) -> (
	Row,
	bool,
) {
	if previous == nil ||
	   previous.epoch != current.epoch ||
	   previous.revision != current.revision ||
	   previous.tick == max(u64) ||
	   previous.tick + 1 != current.tick {return row, false}
	for older in previous.rows[:previous.count] {
		if !row_same_binding(older, row) {continue}
		a, ok_a := pose_normalize(older.pose); b, ok_b := pose_normalize(row.pose)
		if !ok_a || !ok_b {return row, false}
		result := row
		result.pose.position = a.position * (1 - alpha) + b.position * alpha
		dot := f32(0); for value, i in a.rotation {dot += value * b.rotation[i]}
		if dot < 0 {b.rotation = -b.rotation}
		result.pose.rotation = a.rotation * (1 - alpha) + b.rotation * alpha
		normalized, ok := pose_normalize(result.pose); if !ok {return row, false}
		result.pose = normalized
		return result, true
	}
	return row, false
}

// Atomic map/output transaction. Call once per render update; alpha comes from
// the EXISTING adapter clock/phase. This function owns or advances no clock.
present :: proc "contextless" (
	view: ^View,
	previous, current: ^Frame,
	alpha: f32,
	out: []Change,
) -> (
	required: u32,
	error: Error,
) {
	if view == nil ||
	   !frame_valid(current) ||
	   (previous != nil && !frame_valid(previous)) ||
	   !finite(alpha) {return 0, .Invalid}
	if view.ready &&
	   (current.epoch < view.epoch ||
			   (current.epoch == view.epoch &&
					   current.revision < view.revision)) {return 0, .Stale}
	if view.ready &&
	   current.epoch == view.epoch &&
	   current.revision == view.revision &&
	   current.tick < view.tick {return 0, .Stale}
	a := clamp(alpha, 0, 1)
	next := view^
	changes: [MAX_CHANGES]Change
	count := u32(0)
	epoch_cut := next.ready && next.epoch != current.epoch
	revision_cut := next.ready && next.revision != current.revision
	// Retire disappeared identities, including all prior-epoch proxies. Generations
	// survive retirement, so even numerical game/body keys cannot alias stale rigs.
	for &slot, i in next.slots {
		if !slot.active {continue}
		found := false
		if !epoch_cut {for row in current.rows[:current.count] {if row.id.entity == slot.row.id.entity {found = true; break}}}
		if !found {
			changes[count] = {
				kind           = .Remove,
				token          = {u32(i), slot.generation},
				previous_token = {u32(i), slot.generation},
				row            = slot.row,
				previous       = slot.row,
			}
			count += 1; slot.active = false
		}
	}
	for raw in current.rows[:current.count] {
		row := raw
		row.pose, _ = pose_normalize(raw.pose)
		at := -1
		for slot, i in next.slots {if slot.active && slot.row.id.entity == row.id.entity {at = i; break}}
		kind := Change_Kind.Update
		old: Row; old_token: Token
		if at < 0 {
			kind = .Spawn
			for slot, i in next.slots {if !slot.active && slot.generation < max(u32) {at = i; break}}
			if at < 0 {return 0, .Generation_Exhausted}
		} else {
			slot := &next.slots[at]; old = slot.row; old_token = {u32(at), slot.generation}
			if !row_same_binding(old, row) {kind = .Rebind}
		}
		slot := &next.slots[at]
		if kind == .Spawn || kind == .Rebind {
			if slot.generation == max(u32) {return 0, .Generation_Exhausted}
			slot.generation += 1
			if kind == .Rebind {next.rebinds += 1}
		}
		value := row; blend := false
		if !epoch_cut && !revision_cut {value, blend = interpolated_row(previous, current, row, a)}
		slot.active = true; slot.row = value
		changes[count] = {
			kind           = kind,
			token          = {u32(at), slot.generation},
			previous_token = old_token,
			row            = value,
			previous       = old,
			interpolated   = blend,
		}
		count += 1
	}
	if u64(len(out)) < u64(count) {return count, .Capacity}
	if epoch_cut || revision_cut {next.cuts += 1}
	next.ready =
		true; next.epoch = current.epoch; next.tick = current.tick; next.revision = current.revision; next.frames += 1
	copy(out, changes[:count]); view^ = next
	return count, .None
}

view_clear :: proc "contextless" (view: ^View, out: []Change) -> (u32, Error) {
	if view == nil {return 0, .Invalid}
	changes: [MAX_BODIES]Change; count := u32(0)
	next := view^
	for &slot, i in next.slots {if slot.active {
			changes[count] = {
				kind           = .Remove,
				token          = {u32(i), slot.generation},
				previous_token = {u32(i), slot.generation},
				row            = slot.row,
				previous       = slot.row,
			}; count += 1; slot.active = false
		}}
	if u64(len(out)) < u64(count) {return count, .Capacity}
	next.ready = false; next.epoch = 0; next.tick = 0; next.revision = 0
	copy(out, changes[:count]); view^ = next
	return count, .None
}

status_valid :: proc "contextless" (value: Status) -> bool {
	if value.ready && value.epoch == 0 {return false}
	if value.confirmed > value.head {return false}
	if value.predicted_frontier_available &&
	   value.predicted_frontier < value.confirmed {return false}
	return true
}
effect_valid :: proc "contextless" (value: Effect_Observation) -> bool {
	return(
		value.id.epoch != 0 &&
		value.id.key != 0 &&
		identity_valid(value.game) &&
		value.kind <= .Committed &&
		(value.kind != .Committed || value.confirmed) \
	)
}
impairment_valid :: proc "contextless" (value: Impairment) -> bool {
	return(
		value.latency_ms <= 60_000 &&
		value.jitter_ms <= 60_000 &&
		value.loss_permyriad <= 10_000 &&
		value.duplicate_permyriad <= 10_000 \
	)
}
