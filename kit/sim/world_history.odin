package kit_sim

import "core:math"
import "core:mem"
import "core:time"
import bd "godot:box3d/diagnostics"
import knet "godot:kit/net"
import ksess "godot:kit/session"

World_Commit_Gate :: struct {
	user:  rawptr,
	allow: proc(user: rawptr, tick: u64) -> bool,
}
World_Result :: struct {
	error: World_Error,
	tick:  u64,
	steps: int,
}

@(private)
world_admit :: proc(
	l: ^Lane,
	execution: rawptr,
	prediction, correction: u32,
	normal_ns, correction_ns: u64,
	reserve: bool,
) -> World_Error {
	w := l.world
	request := World_Admission {
		prediction,
		correction,
		world_external_bytes(l),
		reserve ? w.config.reservation_bytes : 0,
		normal_ns,
		correction_ns,
	}
	return w.provider.admit(w.provider.user, execution, request)
}
@(private)
world_stage_clear :: proc(w: ^World_History) {
	for &f in w.staged {if f.image != nil {w.provider.release(f.image)}; f.image = nil; f.valid = false; f.effect_count = 0}
	w.staged_count = 0
}
@(private)
world_stage_note :: proc(l: ^Lane, tick: u64) -> World_Error {
	w := l.world
	if w.staged_count >= len(w.staged) {return .Capacity}
	if error := world_admit(l, w.candidate, 0, 0, 0, 0, true); error != .Ok {return error}
	f := &w.staged[w.staged_count]
	image, error := w.provider.capture(w.provider.user, w.candidate)
	if error != .Ok {return error}
	f.image = image; f.tick = tick; f.valid = true; world_capture_fields(w, f.fields)
	f.effect_count = w.current_effect_count
	for i in 0 ..< f.effect_count {f.effects[i] = w.current_effects[i]}
	w.staged_count += 1
	if error := world_network_admit_image(l, image); error != .Ok {return error}
	return world_admit(l, w.candidate, 0, 0, 0, 0, false)
}

@(private)
world_publish :: proc(
	l: ^Lane,
	tick: u64,
	steps: int,
	confirm, reset_epoch: bool,
	started: time.Tick,
	normal: bool,
	confirm_to: u64 = 0,
	matched_signature: ^bd.Signature = nil,
) -> World_Result {
	w := l.world
	// No allocation, callback or fallible operation is permitted between owner
	// selection and committing fields/legacy ledgers. Effects are copied first.
	ready: [(WORLD_REPAIR_TICKS + 1) * WORLD_EFFECTS_PER_TICK]World_Effect
	ticks: [(WORLD_REPAIR_TICKS + 1) * WORLD_EFFECTS_PER_TICK]u64
	count := 0
	for &staged in w.staged[:w.staged_count] {
		old := world_record(w, staged.tick)
		for e in staged.effects[:staged.effect_count] {
			if reset_epoch {continue}
			seen := false
			if old !=
			   nil {for prior in old.effects[:old.effect_count] {if prior.key == e.key {seen = true; break}}}
			if !seen {ready[count] = e; ticks[count] = staged.tick; count += 1}
		}
	}
	retired := w.published
	w.publishing = true
	if reset_epoch {
		for &f in w.frames {if f.image != nil {w.provider.release(f.image)}; f.image = nil; f.valid = false; f.effect_count = 0}
		for b in w.bindings {mem.zero(raw_data(b.hist.tick), len(b.hist.tick) * 8)}
		for &ic in l.inputs {mem.zero(raw_data(ic.ring.ring.tick), len(ic.ring.ring.tick) * 8); ic.ring.head = 0; ic.ring.tail = 0; mem.zero(raw_data(ic.scratch), len(ic.scratch))}
		w.epoch += 1; w.confirmed = tick; l.ticker.acc = 0; clear(&l.pending); l.pending_tick = 0
	}
	w.provider.publish(w.provider.user, w.candidate)
	w.published = w.candidate; w.candidate = nil
	for &staged in w.staged[:w.staged_count] {
		f := &w.frames[staged.tick % WORLD_HISTORY_FRAMES]
		if f.image != nil {w.provider.release(f.image)}
		f.image =
			staged.image; staged.image = nil; f.tick = staged.tick; f.valid = true; copy(f.fields, staged.fields)
		f.effect_count = staged.effect_count
		for i in 0 ..< f.effect_count {f.effects[i] = staged.effects[i]}
		for b in w.bindings {history_note_bytes(b.hist, f.tick, f.fields[b.offset:b.offset + b.size])}
	}
	world_net_commit_inputs(l)
	w.head = tick; l.ticker.tick = tick
	if w.network != nil && l.ses.is_host {w.confirmed = tick;w.network.protocol.accepted_through=tick}
	if confirm && !reset_epoch {w.confirmed = max(w.confirmed, w.staged[0].tick)}
	if confirm_to != 0 {w.confirmed = max(w.confirmed, confirm_to)}
	if matched_signature!=nil {
		n:=w.network;n.protocol.matched_signature_tick=matched_signature.tick;n.protocol.signatures_matched+=1
		n.last_signature=matched_signature^;n.status=.Ok;n.protocol.error=.Ok
	}
	w.publishing = false; w.provider.bind(w.provider.user, w.published)
	w.provider.close(retired)
	elapsed := u64(max(i64(time.tick_since(started)), 0))
	if normal {w.work.normal_latest_ns = elapsed; w.work.normal_peak_ns = max(w.work.normal_peak_ns, elapsed)} else {w.work.correction_latest_ns = elapsed; w.work.correction_peak_ns = max(w.work.correction_peak_ns, elapsed)}
	w.status = .Ok; w.resync = false
	result := World_Result{.Ok, tick, steps}
	w.staged_count = 0
	// Release busy before effects, but a separate latch rejects reentrant lane
	// operations while irreversible presentation callbacks run after acceptance.
	w.busy = false; w.presenting = true
	for i in 0 ..< count {e := &ready[i]; e.fire(e.user, ticks[i], e.key, e.args[:e.count])}
	w.presenting = false
	return result
}

@(private)
world_operation :: proc(
	l: ^Lane,
	source: ^World_Frame,
	checkpoint: ^World_Checkpoint,
	head: u64,
	normal: bool,
	gate: World_Commit_Gate,
	reset_epoch := false,
	confirm_authority := true,
	verify_at: ^World_Checkpoint = nil,
	verify_signature: ^bd.Signature = nil,
	confirm_to: u64 = 0,
) -> (
	result: World_Result,
) {
	w := l.world
	if w == nil {return {.Unsupported, l.ticker.tick, 0}}
	if e := world_owner_check(w.provider.owner, WORLD_OWNER_EXECUTE);
	   e != .Ok {return {e, w.head, 0}}
	context.allocator = w.allocator
	if w.busy || w.presenting {return {.Busy, w.head, 0}}
	if source == nil {return {.History_Missing, w.head, 0}}
	if head < source.tick ||
	   head - source.tick > WORLD_REPAIR_TICKS {return {.Repair_Limit, source.tick, 0}}
	correction := normal ? u32(0) : u32(head - source.tick)
	prediction := u32(0)
	if !l.ses.is_host && !reset_epoch {
		if head < w.confirmed ||
		   head - w.confirmed > WORLD_REPAIR_TICKS {return {.Prediction_Limit, head, 0}}
		prediction = u32(head - w.confirmed)
	}
	// Scheduled verbs have unmanaged patches/delta effects today. Do not run
	// them and pretend those effects are part of this transaction.
	if len(l.cmd_in) != 0 || len(l.cmd_out) != 0 {return {.Unsupported, w.head, 0}}
	for &ic in l.inputs {if ic.size > 0 && !normal {
			for offset in 0 ..< int(
				head - source.tick,
			) {tick := source.tick + u64(offset) + 1; if verify_signature!=nil && tick<=verify_signature.tick {continue}; if _, ok := input_read(&ic.ring, tick); !ok {return {.History_Missing, tick, 0}}}
		}}
	// One ticket covers admitted staged ticks plus open/final verification work.
	// The configured 2 MiB remains a primitive allowance, not an eight-tick total.
	primitive_count := max(u64(1), head - source.tick) + 3
	if w.config.reservation_bytes >
	   WORLD_MEMORY_BYTES / primitive_count {return {.Budget, w.head, 0}}
	mark, budget_error := world_budget_begin(
		w.provider.budget,
		w.config.reservation_bytes * primitive_count,
	)
	if budget_error != .Ok {return {budget_error, w.head, 0}}
	defer world_budget_end(w.provider.budget, &mark)
	if error := world_admit(l, w.published, prediction, correction, 0, 0, true);
	   error != .Ok {return {error, w.head, 0}}
	started := time.tick_now()
	world_capture_fields(w, w.live_backup)
	world_inputs_save(l)
	old_resimming, old_step, old_auth := l.resimming, l.step_tick, l.in_auth
	success := false
	w.busy = true; w.status = .Ok; world_stage_clear(w)
	defer {
		l.resimming =
			old_resimming; l.step_tick = success ? w.head : old_step; l.in_auth = old_auth
		if !success {
			world_restore_fields(w, w.live_backup); world_inputs_restore(l)
			w.provider.bind(w.provider.user, w.published)
			if w.candidate != nil {w.provider.close(w.candidate); w.candidate = nil}
			world_stage_clear(w); w.busy = false
			w.status = result.error
			if result.error != .Rejected &&
			   result.error != .Allocation_Failed &&
			   result.error != .Step_Failed {w.resync = true}
		}
	}
	if error := world_net_operation_begin(l, source.tick);
	   error != .Ok {return {error, source.tick, 0}}
	execution, error := w.provider.open(w.provider.user, source.image)
	if error != .Ok {return {error, source.tick, 0}}
	w.candidate = execution; w.provider.bind(w.provider.user, execution)
	world_restore_fields(w, source.fields)
	if error := world_admit(l, execution, prediction, correction, 0, 0, true);
	   error != .Ok {return {error, source.tick, 0}}
	if !normal {
		// The authoritative predecessor is part of the accepted complete suffix,
		// even when every registered pose byte happens to match its prediction.
		f := &w.staged[0]
		f.image, error = w.provider.clone(source.image)
		if error != .Ok {return {error, source.tick, 0}}
		f.tick = source.tick; f.valid = true; f.effect_count = 0; copy(f.fields, source.fields)
		if old := world_record(w, source.tick);
		   old !=
		   nil {f.effect_count = old.effect_count; for i in 0 ..< f.effect_count {f.effects[i] = old.effects[i]}}
		if checkpoint != nil &&
		   checkpoint.effects_known {f.effect_count = checkpoint.effect_count; f.effects = checkpoint.effects}
		w.staged_count = 1
	}
	steps := 0
	l.resimming = true // generated/inline presentation never runs speculatively
	for offset in 0 ..< int(head - source.tick) {
		tick := source.tick + u64(offset) + 1
		if error := world_admit(l, execution, prediction, correction, 0, 0, true);
		   error != .Ok {return {error, tick, steps}}
		w.current_effect_count = 0
		if normal {sample_inputs(l, tick)}
		if error := world_net_prepare(l, tick); error != .Ok {return {error, tick, steps}}
		run_tick(l, tick)
		if w.status != .Ok {return {w.status, tick, steps}}
		steps += 1
		if error := world_stage_note(l, tick); error != .Ok {return {error, tick, steps}}
		if verify_at != nil && tick == verify_at.tick {
			actual := &w.staged[w.staged_count - 1]
			same, e := w.provider.equal(actual.image, verify_at.image)
			if e != .Ok {return {e, tick, steps}}
			if !same ||
			   mem.compare(actual.fields, verify_at.fields) != 0 ||
			   !world_effects_equal(
					   actual.effects[:actual.effect_count],
					   verify_at.effects[:verify_at.effect_count],
				   ) {
				if w.network !=
				   nil {world_network_trace_settled(l, w.network.check_signature, w.network.applying_transfer.bytes, actual)}
				return {.Conflict, tick, steps}
			}
		}
	}
	if verify_signature!=nil {
		frame:=world_record(w,verify_signature.tick)
		for &staged in w.staged[:w.staged_count] {if staged.tick==verify_signature.tick {frame=&staged;break}}
		if frame==nil {return {.History_Missing,verify_signature.tick,steps}}
		actual,e:=world_protocol_frame_signature(l,frame);if e!=.Ok {return {e,verify_signature.tick,steps}}
		if bd.compare(actual,verify_signature^)!=.Match {return {.Conflict,verify_signature.tick,steps}}
	}
	elapsed := u64(max(i64(time.tick_since(started)), 0))
	// Diagnostic wall time is not causal admission state. OS preemption must
	// not turn a valid simulation into a sticky resync. P2 measures the4ms
	// targets in integration acceptance, outside deterministic simulation.
	if normal {w.work.normal_latest_ns = elapsed; w.work.normal_peak_ns = max(w.work.normal_peak_ns, elapsed)} else {w.work.correction_latest_ns = elapsed; w.work.correction_peak_ns = max(w.work.correction_peak_ns, elapsed)}
	if error := world_admit(l, execution, prediction, correction, 0, 0, false);
	   error != .Ok {return {error, head, steps}}
	if gate.allow != nil && !gate.allow(gate.user, head) {return {.Rejected, head, steps}}
	if gate.allow != nil {
		// Gates authorize; they do not gain permission to mutate the candidate.
		last := &w.staged[w.staged_count - 1]
		for b in w.bindings {if !predict_matches(b.entity, b.desc, last.fields[b.offset:b.offset + b.size]) {return {.Unsupported, head, steps}}}
		if error := world_admit(l, execution, prediction, correction, 0, 0, true);
		   error != .Ok {return {error, head, steps}}
		probe, error := w.provider.capture(
			w.provider.user,
			execution,
		); if error != .Ok {return {error, head, steps}}
		equal, compare_error := w.provider.equal(last.image, probe); w.provider.release(probe)
		if compare_error != .Ok {return {compare_error, head, steps}}
		if !equal {return {.Unsupported, head, steps}}
		if error := world_admit(l, execution, prediction, correction, 0, 0, false);
		   error != .Ok {return {error, head, steps}}
	}
	// A gate is outside simulation and may only authorize publication; changed
	// tracked/command structures must still fail rather than publish partial state.
	if w.status != .Ok {return {w.status, head, steps}}
	if error := world_budget_reconcile(w.provider.budget, mark);
	   error != .Ok {return {error, w.head, 0}}
	success = true
	return world_publish(
		l,
		head,
		steps,
		!normal && confirm_authority,
		reset_epoch,
		started,
		normal,
		confirm_to,
		verify_signature,
	)
}

