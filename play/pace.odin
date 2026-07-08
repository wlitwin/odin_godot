package play

// play/pace — a deadline you re-arm: "is it time yet? then schedule the next."
//
// The single most repeated shape in a host tick loop: a stored moment (`next`),
// a check that the clock has reached it, and a re-arm to now + an interval. A gun's
// fire cadence, a scrapbot's bite/spit/slam cooldown, a boss's add-spawn timer, a
// one-shot "reset the run in 2.5s" — all the same three lines, re-hand-rolled per
// entity. Pace(T) names them.
//
// GENERIC OVER THE CLOCK. T is whatever your clock counts:
//   * Pace(u64) against a NET TICK number  — host sim deadlines (bite, slam, adds).
//   * Pace(f64) against monotonic SECONDS   — wall-clock deadlines (the fire pacer).
// The value is host scratch — it lives in a brain or a host struct, never on the
// wire (the same discipline as play/edge: a primitive that can't cross the boundary).
//
// Two idioms, pick per site:
//
//   split  (interval known only AFTER the check, or the re-arm happens elsewhere):
//     if !play.due(&p, now) { return }
//     ...compute the cooldown from live state...
//     play.arm(&p, now + cooldown)
//
//   combined (the simple recurring cooldown — check and re-arm in one):
//     if play.ready(&p, now, interval) { ...act... }
//
// Re-arm is `now + interval`, NOT `next += interval`: after a stall the timer
// resumes from NOW instead of firing a catch-up burst. That is what a gameplay
// cooldown wants (no machine-gun after a hitch); a fixed-cadence scheduler would
// want the accumulating form — a different primitive if a game ever needs it.
Pace :: struct($T: typeid) {
	next: T,
}

// due reports whether the clock has reached the armed deadline. Cheap and pure —
// safe inside a compound guard (`play.due(&p, tick) && in_range`), and it does NOT
// re-arm, so pair it with `arm` when the interval depends on state read afterward.
due :: proc(p: ^Pace($T), now: T) -> bool {
	return now >= p.next
}

// arm sets the next deadline to the ABSOLUTE moment `at` (e.g. now + cooldown, or a
// spawn wind-up like tick + 90). The re-arm half of the split idiom.
arm :: proc(p: ^Pace($T), at: T) {
	p.next = at
}

// ready is the recurring-cooldown one-liner: if the deadline has passed, re-arm to
// now + interval and return true (fire this frame); otherwise return false and
// leave the deadline. Short-circuits cleanly inside a guard, e.g.
// `in_range && play.ready(&p, tick, cd)` only re-arms when in range AND due.
ready :: proc(p: ^Pace($T), now, interval: T) -> bool {
	if now < p.next {
		return false
	}
	p.next = now + interval
	return true
}
