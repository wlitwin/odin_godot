package replay

import "core:mem"
import "core:reflect"

// State is the complete mutable simulation, including entity allocation and RNG.
// Tick zero is a real initial frame. Frames returned to callers are owned values.
Frame :: struct($State: typeid) {
	tick:  u64,
	state: State,
}

Config :: struct {
	history_frames:  int,
	events_per_tick: int,
}

DEFAULT_CONFIG :: Config{history_frames = 128, events_per_tick = 32}

Result :: struct {
	error: Error,
	// steps counts completed staged steps, including on an aborted operation.
	// Only error=None commits a revision. Audit never commits.
	steps: int,
	tick:  u64, // first failing tick, or final processed tick on success
}

@(private)
Record :: struct($State, $Input, $Event: typeid) {
	valid:     bool,
	has_input: bool,
	frame:     Frame(State),
	input:     Input,
	events:    []Occurrence(Event),
	count:     int,
}

// Runtime owner: initialize once, use by pointer, destroy once. Do not copy a
// live Timeline: its allocations have one owner. Public reads copy data out.
Timeline :: struct($State, $Input, $Event: typeid) {
	allocator: mem.Allocator,
	step: proc(state: ^State, input: Input, ctx: ^Step(Event)),
	epoch: u64,
	head: u64,
	confirmed: u64,
	busy: bool,
	user: rawptr,
	records: []Record(State, Input, Event),
	staged:  []Record(State, Input, Event),
	event_storage: []Occurrence(Event),
	staged_events: []Occurrence(Event),
}

init :: proc(
	t: ^Timeline($State, $Input, $Event),
	initial: Frame(State),
	step: proc(state: ^State, input: Input, ctx: ^Step(Event)),
	cfg := DEFAULT_CONFIG,
	epoch: u64 = 1,
	allocator := context.allocator,
	user: rawptr = nil,
) -> Error {
	if len(t.records) != 0 {return .Already_Initialized}
	if step == nil || epoch == 0 || cfg.history_frames < 2 ||
	   cfg.history_frames > 4096 || cfg.events_per_tick < 0 || cfg.events_per_tick > 4096 {
		return .Invalid_Config
	}
	if !value_supported(State) || !value_supported(Input) || !value_supported(Event) {
		return .Unsupported_Value
	}
	t.records = make([]Record(State, Input, Event), cfg.history_frames, allocator)
	t.staged = make([]Record(State, Input, Event), cfg.history_frames, allocator)
	n := cfg.history_frames * cfg.events_per_tick
	t.event_storage = make([]Occurrence(Event), n, allocator)
	t.staged_events = make([]Occurrence(Event), n, allocator)
	for i in 0 ..< cfg.history_frames {
		lo, hi := i * cfg.events_per_tick, (i + 1) * cfg.events_per_tick
		t.records[i].events = t.event_storage[lo:hi]
		t.staged[i].events = t.staged_events[lo:hi]
	}
	t.step = step
	t.user = user
	t.allocator = allocator
	t.epoch = epoch
	t.head = initial.tick
	t.confirmed = initial.tick
	r := &t.records[initial.tick % u64(len(t.records))]
	r.valid = true
	r.frame = initial
	return .None
}

destroy :: proc(t: ^Timeline($State, $Input, $Event)) {
	assert(!t.busy, "destroy cannot run inside a simulation step")
	delete(t.records, t.allocator)
	delete(t.staged, t.allocator)
	delete(t.event_storage, t.allocator)
	delete(t.staged_events, t.allocator)
	t^ = {}
}

read :: proc(t: ^Timeline($State, $Input, $Event), tick: u64) -> (frame: Frame(State), ok: bool) {
	r := record_at(t, tick)
	if r == nil {return {}, false}
	return r.frame, true
}

current :: proc(t: ^Timeline($State, $Input, $Event)) -> (frame: Frame(State), ok: bool) {
	return read(t, t.head)
}

// Configuration metadata for bounded diagnostics; no history storage is exposed.
timeline_config :: proc(t:^Timeline($S,$I,$E))->(Config,Error) {
	if err:=available(t);err!=.None {return {},err}
	return {len(t.records),len(t.records[0].events)},.None
}

// Copies the entire occurrence batch or nothing. Never exposes history storage.
copy_events :: proc(t: ^Timeline($State, $Input, $Event), tick: u64, dst: []Occurrence(Event)) -> (count: int, error: Error) {
	if len(t.records) == 0 {return 0, .Not_Initialized}
	r := record_at(t, tick)
	if r == nil {return 0, .History_Missing}
	if len(dst) < r.count {return r.count, .Output_Too_Small}
	copy(dst, r.events[:r.count])
	return r.count, .None
}

// Optional outside-simulation authorization immediately before publishing a
// candidate. Rejection preserves the complete ring, including its oldest slot.
Commit_Gate :: struct {user: rawptr, allow: proc(user: rawptr, epoch: u64) -> bool}

advance :: proc(t: ^Timeline($State, $Input, $Event), input: Input, gate: Commit_Gate = {}) -> Result {
	if err := available(t); err != .None {return {error = err}}
	if t.head == max(u64) {return {error = .Tick_Overflow, tick = t.head}}
	t.busy = true
	defer t.busy = false
	before := record_at(t, t.head).frame
	candidate := &t.staged[0]
	if err := simulate(t, candidate, before, input); err != .None {
		return {error = err, tick = before.tick + 1}
	}
	if gate.allow != nil && !gate.allow(gate.user, t.epoch) {return {error = .Commit_Rejected, steps = 1, tick = before.tick + 1}}
	commit(t, candidate)
	t.head = candidate.frame.tick
	return {steps = 1, tick = t.head}
}