@(private)
world_frame :: proc(l: ^Lane, dt: f64) -> int {
	w := l.world
	if e := world_owner_check(w.provider.owner, WORLD_OWNER_EXECUTE);
	   e != .Ok {w.status = e; return 0}
	if w.busy || w.presenting {w.status = .Busy; return 0}
	if w.network != nil {world_network_ingest(l); if dt==0 {world_protocol_control(l)}; if !w.network.ready {return 0}}
	if w.resync {return 0}
	if len(l.pending) != 0 {w.status = .Missing_Attachment; w.resync = true; return 0}
	if w.head == max(u64) {w.status = .Capacity; w.resync = true; return 0}
	if dt < 0 || math.is_nan(dt) || math.is_inf(dt) {w.status = .Invalid; return 0}
	total := l.ticker.acc + dt * l.ticker.scale
	if total >=
	   l.ticker.dt *
		   f64(MAX_CATCHUP_TICKS + 1) {w.status = .Repair_Limit; w.resync = true; return 0}
	trial := l.ticker; n := sim_ticker_advance(&trial, dt); accepted := 0
	if n == 0 {l.ticker.acc = total; return 0}
	for _ in 0 ..< n {
		source := world_record(w, w.head)
		result := world_operation(l, source, nil, w.head + 1, true, {})
		if result.error !=
		   .Ok {w.status = result.error; if result.error != .Rejected && result.error != .Allocation_Failed && result.error != .Step_Failed && result.error != .Busy {w.resync = true}; return accepted}
		accepted += 1; l.ticker.acc = total - f64(accepted) * l.ticker.dt
		if w.network != nil {world_network_after_tick(l)}
	}
	return accepted
}

// Reset is explicit complete-state recovery. It never manufactures missing
// history from live state or drops solver attachments. Exported checkpoints own
// their image/fields independently of the source Lane/provider lifetime.
lane_world_reset :: proc(
	l: ^Lane,
	checkpoint: ^World_Checkpoint,
	gate := World_Commit_Gate{},
) -> World_Result {
	return world_reconcile(l, checkpoint, true, gate)
}
@(private)
world_reconcile :: proc(
	l: ^Lane,
	checkpoint: ^World_Checkpoint,
	reset: bool,
	gate: World_Commit_Gate,
) -> World_Result {
	if l.world == nil {return {.Unsupported, l.ticker.tick, 0}}
	w := l.world
	if w.network != nil && !w.network.applying {return {.Rejected, w.head, 0}}
	if checkpoint == nil ||
	   checkpoint.image ==
		   nil {w.status = .Missing_Attachment; w.resync = true; return {.Missing_Attachment, w.head, 0}}
	if e := world_owner_check(checkpoint.owner); e != .Ok {return {e, w.head, 0}}
	if e := world_owner_check(w.provider.owner, WORLD_OWNER_EXECUTE);
	   e != .Ok {return {e, w.head, 0}}
	if checkpoint.asset_id != w.provider.asset_id ||
	   checkpoint.side_type != w.provider.side_type ||
	   checkpoint.field_schema != w.field_schema ||
	   len(checkpoint.fields) !=
		   w.field_bytes {w.status = .Incompatible; w.resync = true; return {.Incompatible, checkpoint.tick, 0}}
	if w.busy || w.presenting {return {.Busy, w.head, 0}}
	if !reset &&
	   checkpoint.tick < w.confirmed {w.status = .Settled; return {.Settled, checkpoint.tick, 0}}
	if !reset && checkpoint.tick == w.confirmed {
		settled := world_record(w, w.confirmed)
		if settled ==
		   nil {w.status = .History_Missing; w.resync = true; return {.History_Missing, checkpoint.tick, 0}}
		equal, status := w.provider.equal(settled.image, checkpoint.image)
		if status != .Ok {w.status = status; return {status, checkpoint.tick, 0}}
		if !equal ||
		   (checkpoint.effects_known &&
				   !world_effects_equal(
						   settled.effects[:settled.effect_count],
						   checkpoint.effects[:checkpoint.effect_count],
					   )) ||
		   mem.compare(settled.fields, checkpoint.fields) !=
			   0 {w.status = .Conflict; w.resync = true; return {.Conflict, checkpoint.tick, 0}}
		w.status = .Ok; return {.Ok, w.head, 0}
	}
	if !reset &&
	   world_record(w, checkpoint.tick) ==
		   nil {w.status = .History_Missing; w.resync = true; return {.History_Missing, checkpoint.tick, 0}}
	if !reset &&
	   (checkpoint.tick > w.head ||
			   w.head - checkpoint.tick >
				   WORLD_REPAIR_TICKS) {w.status = .Repair_Limit; w.resync = true; return {.Repair_Limit, checkpoint.tick, 0}}
	frame := World_Frame {
		tick   = checkpoint.tick,
		valid  = true,
		image  = checkpoint.image,
		fields = checkpoint.fields,
	}
	head := reset ? checkpoint.tick : w.head
	if reset && w.epoch == max(u64) {return {.Capacity, checkpoint.tick, 0}}
	result := world_operation(l, &frame, checkpoint, head, false, gate, reset_epoch = reset)
	if result.error == .Ok &&
	   !reset {l.stat_reconciles += 1; l.stat_resims += result.steps; l.stat_resim_seconds += f64(w.work.correction_latest_ns) / 1e9}
	return result
}

