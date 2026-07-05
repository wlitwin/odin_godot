package kit_net

// later — a tiny delay queue for presenting events on the RENDER timeline.
//
// A peer watching a remote simulation lives on two clocks: reliable state
// (deltas, despawns, results) applies the moment it arrives, but the
// simulation itself RENDERS interp-delay in the past — that buffer is what
// makes a 20 Hz stream look like motion. So a consequence applied on arrival
// plays ~interp_delay EARLY against what the eye is watching: the gem
// vanishes before the rendered ball reaches it, the door opens before the
// rendered cart docks. Both channels crossed the same wire, so transit
// cancels — delaying PRESENTATION by exactly the interp delay re-aligns the
// consequence with the rendered cause, within jitter.
//
// That is all this is: push what to show and when, drain what's due each
// frame. State stays as fresh as the wire (gameplay reads truth); only the
// showing waits. The peer whose OWN simulation caused the event presents
// immediately — its screen is the truth everyone else is waiting to see.
//
//     // observer, on the taken-edge:
//     knet.later_push(&g.later, now + ksess.session_interp_delay(&g.ses), HIDE_GEM, id)
//     // every frame:
//     for e in knet.later_drain(&g.later, now) {
//         switch e.kind { case HIDE_GEM: hide(e.id) }
//     }
//
// The other half of the discipline (see docs/kit/net.md "The two timelines"):
// the AUTHORITY must keep the entity alive long enough to be presented —
// an edge (despawn, reset) must outlive the slowest observer, so give it a
// dwell ≥ interp delay before the node actually dies.

Later_Entry :: struct {
	due:  f64, // present at/after this time (the caller's clock)
	kind: u16, // game-defined verb
	id:   Net_Id, // what it concerns (NET_ID_INVALID is fine for global events)
	a:    u64, // one payload word — enough for a kind/count/player in a pinch
}

Later :: struct {
	entries: [dynamic]Later_Entry,
	due_buf: [dynamic]Later_Entry, // drain reuses this; valid until the next drain
}

later_destroy :: proc(l: ^Later) {
	delete(l.entries)
	delete(l.due_buf)
	l^ = {}
}

later_push :: proc(l: ^Later, due: f64, kind: u16, id := NET_ID_INVALID, a := u64(0)) {
	append(&l.entries, Later_Entry{due = due, kind = kind, id = id, a = a})
}

// Everything due at `now`, in push order (stable: same-frame events present
// in the order they were queued). The slice is valid until the next drain.
later_drain :: proc(l: ^Later, now: f64) -> []Later_Entry {
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
	return l.due_buf[:]
}

// Drop everything pending (a level change: the world those events were
// about no longer exists).
later_clear :: proc(l: ^Later) {
	clear(&l.entries)
}

later_pending :: proc(l: ^Later) -> int {
	return len(l.entries)
}