// Replace the complete input batch for one tick, then replay its entire suffix.
// Missing history or any failed step leaves ALL committed frames/inputs/events
// unchanged. No approximate fallback from current state is allowed.
revise_input :: proc(t: ^Timeline($State, $Input, $Event), tick: u64, input: Input) -> Result {
	if err := available(t); err != .None {return {error = err, tick = tick}}
	if tick <= t.confirmed {
		if first := record_at(t, tick); first != nil && !first.has_input {
			return {error = .Initial_Frame, tick = tick}
		}
		return {error = .Committed, tick = tick}
	}
	return replay_suffix(t, tick, input, false)
}

// Called by the runner after authority has settled complete state through tick.
// Simulation and presentation have separate frontiers; this protects gameplay
// even if a view is delayed or temporarily blocked on its notification queue.
confirm_through :: proc(t: ^Timeline($State, $Input, $Event), tick: u64) -> Error {
	if err := available(t); err != .None {return err}
	if tick < t.confirmed {return .Time_Reversed}
	if record_at(t, tick) == nil {return .History_Missing}
	t.confirmed = tick
	return .None
}

// Re-execute recorded inputs and compare logical values, ignoring struct padding.
// Reports the first differing tick and whether state or events diverged. This
// checks local reproducibility; it cannot prove cross-machine determinism or
// undo side effects in a callback that violates the simulation contract.
audit :: proc(t: ^Timeline($State, $Input, $Event), from_tick: u64) -> Result {
	return replay_suffix(t, from_tick, Input{}, true)
}

// Explicit branch: discard future frames, inputs, and events. A caller can also
// copy a Frame and init a separate Timeline at that checkpoint without touching
// the original. Neither operation constitutes network host migration.
rewind :: proc(t: ^Timeline($State, $Input, $Event), tick: u64) -> Error {
	if err := available(t); err != .None {return err}
	if tick < t.confirmed {return .Committed}
	if record_at(t, tick) == nil {return .History_Missing}
	for &r in t.records {
		if r.valid && r.frame.tick > tick {
			r.valid = false
			r.count = 0
		}
	}
	t.head = tick
	return .None
}

@(private)
available :: proc(t: ^Timeline($State, $Input, $Event)) -> Error {
	if len(t.records) == 0 {return .Not_Initialized}
	if t.busy {return .Reentrant}
	return .None
}

@(private)
record_at :: proc(t: ^Timeline($State, $Input, $Event), tick: u64) -> ^Record(State, Input, Event) {
	if len(t.records) == 0 || tick > t.head {return nil}
	r := &t.records[tick % u64(len(t.records))]
	if !r.valid || r.frame.tick != tick {return nil}
	return r
}

@(private)
simulate :: proc(t: ^Timeline($State, $Input, $Event), dst: ^Record(State, Input, Event), before: Frame(State), input: Input) -> Error {
	dst.frame = {before.tick + 1, before.state}
	dst.input = input
	dst.has_input = true
	dst.valid = true
	ctx := Step(Event){tick = dst.frame.tick, epoch = t.epoch, events = dst.events, user = t.user}
	t.step(&dst.frame.state, input, &ctx)
	dst.count = ctx.count
	return ctx.error
}

@(private)
commit :: proc(t: ^Timeline($State, $Input, $Event), src: ^Record(State, Input, Event)) {
	dst := &t.records[src.frame.tick % u64(len(t.records))]
	dst.valid = true
	dst.has_input = src.has_input
	dst.frame = src.frame
	dst.input = src.input
	dst.count = src.count
	copy(dst.events, src.events[:src.count])
}

@(private)
replay_suffix :: proc(t:^Timeline($S,$I,$E),tick:u64,input:I,checking:bool)->Result {
	capture:^Audit_Capture(S,I,E)
	return replay_suffix_capture(t,tick,input,checking,capture,context.allocator)
}

@(private)
replay_suffix_capture :: proc(t: ^Timeline($State, $Input, $Event), tick: u64, input: Input, checking: bool, capture:^Audit_Capture(State,Input,Event), allocator:mem.Allocator) -> Result {
	if err := available(t); err != .None {return {error = err, tick = tick}}
	first := record_at(t, tick)
	if first == nil {return {error = .History_Missing, tick = tick}}
	if !first.has_input {return {error = .Initial_Frame, tick = tick}}
	parent := record_at(t, tick - 1)
	if parent == nil {return {error = .History_Missing, tick = tick - 1}}
	n := int(t.head - tick) + 1 // bounded by the stamped history window
	t.busy = true
	defer t.busy = false
	before := parent.frame
	for i in 0 ..< n {
		at := tick + u64(i)
		original := record_at(t, at)
		if original == nil {return {error = .History_Missing, steps = i, tick = at}}
		if !original.has_input {return {error = .Initial_Frame, steps = i, tick = at}}
		sample := original.input
		if i == 0 && !checking {sample = input}
		dst := &t.staged[i]
		if err := simulate(t, dst, before, sample); err != .None {
			return {error = err, steps = i, tick = at}
		}
		if checking {
			if !reflect.equal(dst.frame.state, original.frame.state) {
				result:=Result{error=.Diverged_State,steps=i+1,tick=at}
				capture_audit_difference(capture,result,original,dst,before,allocator)
				return result
			}
			if dst.count != original.count ||
			   !reflect.equal(dst.events[:dst.count], original.events[:original.count], true) {
				result:=Result{error=.Diverged_Event,steps=i+1,tick=at}
				capture_audit_difference(capture,result,original,dst,before,allocator)
				return result
			}
		}
		before = dst.frame
	}
	if !checking {
		for i in 0 ..< n {commit(t, &t.staged[i])}
	}
	return {steps = n, tick = t.head}
}