@(private)
world_network_bytes :: proc(n: ^World_Network) -> u64 {
	if n == nil {return 0}
	return(
		u64(
			size_of(World_Network) +
			len(n.drivers) * size_of(World_Driver) +
			len(n.effects) * size_of(World_Effect_Def) +
			len(n.accepted_data) +
			len(n.proposed_data) +
			len(n.used_data) +
			len(n.backup_data) +
			len(n.staged_data) +
			n.queue_bytes +
			len(n.trace.storage),
		) +
		n.outbound_bytes + world_network_transfer_bytes(n) \
	)
}
@(private)
world_network_transfer_bytes :: proc(n:^World_Network)->u64 {
 if n==nil {return 0}
 total:=u64(len(n.transfer)+len(n.applying_transfer.bytes))
 for entry in n.completed {total+=u64(len(entry.bytes))}
 return total
}
@(private)
world_network_clear_assembly :: proc(n:^World_Network,allocator:mem.Allocator) {
 delete(n.transfer,allocator);n.transfer=nil;n.transfer_seen={};n.transfer_hash={}
 n.transfer_sequence=0;n.transfer_epoch=0;n.transfer_tick=0;n.transfer_mode={};n.transfer_chunks=0;n.transfer_received=0
}
@(private)
world_network_clear_transfers :: proc(n:^World_Network,allocator:mem.Allocator) {
 // Same-epoch obsolete corrections remain retired across a recovery request.
 world_network_clear_assembly(n,allocator)
 for &entry in n.completed {delete(entry.bytes,allocator);entry={}}
 n.completed_head=0;n.completed_count=0
 delete(n.applying_transfer.bytes,allocator);n.applying_transfer={}
}
@(private)
world_network_retire_transfer_epochs :: proc(n:^World_Network,epoch:u64,allocator:mem.Allocator) {
 if len(n.transfer)>0 && n.transfer_epoch<epoch {world_network_clear_assembly(n,allocator)}
 kept:[WORLD_NETWORK_TRANSFERS]World_Completed_Transfer;count:=0
 for i in 0..<n.completed_count {
  index:=(n.completed_head+i)%WORLD_NETWORK_TRANSFERS;entry:=n.completed[index];n.completed[index]={}
  if entry.epoch<epoch {delete(entry.bytes,allocator)}else{kept[count]=entry;count+=1}
 }
 n.completed=kept;n.completed_head=0;n.completed_count=count
}
@(private)
world_network_queued_chunk :: proc(l:^Lane,entry:^World_Completed_Transfer,mode:World_Transfer_Mode,sequence,epoch,tick:u64,total,index,count:int,hash:bd.Digest,blob:[]u8)->bool {
 if len(entry.bytes)==0 || entry.sequence!=sequence || entry.epoch!=epoch {return false}
 if entry.mode!=mode || entry.tick!=tick || len(entry.bytes)!=total || entry.chunks!=count || entry.hash!=hash {world_network_fail(l,.Conflict);return true}
 stored:=entry.bytes[index*WORLD_NETWORK_CHUNK:index*WORLD_NETWORK_CHUNK+len(blob)]
 if mem.compare(stored,blob)!=0 {world_network_fail(l,.Conflict,true)}else{l.world.network.duplicates+=1}
 return true
}
// Must be installed after local participant/tracks and before stepping. Codecs
// and catalogs are immutable and must outlive this attachment. Driver roster is
// fixed for an epoch; a roster/content change requires a new explicit reset.
lane_world_network_attach :: proc(l: ^Lane, cfg: World_Network_Config) -> World_Error {
	if l == nil || l.world == nil {return .Unsupported}; w := l.world
	if w.busy || w.presenting {return .Busy}
	if w.network != nil ||
	   w.head != 0 ||
	   cfg.epoch == 0 ||
	   cfg.codec.encode == nil ||
	   cfg.codec.recovery_encode == nil ||
	   cfg.codec.decode == nil ||
	   len(cfg.drivers) > WORLD_NETWORK_DRIVERS ||
	   len(cfg.effects) > WORLD_EFFECTS_PER_TICK ||
	   len(cfg.codec.fields) != len(w.bindings) {return .Invalid}
	if e := world_owner_check(w.provider.owner, WORLD_OWNER_EXECUTE); e != .Ok {return e}
	if e := world_owner_check(cfg.codec.owner); e != .Ok {return e}
	if !world_owner_is_empty(w.provider.owner) &&
	   world_owner_is_empty(cfg.codec.owner) {return .Unsupported}
	// Validate the mandatory shared identity through the native-free utility.
	probe, pe := bd.sign(
		{
			identity = cfg.identity,
			epoch = cfg.epoch,
			parts = {
				.Solver = {1},
				.Game = nil,
				.Side = nil,
				.Observations = nil,
				.Occurrences = nil,
			},
		},
	); _ = probe
	if pe != .None {return .Incompatible}
	bytes := 0
	for d, i in cfg.drivers {
		if d.player == knet.PLAYER_ID_INVALID {return .Invalid}
		for p in cfg.drivers[:i] {if p == d {return .Conflict}}
		found := false
		for c in cfg.codec.inputs {if c.class == d.class {
				if found ||
				   c.prediction > .Neutral ||
				   c.codec.encode == nil ||
				   c.codec.decode == nil ||
				   c.codec.local_bytes < 1 ||
				   c.codec.local_bytes > MAX_INPUT_SIZE ||
				   c.codec.wire_bytes < 1 ||
				   c.codec.wire_bytes > MAX_INPUT_SIZE ||
				   len(c.codec.descriptor) == 0 {return .Incompatible}
				ic := lane_class(
					l,
					d.class,
				); if ic == nil || ic.size != c.codec.local_bytes {return .Incompatible}
				bytes += c.codec.local_bytes; found = true
			}}
		if !found {return .Incompatible}
	}
	for b, index in w.bindings {
		if cfg.codec.fields[index].id != b.id {return .Incompatible}
		found := false
		for f in cfg.codec.fields {if f.id == b.id {
				if found ||
				   f.codec.local_bytes != b.size ||
				   f.codec.wire_bytes < 0 ||
				   f.codec.wire_bytes > WORLD_NETWORK_BYTES ||
				   len(f.codec.descriptor) == 0 ||
				   f.codec.encode == nil ||
				   f.codec.decode == nil {return .Incompatible}; found = true
			}}
		if !found {return .Incompatible}
	}
	for e, i in cfg.effects {if e.kind == 0 || e.fire == nil || e.codec.encode == nil || e.codec.decode == nil || e.codec.local_bytes < 0 || e.codec.local_bytes > WORLD_EFFECT_BYTES || e.codec.wire_bytes < 0 || e.codec.wire_bytes > WORLD_EFFECT_BYTES || len(e.codec.descriptor) == 0 {return .Invalid}; for p in cfg.effects[:i] {if p.kind == e.kind || (p.fire == e.fire && p.user == e.user) {return .Conflict}}}
	need := u64(
		size_of(World_Network) +
		len(cfg.drivers) * size_of(World_Driver) +
		len(cfg.effects) * size_of(World_Effect_Def) +
		(WORLD_HISTORY_FRAMES * 4 + WORLD_REPAIR_TICKS + 1) * bytes,
	)
	if need > WORLD_MEMORY_BYTES ||
	   world_external_bytes(l) > WORLD_MEMORY_BYTES - need {return .Budget}
	if err := w.provider.admit_detached(
		world_external_bytes(l) + need,
		w.config.reservation_bytes,
	); err != .Ok {return err}
	n, err := new(
		World_Network,
		w.allocator,
	); if err != nil || n == nil {return .Allocation_Failed}
	n.config =
		cfg; n.epoch = cfg.epoch; n.value_bytes = bytes; n.ready = l.ses.is_host; n.authority = l.ses.is_host; n.local_player = l.ses.me
	w.network = n
	ok := false; defer {if !ok {_ = lane_world_network_detach(l)}}

	if e := world_owner_retain(cfg.codec.owner); e != .Ok {return e}; n.wire_owned = true
	for f in cfg.codec.fields {if e := world_network_hold_codec(n, f.codec); e != .Ok {return e}}
	for input in cfg.codec.inputs {if e := world_network_hold_codec(n, input.codec); e != .Ok {return e}}
	for effect in cfg.effects {if e := world_network_hold_codec(n, effect.codec); e != .Ok {return e}}
	n.drivers, err = make(
		[]World_Driver,
		len(cfg.drivers),
		w.allocator,
	); if err != nil || len(n.drivers) != len(cfg.drivers) {return .Allocation_Failed}; copy(n.drivers, cfg.drivers)
	n.effects, err = make(
		[]World_Effect_Def,
		len(cfg.effects),
		w.allocator,
	); if err != nil || len(n.effects) != len(cfg.effects) {return .Allocation_Failed}; copy(n.effects, cfg.effects)
	for d, i in n.drivers {if i > 0 {n.offsets[i] = n.offsets[i - 1] + world_net_input_codec(n, n.drivers[i - 1].class).local_bytes}; _ = d}
	n.accepted_data, err = make(
		[]u8,
		bytes * WORLD_HISTORY_FRAMES,
		w.allocator,
	); if err != nil || len(n.accepted_data) != bytes * WORLD_HISTORY_FRAMES {return .Allocation_Failed}
	n.proposed_data, err = make(
		[]u8,
		bytes * WORLD_HISTORY_FRAMES,
		w.allocator,
	); if err != nil || len(n.proposed_data) != bytes * WORLD_HISTORY_FRAMES {return .Allocation_Failed}
	n.used_data, err = make(
		[]u8,
		bytes * WORLD_HISTORY_FRAMES,
		w.allocator,
	); if err != nil || len(n.used_data) != bytes * WORLD_HISTORY_FRAMES {return .Allocation_Failed}
	n.backup_data, err = make(
		[]u8,
		bytes * WORLD_HISTORY_FRAMES,
		w.allocator,
	); if err != nil || len(n.backup_data) != bytes * WORLD_HISTORY_FRAMES {return .Allocation_Failed}
	n.staged_data, err = make(
		[]u8,
		bytes * (WORLD_REPAIR_TICKS + 1),
		w.allocator,
	); if err != nil || len(n.staged_data) != bytes * (WORLD_REPAIR_TICKS + 1) {return .Allocation_Failed}
	n.used[0] = {
		valid = true,
	}; n.accepted[0] = {
		valid = true,
	}
	for i in 0 ..< len(n.drivers) {n.accepted[0].origin[i] = .Held; n.used[0].origin[i] = .Held}
	if err := world_admit(l, w.published, 0, 0, 0, 0, false); err != .Ok {return err}
	if err := world_network_admit_image(l, w.frames[0].image); err != .Ok {return err}
	ok = true; return .Ok
}
lane_world_network_detach :: proc(l: ^Lane) -> World_Error {
	if l == nil || l.world == nil || l.world.network == nil {return .Ok}
	w := l.world; if w.busy || w.presenting {return .Busy}; n := w.network
	if n.applying {return .Busy}
	context.allocator = w.allocator
	if e := world_owner_check(w.provider.owner); e != .Ok {return e}
	if e := world_owner_check(n.config.codec.owner); e != .Ok {return e}
	delete(
		n.drivers,
	); delete(n.effects); delete(n.accepted_data); delete(n.proposed_data); delete(n.used_data); delete(n.backup_data); delete(n.staged_data)
	world_network_clear_transfers(n,w.allocator)
	for p in n.queue[:n.queue_count] {delete(p.bytes)}
	bd.trace_destroy(&n.trace)
	for codec in n.owned_codecs[:n.owned_codec_count] {
		if codec.release !=
		   nil {if e := codec.release(codec.user); e != .Ok {return e}} else {if e := world_owner_drop(codec.owner); e != .Ok {return e}}
	}
	wire_owner := n.config.codec.owner; wire_owned := n.wire_owned
	free(n, w.allocator); w.network = nil
	if wire_owned {return world_owner_drop(wire_owner)}
	return .Ok
}
@(private)
world_network_hold_codec :: proc(n: ^World_Network, codec: World_Value_Codec) -> World_Error {
	if n.owned_codec_count == len(n.owned_codecs) {return .Capacity}
	if e := world_owner_check(codec.owner); e != .Ok {return e}
	if (codec.acquire == nil) != (codec.release == nil) {return .Invalid}
	if codec.acquire !=
	   nil {if e := codec.acquire(codec.user); e != .Ok {return e}} else {if e := world_owner_retain(codec.owner); e != .Ok {return e}}
	n.owned_codecs[n.owned_codec_count] = codec; n.owned_codec_count += 1
	return .Ok
}
@(private)
world_network_fail :: proc(l: ^Lane, e: World_Error, resync := false) {
	n := l.world.network; n.status = e; n.rejected += 1
	if resync {l.world.status = e; l.world.resync = true}
}
@(private)
world_network_receive :: proc(
	l: ^Lane,
	from: knet.Player_Id,
	peer: ksess.Peer_Id,
	r: ^knet.Reader,
) {
	if l.world.network ==
	   nil {l.world.status = .Missing_Attachment; l.world.resync = true; r.err = true; return}
	n := l.world.network
	if l.world.busy || l.world.presenting || n.applying {world_network_fail(l, .Busy); return}; kind := knet.read_u8(r)
	if r.err {return}
	if kind == SIM_WORLD_CHUNK {
		if l.ses.is_host || peer != ksess.HOST_PEER {world_network_fail(l, .Rejected); return}
		world_network_chunk(l, r); return
	}
	if kind == SIM_WORLD_INPUT {
		if !l.ses.is_host ||
		   from == knet.PLAYER_ID_INVALID {world_network_fail(l, .Rejected); return}
		p, ok := ksess.session_player(
			l.ses,
			from,
		); if !ok || p.spectator {world_network_fail(l, .Rejected); return}
	} else if kind == SIM_WORLD_ACCEPTED || kind == SIM_WORLD_SIGNATURE {
		if l.ses.is_host || peer != ksess.HOST_PEER {world_network_fail(l, .Rejected); return}
	} else if kind == SIM_WORLD_REQUEST {
		if !l.ses.is_host ||
		   from == knet.PLAYER_ID_INVALID {world_network_fail(l, .Rejected); return}
	} else {world_network_fail(l, .Missing_Attachment, !l.ses.is_host && peer == ksess.HOST_PEER)
		r.err = true
		return}
	blob := knet.reader_remaining(r)
	if len(blob) > 64 * 1024 ||
	   n.queue_count == WORLD_NETWORK_QUEUE ||
	   n.queue_bytes >
		   64 * 1024 - len(blob) {world_network_fail(l, .Capacity, !l.ses.is_host); return}
	if e := l.world.provider.admit_detached(
		world_external_bytes(l) + u64(len(blob)),
		l.world.config.reservation_bytes,
	); e != .Ok {world_network_fail(l, e, !l.ses.is_host); return}
	copy_bytes, err := make(
		[]u8,
		len(blob),
		l.world.allocator,
	); if err != nil || len(copy_bytes) != len(blob) {world_network_fail(l, .Allocation_Failed); return}; copy(copy_bytes, blob)
	n.queue[n.queue_count] = {from=from,kind=kind,bytes=copy_bytes,peer=peer}; n.queue_count += 1; n.queue_bytes += len(blob); r.off = len(r.data)
}
@(private)
world_network_chunk :: proc(l: ^Lane, r: ^knet.Reader) {
	n := l.world.network
	rev := knet.read_u32(
		r,
	); mode := World_Transfer_Mode(knet.read_u8(r)); sequence := knet.read_u64(r); epoch := knet.read_u64(r); tick := knet.read_u64(r)
	total := int(
		knet.read_u32(r),
	); index := int(knet.read_u16(r)); count := int(knet.read_u16(r)); digest: bd.Digest; copy(digest[:], knet.reader_view(r, 32)); blob := knet.reader_remaining(r)
	if r.err ||
	   rev != WORLD_NETWORK_REV ||
	   mode > .Reset ||
	   sequence == 0 ||
	   epoch == 0 ||
	   total < bd.SIGNATURE_BYTES ||
	   total > WORLD_NETWORK_BYTES ||
	   count != (total + WORLD_NETWORK_CHUNK - 1) / WORLD_NETWORK_CHUNK ||
	   count > 32 ||
	   index >= count ||
	   len(blob) !=
		   min(
			   WORLD_NETWORK_CHUNK,
			   total - index * WORLD_NETWORK_CHUNK,
		   ) {world_network_fail(l, .Invalid); r.err = true; return}
	if epoch < n.epoch ||
	   (epoch == n.epoch && sequence <= n.received_sequence) {n.duplicates += 1; return}
	if epoch != n.epoch &&
	   (mode != .Reset && mode != .Welcome) {world_network_fail(l, .Incompatible); return}
	// A discarded prefix remains obsolete after recovery publishes readiness.
	// This marker is ordinary-only and never advances a validated receipt or
	// touches pending Reset/Welcome ownership. All guards above still apply.
	if mode == .Correction {
	 if !n.ready {
	  if n.ignored_correction_epoch!=epoch {
	   n.ignored_correction_epoch=epoch;n.ignored_correction_sequence=sequence
	  }else{n.ignored_correction_sequence=max(n.ignored_correction_sequence,sequence)}
	  n.duplicates+=1;return
	 }
	 if n.ignored_correction_epoch==epoch && sequence<=n.ignored_correction_sequence {n.duplicates+=1;return}
	}
	if epoch>n.epoch {world_network_retire_transfer_epochs(n,epoch,l.world.allocator)}
	if world_network_queued_chunk(l,&n.applying_transfer,mode,sequence,epoch,tick,total,index,count,digest,blob) {return}
	for i in 0..<n.completed_count {
	 slot:=(n.completed_head+i)%WORLD_NETWORK_TRANSFERS
	 if world_network_queued_chunk(l,&n.completed[slot],mode,sequence,epoch,tick,total,index,count,digest,blob) {return}
	}
	if len(n.transfer) == 0 {
		payload:=world_network_transfer_bytes(n)
		if n.completed_count>=WORLD_NETWORK_TRANSFERS || payload>WORLD_NETWORK_BYTES || u64(total)>u64(WORLD_NETWORK_BYTES)-payload {world_network_fail(l,.Capacity,true);return}
		if e := l.world.provider.admit_detached(
			world_external_bytes(l) + u64(total),
			l.world.config.reservation_bytes,
		); e != .Ok {world_network_fail(l, e, true); return}
		data, err := make(
			[]u8,
			total,
			l.world.allocator,
		); if err != nil || len(data) != total {delete(data,l.world.allocator);world_network_fail(l, .Allocation_Failed,true); return}
		n.transfer =
			data; n.transfer_sequence = sequence; n.transfer_epoch = epoch; n.transfer_tick = tick; n.transfer_mode = mode; n.transfer_chunks = count; n.transfer_hash = digest; n.transfer_received = 0; n.transfer_seen = {}
	}
	if n.transfer_sequence != sequence ||
	   n.transfer_epoch != epoch ||
	   n.transfer_tick != tick ||
	   n.transfer_mode != mode ||
	   len(n.transfer) != total ||
	   n.transfer_hash != digest {world_network_fail(l, .Conflict); return}
	dst := n.transfer[index * WORLD_NETWORK_CHUNK:index * WORLD_NETWORK_CHUNK + len(blob)]
	if n.transfer_seen[index] {if mem.compare(dst, blob) != 0 {world_network_fail(l, .Conflict, true)} else {n.duplicates += 1}; return}
	copy(dst, blob); n.transfer_seen[index] = true; n.transfer_received += 1; r.off = len(r.data)
	if n.transfer_received==n.transfer_chunks {
	 if n.completed_count>=WORLD_NETWORK_TRANSFERS {world_network_fail(l,.Capacity,true);return}
	 slot:=(n.completed_head+n.completed_count)%WORLD_NETWORK_TRANSFERS
	 n.completed[slot]={bytes=n.transfer,hash=n.transfer_hash,sequence=n.transfer_sequence,epoch=n.transfer_epoch,tick=n.transfer_tick,mode=n.transfer_mode,chunks=n.transfer_chunks}
	 n.completed_count+=1
	 // Ownership moves without allocation; no decode or publication in receive.
	 n.transfer=nil;n.transfer_seen={};n.transfer_hash={};n.transfer_sequence=0;n.transfer_epoch=0;n.transfer_tick=0;n.transfer_mode={};n.transfer_chunks=0;n.transfer_received=0
	}
}

