package events_test

// Standalone tests for the `events` observer — no Godot runtime needed.
//
//   odin test tests/events -collection:godot=$PWD
//
// (run from the repo root; `godot:` is the same collection the scripts use).

import "core:testing"
import events "godot:events"

Hit :: struct {
	damage: int,
	crit:   bool,
}

State :: struct {
	log:   [dynamic]int,
	event: ^events.Event(Hit),
	total: int,
}

@(test)
subscribe_emit_order_and_typed_payload :: proc(t: ^testing.T) {
	e: events.Event(Hit)
	defer events.destroy(&e)
	s := State{}
	defer delete(s.log)

	events.subscribe(&e, &s, proc(ctx: rawptr, h: Hit) {append(&(cast(^State)ctx).log, h.damage)})
	events.subscribe(&e, &s, proc(ctx: rawptr, h: Hit) {append(&(cast(^State)ctx).log, h.damage * 10)})
	events.emit(&e, Hit{damage = 3, crit = true})

	testing.expect_value(t, len(s.log), 2)
	testing.expect_value(t, s.log[0], 3) // subscription order
	testing.expect_value(t, s.log[1], 30)
	testing.expect_value(t, events.count(&e), 2)
}

@(test)
unsubscribe_first_match_only :: proc(t: ^testing.T) {
	e: events.Event(Hit)
	defer events.destroy(&e)
	s := State{}
	defer delete(s.log)

	fn := proc(ctx: rawptr, h: Hit) {append(&(cast(^State)ctx).log, h.damage)}
	events.subscribe(&e, &s, fn) // duplicate subscriptions fire once each
	events.subscribe(&e, &s, fn)
	events.unsubscribe(&e, &s, fn)
	events.emit(&e, Hit{damage = 1})

	testing.expect_value(t, len(s.log), 1)
	testing.expect_value(t, events.count(&e), 1)
}

@(test)
unsubscribe_owner_bulk :: proc(t: ^testing.T) {
	e: events.Event(Hit)
	defer events.destroy(&e)
	a, b := State{}, State{}
	defer delete(a.log)
	defer delete(b.log)

	fn := proc(ctx: rawptr, h: Hit) {append(&(cast(^State)ctx).log, h.damage)}
	events.subscribe(&e, &a, fn, 7)
	events.subscribe(&e, &a, fn, 7)
	events.subscribe(&e, &b, fn, 9)
	events.unsubscribe_owner(&e, 7)
	events.emit(&e, Hit{damage = 2})

	testing.expect_value(t, len(a.log), 0)
	testing.expect_value(t, len(b.log), 1)
	testing.expect_value(t, events.count(&e), 1)
}

@(test)
resubscribe_pattern_is_idempotent :: proc(t: ^testing.T) {
	// The documented hot-reload pattern: unsubscribe_owner + subscribe, repeatable.
	e: events.Event(Hit)
	defer events.destroy(&e)
	s := State{}
	defer delete(s.log)

	fn := proc(ctx: rawptr, h: Hit) {append(&(cast(^State)ctx).log, h.damage)}
	for _ in 0 ..< 3 {
		events.unsubscribe_owner(&e, 42)
		events.subscribe(&e, &s, fn, 42)
	}
	events.emit(&e, Hit{damage = 5})

	testing.expect_value(t, len(s.log), 1) // exactly one live subscription survives
	testing.expect_value(t, events.count(&e), 1)
}

@(test)
subscribe_during_emit_defers_to_next_emit :: proc(t: ^testing.T) {
	e: events.Event(Hit)
	defer events.destroy(&e)
	s := State{event = &e}
	defer delete(s.log)

	late := proc(ctx: rawptr, h: Hit) {append(&(cast(^State)ctx).log, 100 + h.damage)}
	first := proc(ctx: rawptr, h: Hit) {
		st := cast(^State)ctx
		append(&st.log, h.damage)
		if len(st.log) == 1 { // only on the first emit
			events.subscribe(st.event, st, proc(ctx: rawptr, h: Hit) {append(&(cast(^State)ctx).log, 100 + h.damage)})
		}
	}
	_ = late
	events.subscribe(&e, &s, first)

	events.emit(&e, Hit{damage = 1})
	testing.expect_value(t, len(s.log), 1) // late sub did NOT fire this round

	events.emit(&e, Hit{damage = 2})
	testing.expect_value(t, len(s.log), 3) // first + late both fired
	testing.expect_value(t, s.log[1], 2)
	testing.expect_value(t, s.log[2], 102)
}

@(test)
unsubscribe_during_emit_skips_pending_subscriber :: proc(t: ^testing.T) {
	e: events.Event(Hit)
	defer events.destroy(&e)
	s := State{event = &e}
	defer delete(s.log)

	second := proc(ctx: rawptr, h: Hit) {append(&(cast(^State)ctx).log, 2)}
	first := proc(ctx: rawptr, h: Hit) {
		st := cast(^State)ctx
		append(&st.log, 1)
		// Remove the not-yet-called second subscriber mid-emit: it must NOT fire.
		events.unsubscribe_owner(st.event, 5)
	}
	events.subscribe(&e, &s, first)
	events.subscribe(&e, &s, second, 5)

	events.emit(&e, Hit{})
	testing.expect_value(t, len(s.log), 1)
	testing.expect_value(t, events.count(&e), 1) // tombstone compacted after the emit
	testing.expect_value(t, len(e.subs), 1)

	events.emit(&e, Hit{})
	testing.expect_value(t, len(s.log), 2) // and the survivor still works
	testing.expect_value(t, s.log[1], 1)
}

@(test)
clear_during_emit_stops_pending_and_empties :: proc(t: ^testing.T) {
	e: events.Event(Hit)
	defer events.destroy(&e)
	s := State{event = &e}
	defer delete(s.log)

	first := proc(ctx: rawptr, h: Hit) {
		st := cast(^State)ctx
		append(&st.log, 1)
		events.clear(st.event)
	}
	events.subscribe(&e, &s, first)
	events.subscribe(&e, &s, proc(ctx: rawptr, h: Hit) {append(&(cast(^State)ctx).log, 2)})

	events.emit(&e, Hit{})
	testing.expect_value(t, len(s.log), 1)
	testing.expect_value(t, events.count(&e), 0)
	testing.expect_value(t, len(e.subs), 0)
}

@(test)
nested_emit_and_totals :: proc(t: ^testing.T) {
	e: events.Event(Hit)
	defer events.destroy(&e)
	s := State{event = &e}
	defer delete(s.log)

	fn := proc(ctx: rawptr, h: Hit) {
		st := cast(^State)ctx
		st.total += h.damage
		if h.damage > 1 { // nested emit from inside a callback
			events.emit(st.event, Hit{damage = 1})
		}
	}
	events.subscribe(&e, &s, fn)
	events.emit(&e, Hit{damage = 3})

	testing.expect_value(t, s.total, 4) // 3 + nested 1
	testing.expect_value(t, e.emitting, 0)
}
