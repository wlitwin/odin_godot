package replay

Error :: enum {
	None,
	Invalid_Config,
	Unsupported_Value,
	Not_Initialized,
	Already_Initialized,
	Reentrant,
	Tick_Overflow,
	History_Missing,
	Initial_Frame,
	Event_Capacity,
	Duplicate_Event,
	Output_Too_Small,
	Aborted,
	Commit_Rejected,
	Diverged_State,
	Diverged_Event,
	Committed,
	Time_Reversed,
	Invalid_Event,
	Invalid_Epoch,
}

// source identifies the producer; key identifies its semantic occurrence within
// this tick (e.g. action sequence + effect slot). Call order is not identity.
// Epoch is supplied by the runner owner. It does not itself elect an authority.
Event_Id :: struct {
	epoch, tick: u64,
	source, key: u64,
}

Occurrence :: struct($Event: typeid) {
	id:    Event_Id,
	value: Event,
}

Step :: struct($Event: typeid) {
	tick:  u64,
	epoch: u64,
	// Runtime-owned borrowed scratch. Gameplay uses emit/abort; it must not
	// retain this context or modify the journal metadata directly.
	events: []Occurrence(Event),
	count:  int,
	error:  Error,
	user: rawptr, // immutable model/assets supplied by the timeline owner
}

emit :: proc(s: ^Step($Event), source, key: u64, value: Event) -> bool {
	if s.error != .None {return false}
	id := Event_Id{s.epoch, s.tick, source, key}
	for e in s.events[:s.count] {
		if e.id == id {
			s.error = .Duplicate_Event
			return false
		}
	}
	if s.count == len(s.events) {
		s.error = .Event_Capacity
		return false
	}
	s.events[s.count] = {id, value}
	s.count += 1
	return true
}

// Explicitly combine multiple contributions to one semantic occurrence. The
// first contribution fixes its position in the tick's event list. Ordinary emit
// still rejects duplicates; callers choose folding and supply a pure reducer.
emit_fold :: proc(s: ^Step($Event), source, key: u64, value: Event,
                  fold: proc(previous, contribution: Event) -> (Event, bool)) -> bool {
	if s.error != .None {return false}
	if fold == nil {s.error = .Invalid_Event; return false}
	id := Event_Id{s.epoch, s.tick, source, key}
	for &event in s.events[:s.count] {
		if event.id != id {continue}
		combined, ok := fold(event.value, value)
		if !ok {abort(s); return false}
		event.value = combined
		return true
	}
	return emit(s, source, key, value)
}

// Abort the complete candidate tick, including earlier entity mutations/events.
abort :: proc(s: ^Step($Event)) {
	if s.error == .None {s.error = .Aborted}
}
