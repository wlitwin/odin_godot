package kit_net

// intent — the bookkeeping half of the intent→command→result pipeline.
//
// A client issuing a predicted command: allocates a sequence number, captures the
// entity's declared fields (fields_capture), applies the command optimistically,
// and records a Pending entry. The host's result either CONFIRMS (entry discarded,
// nothing replays — the intent id is how effect echoes are matched) or REJECTS
// (caller restores the captured fields). An entry whose result never arrives times
// out and is handed back for the same revert — a prediction can never leak.
//
// The host side keeps a per-peer Dedup_Window so duplicated / reordered / replayed
// commands (retransmits, reconnect replays) execute EXACTLY ONCE.
//
// This file is pure bookkeeping — it never touches entities itself. The session
// layer owns entity lookup and calls fields_restore with the returned snapshots
// (an entity may despawn while a prediction is pending; resolving Net_Id → pointer
// is the registry's job, not ours).

// Unique per (issuing peer, session). u32 sequence: ~4 billion commands per peer
// per session — wraparound is not handled, by design.
Intent_Seq :: distinct u32

Pending :: struct {
	seq:         Intent_Seq,
	entity:      Net_Id,
	revert:      []u8, // fields_capture buffer (shadow layout); ownership transfers back on confirm/reject/timeout
	issued_tick: u64,
}

Pending_Table :: struct {
	next_seq: Intent_Seq,
	entries:  [dynamic]Pending,
}

pending_table_make :: proc(allocator := context.allocator) -> Pending_Table {
	return Pending_Table{next_seq = 1, entries = make([dynamic]Pending, 0, 16, allocator)}
}

pending_table_destroy :: proc(t: ^Pending_Table) {
	for e in t.entries {
		delete(e.revert)
	}
	delete(t.entries)
	t.entries = nil
}

// Allocate the next intent sequence and record the pending prediction. `revert`
// ownership moves into the table.
pending_add :: proc(t: ^Pending_Table, entity: Net_Id, revert: []u8, now_tick: u64) -> Intent_Seq {
	seq := t.next_seq
	t.next_seq += 1
	append(&t.entries, Pending{seq = seq, entity = entity, revert = revert, issued_tick = now_tick})
	return seq
}

@(private = "file")
pending_take :: proc(t: ^Pending_Table, seq: Intent_Seq) -> (p: Pending, ok: bool) {
	for e, i in t.entries {
		if e.seq == seq {
			p = e
			ordered_remove(&t.entries, i) // order preserved: reverts must undo newest-first
			return p, true
		}
	}
	return {}, false
}

// The host confirmed the prediction: the optimistic state stands. The revert
// buffer is freed here — nothing to undo, and (crucially) nothing to REPLAY:
// the caller uses the seq to match/suppress the echoed transition's effects.
pending_confirm :: proc(t: ^Pending_Table, seq: Intent_Seq) -> bool {
	p, ok := pending_take(t, seq)
	if ok {
		delete(p.revert)
	}
	return ok
}

// The host rejected the prediction (or it can't apply anymore). Returns the
// pending record; the CALLER restores the fields (it owns entity resolution)
// and must delete(p.revert) afterwards.
pending_reject :: proc(t: ^Pending_Table, seq: Intent_Seq) -> (p: Pending, ok: bool) {
	return pending_take(t, seq)
}

// Pop every entry older than `max_age_ticks` into `expired` (appended). The caller
// reverts each exactly like a rejection — a result that never arrives must behave
// as a loud "no". Entries are returned oldest-first.
pending_expire :: proc(t: ^Pending_Table, now_tick: u64, max_age_ticks: u64, expired: ^[dynamic]Pending) {
	for i := 0; i < len(t.entries); {
		if now_tick - t.entries[i].issued_tick >= max_age_ticks {
			append(expired, t.entries[i])
			ordered_remove(&t.entries, i)
		} else {
			i += 1
		}
	}
}

pending_count :: proc(t: ^Pending_Table) -> int {
	return len(t.entries)
}

// ---------------------------------------------------------------------------
// Host-side per-peer dedup: a 64-command sliding window over the peer's intent
// sequences. accept() answers "is this the first time I see seq?" — duplicates
// within the window, already-seen seqs, and anything older than the window are
// all rejected (a command 64+ behind the newest is a stale retransmit, not new).

Dedup_Window :: struct {
	latest: Intent_Seq, // highest seq accepted so far (0 = none yet)
	window: u64,        // bit i = (latest - i) was seen, bit 0 = latest itself
}

dedup_accept :: proc(d: ^Dedup_Window, seq: Intent_Seq) -> bool {
	if seq == 0 {
		return false // 0 is never a valid sequence (tables start at 1)
	}
	if d.latest == 0 || seq > d.latest {
		shift := u64(seq - d.latest) // d.latest==0 → large shift → window clears, correct
		if d.latest == 0 {shift = 64}
		if shift >= 64 {
			d.window = 1
		} else {
			d.window = (d.window << shift) | 1
		}
		d.latest = seq
		return true
	}
	back := u64(d.latest - seq)
	if back >= 64 {
		return false // older than the window: stale duplicate
	}
	bit := u64(1) << back
	if d.window & bit != 0 {
		return false // already executed
	}
	d.window |= bit
	return true // late-but-new arrival within the window
}
