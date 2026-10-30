package replay

import "core:reflect"
import "core:mem"

// Optional correction-time prediction policy. It may use call-local scratch in
// user; the timeline owns only the resulting value inputs, never this callback.
// External side effects in apply are not part of the timeline transaction.
Input_Rewrite :: struct($Input: typeid) {
	user: rawptr,
	apply: proc(user: rawptr, tick: u64, original: Input) -> Input,
}

read_input :: proc(t: ^Timeline($State, $Input, $Event), tick: u64) -> (input: Input, ok: bool) {
	record := record_at(t, tick)
	if record == nil || !record.has_input {return {}, false}
	return record.input, true
}

// Restore occurrences attached to a freshly initialized/reset checkpoint.
// This cannot rewrite a simulated or nonempty committed tick.
seed_checkpoint_events :: proc(t: ^Timeline($S, $I, $E), events: []Occurrence(E)) -> Error {
	if err := available(t); err != .None {return err}
	base := record_at(t, t.head)
	if t.head != t.confirmed || base == nil || base.has_input || base.count != 0 {return .Committed}
	if len(events) > len(base.events) {return .Event_Capacity}
	for event, i in events {
		if event.id.epoch != t.epoch || event.id.tick != t.head {return .Invalid_Event}
		for prior in events[:i] {if prior.id == event.id {return .Duplicate_Event}}
	}
	copy(base.events, events); base.count = len(events)
	return .None
}

// Replace a speculative suffix from recorded/received decisions without
// advancing confirmation. P2P input arrival is not authority state correction.
revise_inputs :: proc(t: ^Timeline($State, $Input, $Event), first: u64, rewrite: Input_Rewrite(Input)) -> Result {
	if err := available(t); err != .None {return {error = err, tick = first}}
	if first <= t.confirmed {return {error = .Committed, tick = first}}
	if first > t.head || rewrite.apply == nil {return {error = .History_Missing, tick = first}}
	base := record_at(t, first - 1)
	if base == nil {return {error = .History_Missing, tick = first - 1}}
	n := int(t.head - first + 1)
	t.busy = true; defer t.busy = false
	before := base.frame
	for i in 0 ..< n {
		tick := first + u64(i)
		original := record_at(t, tick)
		if original == nil || !original.has_input {return {error = .History_Missing, steps = i, tick = tick}}
		input := rewrite.apply(rewrite.user, tick, original.input)
		if err := simulate(t, &t.staged[i], before, input); err != .None {return {error = err, steps = i, tick = tick}}
		before = t.staged[i].frame
	}
	for i in 0 ..< n {commit(t, &t.staged[i])}
	return {steps = n, tick = t.head}
}

// Ingest a COMPLETE authoritative frame and its complete occurrence batch.
// The caller authenticates authority, epoch, schema, and game invariants before
// calling. Replay every later input in scratch, then atomically commit both the
// checkpoint and its suffix. An optional Input_Rewrite replaces guesses while
// staging. Failure leaves inputs/state/events/confirmation unchanged.
correct :: proc{correct_plain, correct_rewrite}

@(private)
correct_plain :: proc(t: ^Timeline($State, $Input, $Event), truth: Frame(State), events: []Occurrence(Event)) -> Result {
	return correct_rewrite(t, truth, events, Input_Rewrite(Input){})
}

@(private)
correct_rewrite :: proc(t: ^Timeline($State, $Input, $Event), truth: Frame(State), events: []Occurrence(Event),
                        rewrite: Input_Rewrite(Input)) -> Result {
 return correct_impl(t,truth,events,rewrite,nil)
}

// Explicit deterministic reuse. Complete mutable dependencies belong in State;
// external configuration and the step callback must remain unchanged. Audit and
// ordinary correct still execute every step. Rewriters are always called once
// per visited input. Byte equality is deliberately stricter than float equality.
correct_reusing :: proc{correct_reusing_plain,correct_reusing_rewrite}
@(private)
correct_reusing_plain :: proc(t:^Timeline($S,$I,$E),truth:Frame(S),events:[]Occurrence(E))->(Result,int) {
 return correct_reusing_rewrite(t,truth,events,Input_Rewrite(I){})
}
@(private)
correct_reusing_rewrite :: proc(t:^Timeline($S,$I,$E),truth:Frame(S),events:[]Occurrence(E),rewrite:Input_Rewrite(I))->(result:Result,reused:int) {
 result=correct_impl(t,truth,events,rewrite,&reused)
 return
}