@(private)
world_network_send_inputs :: proc(l: ^Lane, accepted: bool) {
	n := l.world.network; head := l.world.head
	if head == 0 {return}
	first := head
	for first > 1 &&
	    head - first <
		    WORLD_REPAIR_TICKS -
			    1 {prior := &n.used[(first - 1) % WORLD_HISTORY_FRAMES]; if !prior.valid || prior.tick != first - 1 {break}; first -= 1}
	if !accepted {
		local_count := 0; for d in n.drivers {if d.player == l.ses.me {local_count += 1}}; if local_count == 0 {return}
		for tick := head;
		    tick >= first;
		    tick -= 1 {have := true; for d in n.drivers {if d.player == l.ses.me {ic := lane_class(l, d.class); _, ok := input_read(&ic.ring, tick); have = have && ok}}; if !have {first = tick + 1; break}; if tick == first {break}}
		if first > head {return}
	}
	writer := ksess.session_app_begin(l.ses, l.tag)
	knet.write_u8(writer, accepted ? SIM_WORLD_ACCEPTED : SIM_WORLD_INPUT)
	knet.write_u32(
		writer,
		WORLD_NETWORK_REV,
	); for byte in n.config.identity.input_schema {knet.write_u8(writer, byte)}; knet.write_u64(writer, n.epoch)
	if !accepted {knet.write_u64(writer,n.protocol.bootstrap_sequence)}
	knet.write_u64(
		writer,
		head,
	); knet.write_u64(writer, first); knet.write_u8(writer, u8(head - first + 1))
	entries := 0; for d in n.drivers {if accepted || d.player == l.ses.me {entries += 1}}
	knet.write_u8(writer, u8(entries))
	for tick := first; tick <= head; tick += 1 {
		row := &n.used[tick % WORLD_HISTORY_FRAMES]; data := world_net_data(n, n.used_data, tick)
		if !row.valid || row.tick != tick {world_network_fail(l, .History_Missing, true); return}
		for d, i in n.drivers {if accepted || d.player == l.ses.me {
				codec := world_net_input_codec(n, d.class); wire: [MAX_INPUT_SIZE]u8
				local := world_net_driver_bytes(
					n,
					data,
					i,
				); if !accepted {ic := lane_class(l, d.class); local, _ = input_read(&ic.ring, tick)}
				if e := codec.encode(codec.user, local, wire[:codec.wire_bytes]);
				   e != .Ok {world_network_fail(l, e, true); return}
				knet.write_u8(
					writer,
					u8(i),
				); knet.write_u8(writer, u8(accepted ? row.origin[i] : World_Input_Origin.Submitted)); knet.write_u64(writer, accepted ? row.sequence[i] : tick)
				for b in wire[:codec.wire_bytes] {knet.write_u8(writer, b)}
			}}
	}
	if accepted {
		count:=0;for d in n.drivers {if d.class==0 {count+=1}};knet.write_u8(writer,u8(count))
		for d,i in n.drivers {if d.class==0 {
			r:=&n.protocol.receipts[i];available:=world_protocol_host_receipt_current(l,i)&&r.available
			knet.write_player_id(writer,d.player);knet.write_u64(writer,r.bootstrap_sequence);knet.write_u8(writer,available?1:0);knet.write_u64(writer,available?r.proposal_tick:0)
		}}
	}
	ksess.session_app_flush(l.ses, accepted ? ksess.BROADCAST_PEER : ksess.HOST_PEER, accepted?.Reliable:.Stream)
}
@(private)
world_network_accept_packet :: proc(l: ^Lane, p: World_Net_Packet, validate_only := false) -> World_Error {
	n := l.world.network; w := l.world; r := knet.reader_make(p.bytes)
	rev := knet.read_u32(
		&r,
	); schema: bd.Digest; copy(schema[:], knet.reader_view(&r, 32)); epoch := knet.read_u64(&r)
	is_authority := p.kind == SIM_WORLD_ACCEPTED
	bootstrap:u64
	if !is_authority {bootstrap=knet.read_u64(&r)}
	sequence := knet.read_u64(&r); first := knet.read_u64(&r); count := int(knet.read_u8(&r)); entries := int(knet.read_u8(&r))
	if r.err ||
	   rev != WORLD_NETWORK_REV ||
	   schema != n.config.identity.input_schema ||
	   (epoch == 0 || epoch > n.epoch) ||
	   sequence == 0 ||
	   count < 1 ||
	   count > WORLD_REPAIR_TICKS ||
	   first == 0 ||
	   first > max(u64) - u64(count - 1) ||
	   sequence != first + u64(count - 1) ||
	   entries > len(n.drivers) {return .Invalid}
	stale := epoch < n.epoch
	last := first + u64(count - 1)
	if !stale &&
	   ((w.head <= max(u64) - WORLD_REPAIR_TICKS && last > w.head + WORLD_REPAIR_TICKS) ||
			   w.head >= WORLD_HISTORY_FRAMES &&
				   first <= w.head - WORLD_HISTORY_FRAMES) {return .Repair_Limit}
	if is_authority && entries != len(n.drivers) {return .Missing_Attachment}
	expected := 0; for d in n.drivers {if is_authority || d.player == p.from {expected += 1}}
	if entries != expected {return .Rejected}
	// Decode and validate EVERY row into bounded operation-local storage before
	// changing an accepted ledger or executing authored game code.
	rows: [WORLD_REPAIR_TICKS]World_Input_Row
	values: [WORLD_REPAIR_TICKS][WORLD_NETWORK_DRIVERS][MAX_INPUT_SIZE]u8
	for j in 0 ..< count {
		row := &rows[j]; row.tick = first + u64(j); row.valid = true; seen: [WORLD_NETWORK_DRIVERS]bool
		for _ in 0 ..< entries {
			i := int(
				knet.read_u8(&r),
			); origin := World_Input_Origin(knet.read_u8(&r)); seq := knet.read_u64(&r)
			if r.err ||
			   i >= len(n.drivers) ||
			   seen[i] ||
			   (!is_authority && n.drivers[i].player != p.from) ||
			   origin > .Authority ||
			   (is_authority && origin == .Unknown) ||
			   (!is_authority && origin != .Submitted) {return .Rejected}
			seen[i] = true; c := world_net_input_codec(n, n.drivers[i].class)
			wire := knet.reader_view(&r, c.wire_bytes); if r.err {return .Invalid}
			if e := c.decode(c.user, wire, values[j][i][:c.local_bytes]); e != .Ok {return e}
			if !is_authority {ic := lane_class(l, n.drivers[i].class); if e := world_network_validate_input(l, ic, values[j][i][:c.local_bytes]); e != .Ok {return e}}
			// A submitted tick's stable source sequence is that tick. Held
			// authority decisions retain their predecessor's sequence (possibly0).
			if (origin != .Held && seq != row.tick) || seq > row.tick {return .Conflict}
			row.sequence[i] = seq; row.origin[i] = is_authority ? origin : .Submitted
		}
	}
	receipts:[WORLD_NETWORK_DRIVERS]World_Protocol_Receipt;receipt_count:=0
	if is_authority {
		receipt_count=int(knet.read_u8(&r));expected_receipts:=0;for d in n.drivers {if d.class==0 {expected_receipts+=1}}
		if r.err || receipt_count!=expected_receipts {return .Invalid}
		at:=0
		for d,i in n.drivers {if d.class==0 {
			player:=knet.read_player_id(&r);scope:=knet.read_u64(&r);available:=knet.read_u8(&r);newest:=knet.read_u64(&r)
			if r.err || player!=d.player || available>1 || (available==0 && newest!=0) || (available==1 && (scope==0 || newest==0 || (newest>sequence && newest-sequence>WORLD_REPAIR_TICKS))) {return .Invalid}
			receipts[i]={valid=true,available=available==1,epoch=epoch,bootstrap_sequence=scope,proposal_tick=newest};at+=1
		}}
	}
	if len(knet.reader_remaining(&r)) != 0 {return .Invalid}
	// An authenticated obsolete epoch still passes every bounded structural,
	// driver, origin, sequence and typed/trailing check above. It contributes
	// nothing to current ledgers or readiness and cannot trigger a replay.
	if stale {n.duplicates += 1; return .Ok}
	if !is_authority {if e:=world_protocol_proposal_scope(l,p,bootstrap);e!=.Ok {return e}}
	changed := max(u64)
	for row, j in rows[:count] {
		stored :=
			is_authority ? &n.accepted[row.tick % WORLD_HISTORY_FRAMES] : &n.proposed[row.tick % WORLD_HISTORY_FRAMES]
		stored_data := world_net_data(
			n,
			is_authority ? n.accepted_data : n.proposed_data,
			row.tick,
		)
		used := &n.used[row.tick % WORLD_HISTORY_FRAMES]
		for d, i in n.drivers {if row.origin[i] != .Unknown {
				c := world_net_input_codec(n, d.class); candidate := values[j][i][:c.local_bytes]
				if stored.valid && stored.tick == row.tick && stored.origin[i] != .Unknown {
					if stored.sequence[i] != row.sequence[i] ||
					   stored.origin[i] != row.origin[i] ||
					   mem.compare(world_net_driver_bytes(n, stored_data, i), candidate) !=
						   0 {n.conflicts += 1; return .Conflict}
					n.duplicates += 1
				}
				if is_authority &&
				   used.valid &&
				   used.tick == row.tick &&
				   mem.compare(
					   world_net_driver_bytes(n, world_net_data(n, n.used_data, row.tick), i),
					   candidate,
				   ) !=
					   0 {changed = min(changed, row.tick)}
			}}
	}
	if is_authority &&
	   changed != max(u64) &&
	   (changed <= w.confirmed ||
			   changed > w.head ||
			   w.head - (changed - 1) >
				   WORLD_REPAIR_TICKS) {return changed <= w.confirmed ? .Conflict : .Repair_Limit}
	if validate_only {return .Ok}
	if !is_authority {
		if e:=world_protocol_note_proposal(l,p,bootstrap,rows[:count],values[:count]);e!=.Ok {return e}
	}
	if !is_authority {
		// Authority never retroactively replaces its accepted held decisions.
		// Late proposals are stale, while equivocation above remains observable.
		for row, j in rows[:count] {if row.tick > w.head {
				slot := &n.proposed[row.tick % WORLD_HISTORY_FRAMES]; if !slot.valid || slot.tick != row.tick {slot^ = {
						tick  = row.tick,
						valid = true,
					}}
				for d, i in n.drivers {if row.origin[i] != .Unknown {c := world_net_input_codec(n, d.class); slot.origin[i] = .Submitted; slot.sequence[i] = row.sequence[i]; copy(world_net_driver_bytes(n, world_net_data(n, n.proposed_data, row.tick), i), values[j][i][:c.local_bytes])}}
			}}
		return .Ok
	}
	if n.accepted_batches==max(u64) {return .Capacity}
	n.backup = n.accepted; copy(n.backup_data, n.accepted_data)
	for row, j in rows[:count] {
		n.accepted[row.tick % WORLD_HISTORY_FRAMES] = row
		for d, i in n.drivers {c := world_net_input_codec(n, d.class); copy(world_net_driver_bytes(n, world_net_data(n, n.accepted_data, row.tick), i), values[j][i][:c.local_bytes])}
	}
	// v2 repairs only inside a full-signature verification transaction. Merely
	// receiving accepted rows is not a state/confirmation publication boundary.
	world_protocol_accept_receipt(l,sequence,receipts[:])
	world_protocol_advance_accepted(l)
	n.accepted_batches += 1
	return .Ok
}
@(private)
world_network_after_tick :: proc(l: ^Lane) {
	n := l.world.network; if n == nil || !n.ready {return}
	world_network_send_inputs(l, l.ses.is_host)
	if l.ses.is_host &&
	   l.world.head % u64(l.snap_every) ==
		   0 {if e := world_protocol_send_signature(l); e != .Ok {world_network_fail(l, e, true)}}
}
// Explicit request keeps hard recovery separate from ordinary settled history.
lane_world_request_reset :: proc(l: ^Lane) -> World_Error {
	if l == nil || l.world == nil || l.world.network == nil || l.ses.is_host {return .Unsupported}
	n := l.world.network
	if l.world.busy || l.world.presenting || n.applying {return .Busy}
	world_network_clear_transfers(n,l.world.allocator)
	writer := ksess.session_app_begin(l.ses, l.tag); knet.write_u8(writer, SIM_WORLD_REQUEST); knet.write_u32(writer, WORLD_NETWORK_REV); knet.write_u64(writer, n.epoch); ksess.session_app_flush(l.ses, ksess.HOST_PEER)
	world_protocol_invalidate(n)
	n.ready = false; return .Ok
}

