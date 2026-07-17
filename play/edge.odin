package play

// play/edge — fire ONCE on a change instead of every frame — for state the
// wire CANNOT see.
//
// A REPLICATED field never needs this: declare the generated `<field>_edge`
// half (kit/net) and the session's per-frame pass hands you the net change,
// with first sight and resyncs seeding silently — no shadow, no scan, no
// re-baseline ritual. This primitive is for everything ELSE that moves:
//
//   - DERIVED values — a boolean computed from a replicated array
//     (scrapyard's "is this mob slimed?" off its fx effects), a distance
//     bucket, a rank; the field diffs but the DERIVATION is yours
//   - LOCAL state — a persistence profile, a host brain's scratch, render
//     bookkeeping that never crosses the wire
//
// Hand `see` the current value; it returns the PREVIOUS one and whether it
// moved, updating the shadow in place. The caller reads prev-vs-cur for the
// exact transition it cares about (rose, fell to zero, a delta).
//
//   Rising edge:    p, moved := play.see(&e, v);  moved && v          // just became true / nonzero
//   Fell to zero:   p, _     := play.see(&e, v);  p > 0 && v == 0     // finished / expired this frame
//   Delta:          p, moved := play.see(&e, v);  if moved { d := p - v }
//
// For DERIVED-from-replicated values one discipline carries over from the
// kit's halves: a snapshot catch-up (late join, interest re-entry) lands the
// SOURCE fields wholesale, so re-baseline the shadow with `sync` on
// Ev_Resynced — the derivation jump is history, not gameplay. (Purely local
// state never needs it.)
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
