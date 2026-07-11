package play

// play/edge — fire ONCE on a change instead of every frame.
//
// An Edge(T) is a client-local SHADOW of some value (usually a REPLICATED field)
// so presentation can react the single frame the value moves — a hit flash, a
// status splash, a telegraph burst — rather than re-running every frame the value
// merely HOLDS. Hand `see` the current value; it returns the PREVIOUS one and
// whether it moved, updating the shadow in place. The caller reads prev-vs-cur for
// the exact transition it cares about (rose, fell to zero, a delta).
//
// WHY THIS IS A play/ PRIMITIVE AND NOT A kit/ ONE: an Edge touches NOTHING on the
// wire. It is pure local scratch — it lives in an entity's `view` (client render
// state) or host brain, off the replication boundary by construction. The kit's
// bar is "on the wire AND two games need it"; an Edge is neither, yet every
// non-trivial game re-derives it. That is exactly what the opt-in companion layer
// is for: reusable game-STRUCTURE that can't break kit discipline.
//
//   Rising edge:    p, moved := play.see(&e, v);  moved && v          // just became true / nonzero
//   Fell to zero:   p, _     := play.see(&e, v);  p > 0 && v == 0     // finished / expired this frame
//   Delta:          p, moved := play.see(&e, v);  if moved { d := p - v }
//
// A snapshot catch-up (a late join, an interest re-entry) lands replicated fields
// WHOLESALE — that jump is history, not gameplay. Re-baseline the shadow with
// `sync` in the resync pre-pass so a wound taken out of view doesn't present as a
// fresh hit.
Edge :: struct($T: typeid) {
	seen: T,
}

// see updates the shadow to `cur` and reports the value it replaced plus whether
// it differs. The workhorse — call it once per frame with your replicated value.
see :: proc(e: ^Edge($T), cur: T) -> (prev: T, changed: bool) {
	prev = e.seen
	e.seen = cur
	return prev, prev != cur
}

// sync re-baselines the shadow to `cur` WITHOUT reporting a change — for the
// resync pre-pass, so a wholesale snapshot catch-up isn't mistaken for a real
// transition. (Same as writing e.seen directly; named for intent at the call site.)
sync :: proc(e: ^Edge($T), cur: T) {
	e.seen = cur
}