@(private)
world_network_apply_transfer :: proc(l: ^Lane) -> World_Error {
	w := l.world; n := w.network; selected:=&n.applying_transfer
	if len(selected.bytes)==0 {return .Ok}
	defer {delete(selected.bytes,w.allocator);selected^={}}
	if bd.hash_bytes(selected.bytes) != selected.hash {return .Invalid}
	if selected.epoch < n.epoch ||
	   (selected.epoch == n.epoch &&
			   selected.sequence <= n.received_sequence) {n.duplicates += 1; return .Ok}
	reset := selected.mode != .Correction
	if selected.mode == .Welcome && n.ready {return .Rejected}
	if selected.mode == .Reset && n.ready && selected.epoch == n.epoch {return .Rejected}
	if !reset && (!n.ready || selected.epoch != n.epoch) {return .Incompatible}
	if n.protocol.full_states_received==max(u64) {return .Capacity}
	cp, baseline, values, signature, error := world_wire_decode(l, selected.bytes)
	if error !=
	   .Ok {return error}; defer world_checkpoint_destroy(&cp); defer delete(values, w.allocator)
	n.outbound_bytes += u64(len(values)); defer {n.outbound_bytes -= u64(len(values))}
	if signature.epoch != selected.epoch || signature.tick != selected.tick {return .Invalid}
	if !reset &&
	   (cp.tick < w.confirmed ||
			   cp.tick > w.head ||
			   w.head - w.confirmed >
				   WORLD_REPAIR_TICKS) {return cp.tick < w.confirmed ? .Settled : .Repair_Limit}
	if !reset &&
	   cp.tick > w.confirmed &&
	   (n.incoming_count == 0 ||
			   n.incoming[0].tick > w.confirmed + 1 ||
			   world_record(w, w.confirmed) == nil) {return .History_Missing}
	// Every known authority decision is immutable, including rows before this
	// checkpoint. Conflicting provenance is a protocol error, not solver desync.
	if !reset {for row, j in n.incoming[:n.incoming_count] {
			old := &n.accepted[row.tick % WORLD_HISTORY_FRAMES]
			if old.valid &&
			   old.tick == row.tick {for d, i in n.drivers {if old.origin[i] != .Unknown {
						if old.origin[i] != row.origin[i] ||
						   old.sequence[i] != row.sequence[i] ||
						   mem.compare(
							   world_net_driver_bytes(
								   n,
								   world_net_data(n, n.accepted_data, row.tick),
								   i,
							   ),
							   world_net_driver_bytes(
								   n,
								   values[j * n.value_bytes:(j + 1) * n.value_bytes],
								   i,
							   ),
						   ) !=
							   0 {n.conflicts += 1; return .Conflict}
					}}}
		}}
	n.backup = n.accepted; copy(n.backup_data, n.accepted_data)
	for row, j in n.incoming[:n.incoming_count] {n.accepted[row.tick % WORLD_HISTORY_FRAMES] = row; copy(world_net_data(n, n.accepted_data, row.tick), values[j * n.value_bytes:(j + 1) * n.value_bytes])}
	slot := cp.tick % WORLD_HISTORY_FRAMES; old_used := n.used[slot]
	old_used_data: [WORLD_NETWORK_DRIVERS *
	MAX_INPUT_SIZE]u8; copy(old_used_data[:], world_net_data(n, n.used_data, cp.tick))
	baseline_values := values[(n.incoming_count - 1) *
	n.value_bytes:n.incoming_count *
	n.value_bytes]
	if reset {n.used[slot] = baseline; copy(world_net_data(n, n.used_data, cp.tick), baseline_values)}
	n.check_signature = signature
	result: World_Result
	if reset || cp.tick == w.confirmed {
		if !reset {world_network_trace_settled(l, signature, selected.bytes)}
		result = world_reconcile(l, &cp, reset, {})
	} else {
		// Accepted inputs and every action/FX in the missing prefix are replayed
		// before the authoritative image is accepted. Verification occurs while all
		// state is staged, so failure publishes neither partial state nor effects.
		result = world_operation(
			l,
			world_record(w, w.confirmed),
			nil,
			w.head,
			false,
			{},
			confirm_authority = false,
			verify_at = &cp,
			confirm_to = cp.tick,
		)
	}
	if result.error != .Ok {
		n.accepted = n.backup; copy(n.accepted_data, n.backup_data)
		if reset {n.used[slot] = old_used; copy(world_net_data(n, n.used_data, cp.tick), old_used_data[:n.value_bytes])}
		return result.error
	}
	if reset {
		n.used = {}; n.accepted = {}; n.proposed = {}; n.stage_count = 0
		n.used[slot] = baseline; copy(world_net_data(n, n.used_data, cp.tick), baseline_values)
		for row, j in n.incoming[:n.incoming_count] {n.accepted[row.tick % WORLD_HISTORY_FRAMES] = row; copy(world_net_data(n, n.accepted_data, row.tick), values[j * n.value_bytes:(j + 1) * n.value_bytes])}
		if n.epoch!=signature.epoch {n.ignored_correction_epoch=0;n.ignored_correction_sequence=0}
		n.epoch = signature.epoch; w.epoch = signature.epoch
		world_protocol_invalidate(n);n.protocol.bootstrap_sequence=selected.sequence;n.protocol.accepted_through=signature.tick;n.protocol.matched_signature_tick=signature.tick;n.protocol.canonical_floor=n.incoming[0].tick
		n.protocol.signature_head=0;n.protocol.signature_count=0

	}
	n.protocol.full_states_received+=1;n.protocol.error=.Ok;n.protocol.matched_signature_tick=signature.tick
	n.protocol.accepted_through=max(n.protocol.accepted_through,w.confirmed)
	world_protocol_advance_accepted(l)
	n.ready =
		true; n.last_signature = signature; n.received_sequence = selected.sequence; n.status = .Ok; w.resync = false; return .Ok
}
@(private)
world_network_ingest :: proc(l: ^Lane) {
	w := l.world; n := w.network
	if n.authority != l.ses.is_host ||
	   n.local_player != l.ses.me {world_network_fail(l, .Unsupported, true); return}
	if n.applying {return}; n.applying = true; defer {n.applying = false}
	// A failed receive must not be hidden by publishing an older queued
	// correction. Explicit recovery retires the old receive owners first.
	can_apply:=n.completed_count>0 && (!w.resync || !n.ready || n.completed[n.completed_head].mode!=.Correction)
	if can_apply {
	 slot:=n.completed_head;n.applying_transfer=n.completed[slot];n.completed[slot]={}
	 n.completed_head=(slot+1)%WORLD_NETWORK_TRANSFERS;n.completed_count-=1
		if e := world_network_apply_transfer(l);
		   e != .Ok {world_network_fail(l, e, e != .Settled && e != .Rejected)}
	}
	count := n.queue_count; n.queue_count = 0
	for i in 0 ..< count {
		p := n.queue[i]; n.queue[i] = {}; n.queue_bytes -= len(p.bytes)
		e := World_Error.Ok
		if p.kind == SIM_WORLD_REQUEST {
			r := knet.reader_make(p.bytes); rev := knet.read_u32(&r); epoch := knet.read_u64(&r)
			if r.err ||
			   rev != WORLD_NETWORK_REV ||
			   epoch == 0 ||
			   epoch > n.epoch ||
			   len(knet.reader_remaining(&r)) != 0 {e = .Incompatible} else {
				player, ok := ksess.session_player(
					l.ses,
					p.from,
				); if !ok {e = .Rejected} else {e = lane_world_send_checkpoint(l, player.peer, .Reset)}
			}
		} else if n.ready {
			if p.kind==SIM_WORLD_SIGNATURE {e=world_protocol_receive_signature(l,p)} else {e = world_network_accept_packet(l, p, validate_only=w.resync)}
		}
		delete(p.bytes, w.allocator)
		if e != .Ok {n.protocol.error=e;world_network_fail(l, e, p.kind == SIM_WORLD_ACCEPTED || p.kind == SIM_WORLD_SIGNATURE)}
	}
	if !n.authority && n.ready && !w.resync {if e:=world_protocol_apply_signature(l);e!=.Ok {n.protocol.error=e;world_network_fail(l,e,true)}}
}
// Confirmed-only signatures. A guessed local row is never advertised as a
// confirmed physics digest. All bytes are canonical and cover observations/FX.
lane_world_confirmed_signature :: proc(l: ^Lane, tick: u64) -> (bd.Signature, World_Error) {
	if l == nil || l.world == nil || l.world.network == nil {return {}, .Unsupported}
	w := l.world; n := w.network
	if !l.ses.is_host && tick > w.confirmed {return {}, .Rejected}
	f := world_record(w, tick); if f == nil {return {}, .History_Missing}
	if e := w.provider.admit_detached(
		world_external_bytes(l) + WORLD_NETWORK_BYTES,
		w.config.reservation_bytes,
	); e != .Ok {return {}, e}
	n.outbound_bytes += WORLD_NETWORK_BYTES; defer {n.outbound_bytes -= WORLD_NETWORK_BYTES}
	parts, e := world_wire_parts(
		l,
		f,
	); if e != .Ok {return {}, e}; defer {for part in parts {delete(part, l.allocator)}}
	sig, se := bd.sign(
		{n.config.identity, n.epoch, tick, parts},
	); return sig, se == .None ? .Ok : .Invalid
}
lane_world_network_trace :: proc(l: ^Lane) -> ^bd.Trace {return(
		l != nil && l.world != nil && l.world.network != nil ? &l.world.network.trace : nil \
	)}