@(private)
correction_bytes_equal :: proc(a:^$T,b:^T)->bool {
 if a==b {return true}
 x:=(cast([^]u8)a)[:size_of(T)];y:=(cast([^]u8)b)[:size_of(T)]
 return mem.compare(x,y)==0
}

@(private)
correct_impl :: proc(t:^Timeline($State,$Input,$Event),truth:Frame(State),events:[]Occurrence(Event),rewrite:Input_Rewrite(Input),reuse_count:^int)->Result {
	if err := available(t); err != .None {return {error = err, tick = truth.tick}}
	if truth.tick < t.confirmed {return {error = .Committed, tick = truth.tick}}
	base := record_at(t, truth.tick)
	if base == nil {return {error = .History_Missing, tick = truth.tick}}
	if len(events) > len(base.events) {return {error = .Event_Capacity, tick = truth.tick}}
	for event, i in events {
		if event.id.epoch != t.epoch || event.id.tick != truth.tick {
			return {error = .Invalid_Event, tick = truth.tick}
		}
		for previous in events[:i] {
			if previous.id == event.id {return {error = .Duplicate_Event, tick = truth.tick}}
		}
	}
	if truth.tick == t.confirmed {
		if !reflect.equal(base.frame.state, truth.state) ||
		   !reflect.equal(base.events[:base.count], events, true) {
			return {error = .Committed, tick = truth.tick}
		}
		return {tick = truth.tick} // identical replay of a settled checkpoint
	}
	t.busy = true
	defer t.busy = false
	checkpoint := &t.staged[0]
	checkpoint.valid = true
	checkpoint.has_input = false // the generating authority input is not known here
	checkpoint.input = {}
	checkpoint.frame = truth
	checkpoint.count = len(events)
	copy(checkpoint.events, events)
	n := int(t.head - truth.tick)
	reused:=0
	before:=&checkpoint.frame
	for i in 0 ..< n {
		at := truth.tick + u64(i) + 1
		original := record_at(t, at)
		if original == nil {return {error = .History_Missing, steps = i, tick = at}}
		if !original.has_input {return {error = .Initial_Frame, steps = i, tick = at}}
		dst := &t.staged[i + 1]
		input := original.input
		if rewrite.apply != nil {input = rewrite.apply(rewrite.user, at, input)}
		can_reuse:=false
		if reuse_count!=nil {
			previous:=record_at(t,at-1)
			can_reuse=previous!=nil && correction_bytes_equal(&before.state,&previous.frame.state) && correction_bytes_equal(&input,&original.input)
		}
		if can_reuse {
			// The existing record already contains the required input/state/events.
			// Leave it untouched at commit, and never alias its event slice in scratch.
			dst.valid=false;before=&original.frame;reused+=1
		} else {
			if err := simulate(t, dst, before^, input); err != .None {return {error = err, steps = i, tick = at}}
			before=&dst.frame
		}
	}
	for i in 0 ..= n {if t.staged[i].valid {commit(t, &t.staged[i])}}
	if reuse_count!=nil {reuse_count^=reused}
	t.confirmed = truth.tick
	return {steps = n, tick = t.head}
}

// Explicit resync/recovery. Reuses allocations and discards old speculative
// input/event history. A same-epoch snapshot cannot move behind confirmed state;
// a new authorized epoch may resume an older checkpoint (e.g. host migration).
// An epoch counter alone does not establish legitimate authority.
reset_checkpoint :: proc(t: ^Timeline($State, $Input, $Event), frame: Frame(State), epoch: u64) -> Error {
	if err := available(t); err != .None {return err}
	if epoch == 0 || epoch < t.epoch {return .Invalid_Epoch}
	if epoch == t.epoch && frame.tick < t.confirmed {return .Committed}
	for &record in t.records {record.valid = false; record.count = 0}
	for &record in t.staged {record.valid = false; record.count = 0}
	t.epoch, t.head, t.confirmed = epoch, frame.tick, frame.tick
	base := &t.records[frame.tick % u64(len(t.records))]
	base.valid = true
	base.has_input = false
	base.input = {}
	base.frame = frame
	return .None
}
