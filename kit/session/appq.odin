package kit_session

// appq — the SES_APP rider's queue, as a TYPE instead of a convention each
// package re-earns.
//
// Every package that rides the app channel obeys the same discipline: the
// HANDLER only files (it runs inside session_handle_packet, mid-packet-switch,
// on the session's stack), and the GAME drains on its own stack in the pump.
// That rule is load-bearing — index.md's house grammar states it, and the one
// subsystem that broke it (kit/combat's old on_fire callback, running game code
// mid-session-pump) was the package's only reentrancy hole. Yet kit/comms,
// kit/xfer, the album, and the fire lane each rebuilt it privately: four copies
// of `[dynamic]T` plus "len == 0 -> false; take [0]; ordered_remove", which is
// three copies too many for a rule the house calls load-bearing.
//
//     events: ksess.App_Queue(Event)         // the rider's field
//     ksess.appq_push(&c.events, ev)         // from the handler
//     ev, ok := ksess.appq_poll(&c.events)   // from the game's poll proc
//
// It is a CONTAINER, not a subsystem: no Session pointer, no run state, no
// entry in run_destroy, and it allocates only through the dynamic array's own
// creation allocator. That is what lets tier-B (the session, which stores an
// allocator) and tier-C (comms/xfer/combat, ambient) share one type without
// either inheriting the other's allocator rule — see session.md's tiers.

// The queue. Riders keep their public poll proc (`comms_poll`, `xfer_poll`,
// `fire_poll`) and delegate here — the name games see never moves.
App_Queue :: struct($T: typeid) {
	items: [dynamic]T,
}

// Handler side: file one. Called from a Relay_Proc / App_Handler, never from
// game code — the whole point of the split is that nothing here calls out.
appq_push :: proc(q: ^App_Queue($T), item: T) {
	append(&q.items, item)
}

// Game side: drain one (call until ok = false each frame).
appq_poll :: proc(q: ^App_Queue($T)) -> (item: T, ok: bool) {
	if len(q.items) == 0 {
		return
	}
	item = q.items[0]
	ordered_remove(&q.items, 0)
	return item, true
}

// What is still queued, oldest first — for the rider that must ASK before it
// frees something a queued event still points at (kit/xfer's retire path: a
// superseded payload whose Ev_Done has not drained yet). Read-only; push and
// poll own the shape.
appq_items :: proc(q: ^App_Queue($T)) -> []T {
	return q.items[:]
}

appq_len :: proc(q: ^App_Queue($T)) -> int {
	return len(q.items)
}

appq_destroy :: proc(q: ^App_Queue($T)) {
	delete(q.items)
	q^ = {}
}