@(private)
world_network_trace_settled :: proc(
	l: ^Lane,
	expected: bd.Signature,
	wire: []u8,
	candidate: ^World_Frame = nil,
) {
	n := l.world.network; if n.trace.ready {return}
	f := candidate; if f == nil {f = world_record(l.world, expected.tick)}; if f == nil {return}
	if e := l.world.provider.admit_detached(
		world_external_bytes(l) + WORLD_NETWORK_BYTES + 128 * 1024,
		l.world.config.reservation_bytes,
	); e != .Ok {return}
	n.outbound_bytes +=
		WORLD_NETWORK_BYTES +
		128 * 1024; defer {n.outbound_bytes -= WORLD_NETWORK_BYTES + 128 * 1024}
	parts, e := world_wire_parts(
		l,
		f,
	); if e != .Ok {return}; defer {for part in parts {delete(part, l.allocator)}}
	actual := bd.Frame_View{n.config.identity, n.epoch, f.tick, parts}
	incoming := bd.Frame_View{expected.identity, expected.epoch, expected.tick, {}}
	parts_view, _, parse_error := world_wire_view(
		wire,
		expected,
	); if parse_error != .Ok {return}; incoming.parts = parts_view
	first := l.world.confirmed
	accepted, ae := world_trace_inputs(
		l,
		n.accepted[:],
		n.accepted_data,
		first,
		l.world.head,
	); if ae != .Ok {return}; defer delete(accepted, l.allocator)
	predicted, pe := world_trace_inputs(
		l,
		n.used[:],
		n.used_data,
		first,
		l.world.head,
	); if pe != .Ok {return}; defer delete(predicted, l.allocator)
	need := u64(
		len(accepted) + len(predicted),
	); for p in bd.Part {need += u64(len(incoming.parts[p]) + len(actual.parts[p]))}
	if e := l.world.provider.admit_detached(
		world_external_bytes(l) + need,
		l.world.config.reservation_bytes,
	); e != .Ok {return}
	_ = bd.trace_capture(
		&n.trace,
		incoming,
		actual,
		{
			from_tick = first,
			to_tick = l.world.head,
			source = u64(ksess.HOST_PEER),
			sequence = n.applying_transfer.sequence,
			depth = u32(l.world.head - first),
			accepted_inputs = accepted,
			predicted_inputs = predicted,
		},
		allocator = l.allocator,
	)
}

