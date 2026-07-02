package events

// events — a typed, pure-Odin observer: one-to-many dispatch at DIRECT-CALL cost.
//
// An engine signal emit pays the full round trip — StringName lookup, a Variant boxed
// per argument, Object::emit_signal connection dispatch, then the C trampoline back
// into your script. That is the right price for a CROSS-BOUNDARY contract (other
// modules, GDScript, the editor, .tscn [connection]s). But for one script notifying
// other scripts in the SAME dll, it's pure overhead: `Event(T)` is a subscriber list
// of proc pointers, and `emit` is a loop of direct calls with a typed payload — no
// engine, no boxing, no allocation on the emit path.
//
// WHEN TO USE WHICH (the three-tier decision):
//   * engine signal (`gd.Signal1(int)` field)  — crossing ANY boundary: another script
//     module, GDScript, scene [connection]s, the Inspector. The engine is the contract.
//   * events.Event(T)                          — decoupled one-to-many INSIDE one
//     module/dll, when emits are frequent enough that boxing hurts (or you just want
//     typed payloads and direct calls).
//   * no events at all                         — the hottest loops. Batch the data and
//     iterate (see examples/barrage's SOA bullet field): a callback per element is
//     still a call per element.
//
// MODULE BOUNDARY (the hard rule): never hand an Event pointer or subscribe across
// script-module dlls. Modules are ISOLATED — typeids are module-local and proc
// pointers into another dll defeat the module contract (docs/modules.md). The
// canonical shape is: the cross-module edge stays ONE engine call into the module
// that owns the event; the fan-out inside that module is the Event. (Sharing the
// `events` package itself is fine — an Event instance lives in one script's struct,
// not in package globals.)
//
// SUBSCRIBER LIFETIME: a subscription stores your ctx pointer raw. Unsubscribe BEFORE
// the subscriber's struct dies or the next emit is a use-after-free — for a script,
// that means `<class>_exit_tree` (which also covers queue_free). The publisher's
// event should be destroy()ed in its own exit_tree.
//
// HOT RELOAD (same trap as `flow`, same fix): subscriptions cache raw proc pointers
// into the scripts dll, so after a hot reload they point at STALE code — and after a
// CHANGED-LAYOUT reload the ctx pointers dangle too (structs are reallocated; the
// publisher's list is also reset by migration). The self-healing pattern is for every
// SUBSCRIBER to resubscribe in its `<class>_reload` hook, tagged with its own engine
// instance id as `owner`:
//
//     enemy_reload :: proc(self: ^Enemy) { enemy_subscribe_slow(self) }
//
//     enemy_subscribe_slow :: proc(self: ^Enemy) {
//         sp := find_spawner(self)                     // same-module publisher
//         if sp == nil {return}
//         id := u64(gd.object_get_instance_id(cast(gd.Object)self.owner))
//         events.unsubscribe_owner(&sp.slow_changed, id)   // idempotent, order-free
//         events.subscribe(&sp.slow_changed, self, enemy_on_slow, id)
//     }
//
// unsubscribe_owner + subscribe is idempotent and order-independent across the
// rebind loop, and refreshes BOTH the fn and ctx pointers. (Ordinary game scripts
// never hot-reload mid-run — this only matters for `//gd:tool` scripts and
// editor-driven reloads, exactly like flow's Action trees.)
//
// REENTRANCY: emit is safe against subscribe/unsubscribe/clear from inside a
// callback. Subscriptions added during an emit are NOT called until the next emit;
// removals during an emit take effect immediately (a not-yet-called subscriber that
// gets unsubscribed mid-emit will not fire). Nested emits of the same event are fine.
// NOT thread-safe — this is a main-thread gameplay tool, like the rest of a script.
//
// Odin procs are not closures: every callback receives the `ctx` you subscribed with
// (cast it back to your struct, exactly like the flow sequencer's callbacks).

Subscription :: struct($T: typeid) {
	fn:    proc(ctx: rawptr, payload: T), // nil = tombstone (removed mid-emit)
	ctx:   rawptr,
	owner: u64, // caller-chosen tag for bulk removal (e.g. an engine instance id); 0 = untagged
}

Event :: struct($T: typeid) {
	subs:     [dynamic]Subscription(T),
	emitting: int, // >0 while inside emit (counts nesting); removals tombstone instead of shifting
	dirty:    bool, // tombstones pending compaction once the outermost emit unwinds
}

// subscribe appends a subscription (called in subscription order). Duplicates are
// allowed and fire once per subscription. `owner` tags it for unsubscribe_owner.
subscribe :: proc(e: ^Event($T), ctx: rawptr, fn: proc(ctx: rawptr, payload: T), owner: u64 = 0) {
	append(&e.subs, Subscription(T){fn = fn, ctx = ctx, owner = owner})
}

// unsubscribe removes the FIRST subscription matching (fn, ctx). Safe during emit.
unsubscribe :: proc(e: ^Event($T), ctx: rawptr, fn: proc(ctx: rawptr, payload: T)) {
	for &s, i in e.subs {
		if s.fn == fn && s.ctx == ctx {
			remove_at(e, i)
			return
		}
	}
}

// unsubscribe_owner removes EVERY subscription tagged with `owner`. Safe during emit.
// (owner 0 removes the untagged ones — tag real subscribers with a nonzero id.)
unsubscribe_owner :: proc(e: ^Event($T), owner: u64) {
	for i := len(e.subs) - 1; i >= 0; i -= 1 {
		if e.subs[i].owner == owner && e.subs[i].fn != nil {
			remove_at(e, i)
		}
	}
}

// emit calls every live subscriber, in subscription order, with a typed payload —
// direct calls, no engine, no boxing. See the header for mid-emit semantics.
emit :: proc(e: ^Event($T), payload: T) {
	e.emitting += 1
	n := len(e.subs) // snapshot: mid-emit subscribes run from the NEXT emit
	for i in 0 ..< n {
		s := e.subs[i] // re-read per index — callbacks may grow (realloc) the array
		if s.fn != nil {
			s.fn(s.ctx, payload)
		}
	}
	e.emitting -= 1
	if e.emitting == 0 && e.dirty {
		compact(e)
	}
}

// count reports live (non-tombstoned) subscriptions.
count :: proc(e: ^Event($T)) -> int {
	n := 0
	for s in e.subs {
		if s.fn != nil {n += 1}
	}
	return n
}

// clear drops every subscription (safe during emit: not-yet-called subscribers of the
// current emit will not fire).
clear :: proc(e: ^Event($T)) {
	if e.emitting > 0 {
		for &s in e.subs {s.fn = nil}
		e.dirty = true
		return
	}
	clear_dynamic_array(&e.subs)
}

// destroy frees the subscriber list. Must not be called from inside one of this
// event's own callbacks — tear the publisher down from its exit_tree instead.
destroy :: proc(e: ^Event($T)) {
	assert(e.emitting == 0, "events.destroy called mid-emit")
	delete(e.subs)
	e^ = {}
}

@(private)
remove_at :: proc(e: ^Event($T), i: int) {
	if e.emitting > 0 {
		e.subs[i].fn = nil // tombstone: the running emit skips it; compacted after
		e.dirty = true
		return
	}
	ordered_remove(&e.subs, i) // ordered: emit order == subscription order, always
}

@(private)
compact :: proc(e: ^Event($T)) {
	kept := 0
	for s in e.subs {
		if s.fn != nil {
			e.subs[kept] = s
			kept += 1
		}
	}
	resize(&e.subs, kept)
	e.dirty = false
}
