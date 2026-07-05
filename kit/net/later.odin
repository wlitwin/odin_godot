package kit_net

// later — a delay queue for presenting events on the RENDER timeline.
//
// A peer watching a remote simulation lives on two clocks: reliable state
// (deltas, despawns, results) applies the moment it arrives, but the
// simulation itself RENDERS interp-delay in the past — that buffer is what
// makes a 20 Hz stream look like motion. So a consequence applied on arrival
// plays ~interp_delay EARLY against what the eye is watching: the gem
// vanishes before the rendered ball reaches it. Both channels crossed the
// same wire, so transit cancels — delaying PRESENTATION by exactly the
// interp delay re-aligns the consequence with the rendered cause, within
// jitter. State never waits; only the showing does.
//
// Entries carry their HANDLER: one presentation proc holds the whole effect
// (no verb enums, no drain switch — the same shape that makes @(gd_command)
// pleasant: the logic lives in exactly one proc). Most games never touch
// this directly — ksess.session_present wraps the timing decision and the
// session drains its queue every tick; this stays public for engine-free
// tests and games with their own clocks.

// One presentation effect. `id`/`a` are whatever context the effect needs
// (an entity to hide, a count to display); presentation procs should only
// touch LOCAL things — nodes, particles, sounds — never replicated state.
Later_Proc :: proc(user: rawptr, id: Net_Id, a: u64)

Later_Entry :: struct {
	due:  f64,
	cb:   Later_Proc,
	user: rawptr,
	id:   Net_Id,
	a:    u64,
}

Later :: struct {
	entries: [dynamic]Later_Entry,
	due_buf: [dynamic]Later_Entry, // collect-then-call: callbacks may push new entries
}

later_destroy :: proc(l: ^Later) {
	delete(l.entries)
	delete(l.due_buf)
	l^ = {}
}

later_push :: proc(l: ^Later, due: f64, user: rawptr, cb: Later_Proc, id := NET_ID_INVALID, a := u64(0)) {
	assert(cb != nil)
	append(&l.entries, Later_Entry{due = due, cb = cb, user = user, id = id, a = a})
}

// Run everything due at `now`, in push order (stable: same-frame effects
// present in the order they were queued). Returns how many ran. Effects
// pushed BY an effect wait for their own due time on a later drain.
later_drain :: proc(l: ^Later, now: f64) -> int {
	clear(&l.due_buf)
	i := 0
	for i < len(l.entries) {
		if l.entries[i].due <= now {
			append(&l.due_buf, l.entries[i])
			ordered_remove(&l.entries, i)
		} else {
			i += 1
		}
	}
	for e in l.due_buf {
		e.cb(e.user, e.id, e.a)
	}
	return len(l.due_buf)
}

// Drop everything pending (a level change: the world those effects were
// about no longer exists).
later_clear :: proc(l: ^Later) {
	clear(&l.entries)
}

later_pending :: proc(l: ^Later) -> int {
	return len(l.entries)
}