// Authority-only complete reset of the current accepted state into a new
// protocol/effect epoch. No client can manufacture an authority reset through
// the local checkpoint API. A behavior/roster change still requires a new codec.
lane_world_begin_epoch :: proc(l: ^Lane, epoch: u64) -> World_Error {
	if l == nil || l.world == nil || l.world.network == nil || !l.ses.is_host {return .Rejected}
	w :=
		l.world; n := w.network; if epoch <= n.epoch {return .Settled}; if w.busy || w.presenting || n.applying {return .Busy}
	checkpoint, error := lane_world_checkpoint(
		l,
		w.head,
	); if error != .Ok {return error}; defer world_checkpoint_destroy(&checkpoint)
	row := n.used[w.head % WORLD_HISTORY_FRAMES]
	data: [WORLD_NETWORK_DRIVERS *
	MAX_INPUT_SIZE]u8; copy(data[:], world_net_data(n, n.used_data, w.head))
	n.applying = true; result := world_reconcile(l, &checkpoint, true, {}); n.applying = false
	if result.error != .Ok {return result.error}
	n.epoch =
		epoch; w.epoch = epoch; n.accepted = {}; n.used = {}; n.proposed = {}; n.received_sequence = 0; n.sequence = 0
	n.ignored_correction_epoch=0;n.ignored_correction_sequence=0
	world_protocol_invalidate(n);n.protocol.bootstrap_sequence=0;n.protocol.matched_signature_tick=0;n.protocol.accepted_through=w.confirmed;n.protocol.canonical_floor=w.confirmed;n.protocol.signature_head=0;n.protocol.signature_count=0;n.protocol.receipts={}
	world_network_clear_transfers(n,w.allocator)
	n.accepted[w.head % WORLD_HISTORY_FRAMES] = row; n.used[w.head % WORLD_HISTORY_FRAMES] = row
	copy(
		world_net_data(n, n.accepted_data, w.head),
		data[:n.value_bytes],
	); copy(world_net_data(n, n.used_data, w.head), data[:n.value_bytes])
	return .Ok
}

// Validate native catalog/profile support while the complete tick is still a
// disposable candidate. An unsupported spawned asset must never commit first
// and only discover that it cannot be exported on the following send.
@(private)
world_network_admit_image :: proc(l: ^Lane, image: rawptr) -> World_Error {
	if l.world.network == nil {return .Ok}; n := l.world.network
	execution := l.world.candidate != nil ? l.world.candidate : l.world.published
	if e := world_admit(l, execution, 0, 0, 0, 0, true); e != .Ok {return e}
	count: int; error: World_Error
	if n.config.codec.admit !=
	   nil {count, error = n.config.codec.admit(n.config.codec.user, execution)} else {count, error = n.config.codec.recovery_encode(n.config.codec.user, image, nil)}
	after := world_admit(l, execution, 0, 0, 0, 0, false)
	if error != .Ok {return error}; if after != .Ok {return after}
	if count <= 0 || count > WORLD_NETWORK_BYTES {return .Capacity}
	total := bd.SIGNATURE_BYTES + 4 + count
	for part in ([?]bd.Part {
			.Solver,
			.Side,
			.Observations,
		}) {size, e := n.config.codec.encode(n.config.codec.user, image, part, nil); if e != .Ok {return e}; if size < 0 || size > WORLD_NETWORK_BYTES - total {return .Capacity}; total += size}
	for f in n.config.codec.fields {if f.codec.wire_bytes > WORLD_NETWORK_BYTES - total - 8 {return .Capacity}; total += f.codec.wire_bytes + 8}
	total += 5
	for d in n.drivers {c := world_net_input_codec(n, d.class); total += 10 + WORLD_REPAIR_TICKS * (9 + c.wire_bytes)}
	total += 1 + WORLD_EFFECTS_PER_TICK * (2 + 8 + WORLD_EFFECT_BYTES)
	return total <= WORLD_NETWORK_BYTES ? .Ok : .Capacity
}

@(private)
world_trace_inputs :: proc(
	l: ^Lane,
	rows: []World_Input_Row,
	data: []u8,
	first, last: u64,
) -> (
	[]u8,
	World_Error,
) {
	n :=
		l.world.network; if last < first || last - first > WORLD_REPAIR_TICKS {return nil, .Repair_Limit}
	writer := knet.writer_make(256, l.allocator); defer knet.writer_destroy(&writer)
	knet.write_u64(
		&writer,
		first,
	); knet.write_u64(&writer, last); knet.write_u8(&writer, u8(len(n.drivers)))
	for tick := first; tick <= last; tick += 1 {
		row := &rows[tick % WORLD_HISTORY_FRAMES]; valid := row.valid && row.tick == tick
		knet.write_u8(&writer, valid ? 1 : 0)
		if valid {for d, i in n.drivers {
				c := world_net_input_codec(n, d.class); wire: [MAX_INPUT_SIZE]u8
				if e := c.encode(
					c.user,
					world_net_driver_bytes(n, world_net_data(n, data, tick), i),
					wire[:c.wire_bytes],
				); e != .Ok {return nil, e}
				knet.write_u8(
					&writer,
					u8(row.origin[i]),
				); knet.write_u64(&writer, row.sequence[i]); for b in wire[:c.wire_bytes] {knet.write_u8(&writer, b)}
			}}
		if tick == max(u64) {break}
	}
	if len(knet.writer_bytes(&writer)) > 64 * 1024 {return nil, .Capacity}
	result, err := make(
		[]u8,
		len(knet.writer_bytes(&writer)),
		l.allocator,
	); if err != nil {return nil, .Allocation_Failed}; copy(result, knet.writer_bytes(&writer)); return result, .Ok
}

@(private)
world_network_validate_input :: proc(l: ^Lane, ic: ^Input_Class, value: []u8) -> World_Error {
	if ic.validate == nil {return .Ok}
	w := l.world; world_capture_fields(w, w.live_backup)
	status, resync := w.status, w.resync
	allowed := ic.validate(l.user, raw_data(value)); changed := false
	for b in w.bindings {if !predict_matches(b.entity, b.desc, w.live_backup[b.offset:b.offset + b.size]) {changed = true; break}}
	if changed {world_restore_fields(w, w.live_backup)}
	if changed || w.status != status || w.resync != resync {return .Unsupported}
	return allowed ? .Ok : .Rejected
}

// Read-only complete canonical diagnostics, available to confirmed clients and
// committed authorities. This does NOT export a native recovery attachment and
// does not send, open/step/restore a world, confirm state, or clear a resync.
// Success atomically replaces out. Failure preserves out and all publication.
lane_world_diagnostic_frame :: proc(
	l: ^Lane,
	tick: u64,
	out: ^World_Diagnostic_Frame,
	allocator := mem.Allocator{},
) -> World_Error {
	if out == nil {return .Invalid}
	if l == nil || l.world == nil || l.world.network == nil || l.ses == nil {return .Unsupported}
	w := l.world; n := w.network
	if w.busy || w.publishing || w.presenting {return .Busy}
	context.allocator = w.allocator
	if e := world_owner_check(w.provider.owner); e != .Ok {return e}
	if e := world_owner_check(out.owner); e != .Ok {return e}
	if !world_owner_is_empty(w.provider.detached_owner) &&
	   allocator.procedure != nil &&
	   (allocator.procedure != l.allocator.procedure ||
			   allocator.data != l.allocator.data) {return .Unsupported}
	mark, budget_error := world_budget_begin(w.provider.budget, 4 * 1024 * 1024)
	if budget_error != .Ok {return budget_error}; defer world_budget_end(w.provider.budget, &mark)
	// ready can be false while valid older confirmed history survives a reset
	// request. The received signature proves bootstrap happened even at tick0.
	if !l.ses.is_host && (n.last_signature.epoch == 0 || tick > w.confirmed) {return .Rejected}
	if tick > w.head {return .History_Missing}
	f := world_record(w, tick); if f == nil {return .History_Missing}
	if e := w.provider.admit_detached(
		world_external_bytes(l) + WORLD_NETWORK_BYTES,
		w.config.reservation_bytes,
	); e != .Ok {return e}
	context.allocator = l.allocator
	n.outbound_bytes += WORLD_NETWORK_BYTES
	defer {n.outbound_bytes -= WORLD_NETWORK_BYTES}
	parts, error := world_wire_parts(l, f)
	if error != .Ok {return error}
	defer {for part in parts {delete(part, l.allocator)}}
	total := 0; for part in parts {total += len(part)}
	// Transition from conservative composition allowance to the actual owned
	// temporary bytes before allocating the final detached owner.
	n.outbound_bytes -= WORLD_NETWORK_BYTES - u64(total)
	defer {n.outbound_bytes += WORLD_NETWORK_BYTES - u64(total)}
	view := bd.Frame_View{n.config.identity, n.epoch, tick, parts}
	signature, sign_error := bd.sign(view); if sign_error != .None {return .Invalid}
	owner_allocator := allocator.procedure != nil ? allocator : l.allocator
	candidate, copy_error := world_diagnostic_copy(
		view,
		signature,
		owner_allocator,
		w.provider.admit_detached,
		world_external_bytes(l),
		w.provider.detached_owner,
		w.provider.budget,
	)
	if copy_error != .Ok {return copy_error}
	if e := world_budget_reconcile(w.provider.budget, mark);
	   e != .Ok {world_diagnostic_frame_destroy(&candidate); return e}
	old := out^; out^ = candidate; world_diagnostic_frame_destroy(&old)
	return .Ok
}

// Forward an ACTUAL disconnect event before subsequent timing status/frame use.
// Session client joined/roster state alone does not certify connectivity.
lane_world_protocol_peer_disconnected :: proc(l:^Lane,peer:ksess.Peer_Id)->World_Error {
 if l==nil || l.world==nil || l.world.network==nil {return .Unsupported}
 n:=l.world.network
 if n.authority {
  for &receipt in n.protocol.receipts {if receipt.peer==peer {receipt={}}}
 } else if peer==ksess.HOST_PEER {
  world_protocol_invalidate(n);n.protocol.bootstrap_sequence=0;n.protocol.signature_head=0;n.protocol.signature_count=0
 }
 return .Ok
}

// World v2: ordinary accepted traffic contains authenticated receipt feedback;
// full state remains explicit bootstrap/recovery traffic.
@(private)
world_protocol_invalidate :: proc(n:^World_Network) {
 n.protocol.receipt_available=false;n.protocol.receipt_player=0
 n.protocol.receipt_proposal_tick=0;n.protocol.receipt_authority_tick=0;n.protocol.receipt_bootstrap=0
 n.protocol.authority_tick=0
 // A positive call cannot change scale; the next explicit zero ingress does.
}
@(private)
world_protocol_host_receipt_current :: proc(l:^Lane,index:int)->bool {
 n:=l.world.network;r:=&n.protocol.receipts[index]
 if !r.valid || r.epoch!=n.epoch {return false}
 player,ok:=ksess.session_player(l.ses,n.drivers[index].player)
 return ok && player.connected && !player.spectator && player.peer!=ksess.NO_PEER && player.peer==r.peer
}
@(private)
world_protocol_expect_bootstrap :: proc(l:^Lane,to:ksess.Peer_Id,sequence:u64) {
 n:=l.world.network
 for d,i in n.drivers {
  r:=&n.protocol.receipts[i]
  if !world_protocol_host_receipt_current(l,i) {r^={}}
  player,ok:=ksess.session_player(l.ses,d.player)
  if ok && player.connected && !player.spectator && player.peer!=ksess.NO_PEER && (to==ksess.BROADCAST_PEER || to==player.peer) {
   r^={valid=true,peer=player.peer,epoch=n.epoch,bootstrap_sequence=sequence}
  }
 }
}
@(private)
world_protocol_proposal_scope :: proc(l:^Lane,p:World_Net_Packet,scope:u64)->World_Error {
 n:=l.world.network
 if scope==0 {return .Rejected}
 for d,i in n.drivers {if d.player==p.from {
  if !world_protocol_host_receipt_current(l,i) || n.protocol.receipts[i].peer!=p.peer || n.protocol.receipts[i].bootstrap_sequence!=scope {return .Rejected}
  return .Ok
 }}
 return .Rejected
}
@(private)
world_protocol_note_proposal :: proc(l:^Lane,p:World_Net_Packet,scope:u64,rows:[]World_Input_Row,values:[][WORLD_NETWORK_DRIVERS][MAX_INPUT_SIZE]u8)->World_Error {
 n:=l.world.network
 for d,i in n.drivers {if d.player==p.from && d.class==0 {
  old:=&n.protocol.receipts[i];next:=old^;codec:=world_net_input_codec(n,0)
  for row,j in rows {
   value:=values[j][i][:codec.local_bytes]
   if next.available && row.tick==next.proposal_tick && mem.compare(next.value[:next.value_count],value)!=0 {return .Conflict}
   if !next.available || row.tick>next.proposal_tick {next.available=true;next.proposal_tick=row.tick;next.value_count=codec.local_bytes;copy(next.value[:],value)}
  }
  old^=next;return .Ok
 }}
 return .Ok // No class0 driver: there is no control receipt to advertise.
}
@(private)
world_protocol_accept_receipt :: proc(l:^Lane,authority_tick:u64,receipts:[]World_Protocol_Receipt) {
 n:=l.world.network;v:=&n.protocol
 if authority_tick<=v.authority_tick {return}
 v.authority_tick=authority_tick
 for d,i in n.drivers {if d.player==l.ses.me && d.class==0 {
  r:=&receipts[i]
  if !r.available || r.bootstrap_sequence!=v.bootstrap_sequence || v.bootstrap_sequence==0 {
   v.receipt_available=false;return
  }
  if v.receipt_available && r.proposal_tick<v.receipt_proposal_tick {return}
  v.receipt_player=d.player;v.receipt_bootstrap=r.bootstrap_sequence;v.receipt_proposal_tick=r.proposal_tick
  v.receipt_authority_tick=authority_tick;v.receipt_available=true;return
 }}
 v.receipt_available=false
}
@(private)
world_protocol_row_complete :: proc(n:^World_Network,tick:u64)->bool {
 row:=&n.accepted[tick%WORLD_HISTORY_FRAMES]
 if !row.valid || row.tick!=tick {return false}
 for i in 0..<len(n.drivers) {if row.origin[i]==.Unknown {return false}}
 return true
}
@(private)
world_protocol_advance_accepted :: proc(l:^Lane) {
 n:=l.world.network
 for _ in 0..<WORLD_HISTORY_FRAMES {
  if n.protocol.accepted_through==max(u64) {return}
  next:=n.protocol.accepted_through+1
  if !world_protocol_row_complete(n,next) {return}
  n.protocol.accepted_through=next
 }
}
@(private)
world_protocol_receive_signature :: proc(l:^Lane,p:World_Net_Packet)->World_Error {
 n:=l.world.network;r:=knet.reader_make(p.bytes)
 revision:=knet.read_u32(&r)
 if r.err || revision!=WORLD_NETWORK_REV || len(knet.reader_remaining(&r))!=bd.SIGNATURE_BYTES {return .Incompatible}
 sig,se:=bd.signature_decode(knet.reader_remaining(&r));if se!=.None || sig.identity!=n.config.identity {return .Incompatible}
 if sig.epoch<n.epoch {n.duplicates+=1;return .Ok}
 if sig.epoch!=n.epoch {return .Incompatible}
 if sig.tick<=l.world.confirmed {
  if sig.tick==n.protocol.matched_signature_tick && bd.compare(sig,n.last_signature)!=.Match {return .Conflict}
  n.duplicates+=1;return .Ok
 }
 for j in 0..<n.protocol.signature_count {
  i:=(n.protocol.signature_head+j)%WORLD_REPAIR_TICKS;prior:=&n.protocol.signatures[i]
  if prior.tick==sig.tick {if bd.compare(prior^,sig)!=.Match {return .Conflict};n.duplicates+=1;return .Ok}
  if prior.tick>sig.tick {n.duplicates+=1;return .Ok}
 }
 if n.protocol.signature_count==WORLD_REPAIR_TICKS {return .Capacity}
 index:=(n.protocol.signature_head+n.protocol.signature_count)%WORLD_REPAIR_TICKS
 n.protocol.signatures[index]=sig;n.protocol.signature_count+=1
 return .Ok
}
@(private)
world_protocol_signature_inputs :: proc(l:^Lane,tick:u64)->bool {
 n:=l.world.network
 if tick>n.protocol.accepted_through {return false}
 // Canonical Game includes up to eight accepted rows. A validated bootstrap
 // can establish a shorter epoch/history floor, never a predicted substitute.
 first:=tick>u64(WORLD_REPAIR_TICKS-1)?tick-u64(WORLD_REPAIR_TICKS-1):0
 first=max(first,n.protocol.canonical_floor)
 for t:=first;t<=tick;t+=1 {if !world_protocol_row_complete(n,t) {return false};if t==max(u64){break}}
 for t:=l.world.confirmed+1;t<=tick;t+=1 {if !world_protocol_row_complete(n,t){return false};if t==max(u64){break}}
 return true
}
@(private)
world_protocol_repair_needed :: proc(l:^Lane,tick:u64)->bool {
 n:=l.world.network
 if tick>l.world.head {return true}
 for t:=l.world.confirmed+1;t<=tick;t+=1 {
  used:=&n.used[t%WORLD_HISTORY_FRAMES]
  if !used.valid || used.tick!=t {return true}
  if mem.compare(world_net_data(n,n.used_data,t),world_net_data(n,n.accepted_data,t))!=0 {return true}
  if t==max(u64){break}
 }
 return false
}
@(private)
world_protocol_apply_signature :: proc(l:^Lane)->World_Error {
 n:=l.world.network;w:=l.world
 if n.protocol.signature_count==0 {return .Ok}
 sig:=n.protocol.signatures[n.protocol.signature_head]
 if sig.tick<=w.confirmed {n.protocol.signature_head=(n.protocol.signature_head+1)%WORLD_REPAIR_TICKS;n.protocol.signature_count-=1;return .Ok}
 if sig.tick-w.confirmed>WORLD_REPAIR_TICKS {return .Repair_Limit}
 if !world_protocol_signature_inputs(l,sig.tick) {return .Ok} // bounded pending, not confirmation over a gap
 if n.protocol.signatures_matched==max(u64) {return .Capacity}
 source:=world_record(w,w.head)
 if world_protocol_repair_needed(l,sig.tick) {source=world_record(w,w.confirmed)}
 if source==nil {return .History_Missing}
 result:=world_operation(l,source,nil,max(w.head,sig.tick),false,{},confirm_authority=false,verify_signature=&sig,confirm_to=sig.tick)
 if result.error!=.Ok {return result.error}
 l.stat_resims+=result.steps
 n.protocol.signature_head=(n.protocol.signature_head+1)%WORLD_REPAIR_TICKS;n.protocol.signature_count-=1
 return .Ok
}
@(private)
world_protocol_receipt_fresh :: proc(l:^Lane)->bool {
 n:=l.world.network;v:=&n.protocol
 if n.authority || !n.ready || l.world.resync || !v.receipt_available || v.bootstrap_sequence==0 || v.receipt_bootstrap!=v.bootstrap_sequence || v.receipt_player!=l.ses.me || v.receipt_authority_tick<l.world.confirmed {return false}
 distance:=v.receipt_authority_tick>l.world.head?v.receipt_authority_tick-l.world.head:l.world.head-v.receipt_authority_tick
 return distance<=WORLD_REPAIR_TICKS
}
@(private)
world_protocol_control :: proc(l:^Lane) {
 if world_protocol_receipt_fresh(l) {
  v:=&l.world.network.protocol
  headroom:f64
  if v.receipt_proposal_tick>=v.receipt_authority_tick {headroom=f64(v.receipt_proposal_tick-v.receipt_authority_tick)} else {headroom=-f64(v.receipt_authority_tick-v.receipt_proposal_tick)}
  lead_control(&l.ticker,f64(l.margin)-headroom,0.02)
 } else {l.ticker.scale=1}
}
