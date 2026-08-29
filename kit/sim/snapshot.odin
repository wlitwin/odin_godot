package kit_sim

// snapshot — the authority's wire: tick-stamped predict-set batches, delta-
// compressed against the last state the client CONFIRMED holding.
//
// Despite the name, most of what follows is the sim lane's ack-baselined DELTA
// codec (mask + dirty fields, diffed against an acked baseline); the full-row
// SNAPSHOT is only the fallback case — the row a client gets when no baseline
// is shared yet (a fresh spawn, a lapped ledger). "snapshot" names the batch's
// job, not the shape most rows take.
//
// The loop this file closes (the sim lane's whole conversation):
//
//   client → server   [input window]           (input.odin)  [snap ack u64]
//   server → client   [snap batch: tick, baseline, input ack, rows]
//
// THE BASELINE IS AN ACK, NOT A GUESS. The server deltas every entity against
// its ledgered truth at `baseline` — a tick the client explicitly acked, so
// both sides hold byte-identical state for it. Unreliable, unordered, last-
// value: a lost batch is superseded by the next one, a stale or duplicate
// batch is dropped by tick. What keeps the scheme honest through loss,
// reordering, and late joins is one invariant:
//
//   A CLIENT ACKS A BATCH ONLY WHEN IT APPLIED EVERY ROW.
//
// A row it had to skip (an entity whose spawn is still in flight on the
// reliable lane, a malformed length) leaves the ack where it was; the server
// keeps deltaing against the older confirmed tick — and for any entity whose
// ledger no longer reaches that tick (freshly spawned, or the client stalled
// past the ledger window) it falls back to a FULL row. Fulls decode with no
// baseline at all, so the client that finally learns the entity catches up on
// the next batch and the ack advances again. Self-healing in both directions,
// no keyframe request message, no retransmit.
//
// Rows ride length-prefixed like stream batches (an unknown id is skipped by
// length, never abandons the batch). The lane composes them PER RECIPIENT:
// owner first, then stalest/nearest interested entities within the byte budget.
// An unchanged entity costs zero row bytes: both ends carry its acknowledged
// value forward to this batch tick. AOI/budget omissions are different — the
// server does not mark them represented, so a later re-entry is forced FULL.
// Thus absence saves bytes without ever pretending the client holds a baseline
// it did not receive.
//
// Batch layout:
//   [tick u64][baseline u64][input_ack u64][count u16]
//     count × [net_id u32][flags u8][len u16][payload]
//   full row payload:   the predict subset, wire-encoded, field order
//   delta row payload:  [mask][dirty fields wire-encoded]  (mask bit i = i-th
//                       PREDICTED field, ceil(n/8) bytes)
//
// input_ack rides the batch header because batches are already composed
// per-client (the baseline is per-client) — the input ring's trim signal
// costs eight bytes in a message that was going to that client anyway.

import "core:mem"
import knet "godot:kit/net"

SNAP_FULL: u8 : 1 << 0 // row flag: payload is the whole subset, no baseline needed
SNAP_HEADER_BYTES :: 8 + 8 + 8 + 2
SNAP_ROW_HEADER_BYTES :: 4 + 1 + 2

Snap_Write_Stats :: struct {
	rows:       int,
	full:       int,
	delta:      int,
	suppressed: int,
	deferred:   int,
	bytes:      int,
}

// Byte size of one predict-set snapshot ON THE WIRE (Wire_Kind encodings
// applied) — what a full row's payload occupies. The stream_wire_size of
// this lane.
predict_wire_size :: proc(desc: ^knet.Entity_Desc) -> int {
	return knet.subset_view(desc, .Predicted).wire_bytes
}

// ---------------------------------------------------------------------------
// Server side: ledger → wire. Pure — per-client ack state lives in the
// driver (a map[peer]u64 beside the input buffers); this proc just writes
// one client's batch given the tick to ship and the tick that client acked.

// Write one snapshot batch from the entries' TRUTH ledgers. `tick` must be
// ledgered for every entry (the sim loop's contract: note_all, then snap) —
// entities that predict nothing are skipped. `baseline` is the target
// client's newest fully-applied tick (0 = nothing acked yet → all fulls).
// Returns the row count.
snap_write :: proc(
	w: ^knet.Writer,
	entries: []Entry,
	tick: u64,
	baseline: u64,
	input_ack: u64,
) -> int {
	stats := snap_write_recipient(w, entries, tick, baseline, input_ack, 0, nil, false)
	return stats.rows
}

// Per-recipient writer used by Lane. `budget` is the maximum snapshot body
// size (header + rows; zero is unlimited). `sent` records the exact batch tick
// in which each entity was represented for this peer. A delta is legal only
// when that row was represented in the peer's ACKED baseline batch; otherwise
// re-entry/deferred work is a full row. Unchanged rows advance `sent` without
// bytes because the receiver carries its baseline bytes forward to `tick`.
snap_write_recipient :: proc(
	w: ^knet.Writer,
	entries: []Entry,
	tick: u64,
	baseline: u64,
	input_ack: u64,
	budget: int,
	sent: ^map[knet.Net_Id]u64,
	suppress_unchanged := true,
) -> Snap_Write_Stats {
	assert(len(entries) <= int(max(u16)), "snapshot entity count exceeds its u16 wire field")
	assert(
		len(entries) <= knet.MAX_CONTAINER_ITEMS,
		"snapshot entity count exceeds MAX_CONTAINER_ITEMS",
	)
	start := len(w.buf)
	knet.write_u64(w, tick)
	knet.write_u64(w, baseline)
	knet.write_u64(w, input_ack)
	count_at := len(w.buf)
	knet.write_u16(w, 0) // patched below
	stats: Snap_Write_Stats
	for &e in entries {
		desc := e.hist.desc
		if e.hist.size == 0 {
			continue // predicts nothing — not this lane's entity
		}
		now, have_now := history_read(e.hist, tick)
		assert(have_now, "snap_write ships ledgered ticks: note_all before snapping")
		base, have_base := history_read(e.hist, baseline)
		if sent != nil && have_base {
			last, represented := sent^[e.id]
			have_base = represented && last == baseline
		}

		pred := knet.subset_view(desc, .Predicted)
		assert(
			pred.wire_bytes <= knet.MAX_REPLICATED_ENTITY_BYTES,
			"full snapshot row exceeds MAX_REPLICATED_ENTITY_BYTES",
		)
		if have_base && suppress_unchanged && mem.compare(now, base) == 0 {
			stats.suppressed += 1
			if sent != nil {
				sent^[e.id] = tick
			}
			continue
		}
		row := knet.writer_make(SNAP_ROW_HEADER_BYTES + pred.wire_bytes, context.temp_allocator)
		knet.write_net_id(&row, e.id)
		if !have_base {
			// New entity or lapped baseline: the full row that needs nothing.
			knet.write_u8(&row, SNAP_FULL)
			knet.write_u16(&row, u16(pred.wire_bytes))
			knet.subset_write_blob(&row, pred, now)
			stats.full += 1
		} else {
			knet.write_u8(&row, 0)
			len_at := len(row.buf)
			knet.write_u16(&row, 0) // patched below
			payload_from := len(row.buf)
			knet.subset_delta_write(&row, pred, now, base)
			payload := len(row.buf) - payload_from
			assert(payload <= int(max(u16)))
			knet.writer_patch_u16(&row, len_at, u16(payload))
			stats.delta += 1
		}
		if budget > 0 && len(w.buf) - start + len(row.buf) > budget {
			stats.deferred += 1
			if have_base {
				stats.delta -= 1
			} else {
				stats.full -= 1
			}
			continue
		}
		append(&w.buf, ..row.buf[:])
		stats.rows += 1
		if sent != nil {
			sent^[e.id] = tick
		}
	}
	assert(stats.rows <= int(max(u16)))
	knet.writer_patch_u16(w, count_at, u16(stats.rows))
	stats.bytes = len(w.buf) - start
	return stats
}

// ---------------------------------------------------------------------------
// Client side: wire → RECEIVED ledger → Truths for the reconcile.
//
// The received ledger is distinct from the prediction ledger on purpose:
// deltas decode against what the server SENT (and the client acked), never
// against what the client guessed — a mispredict must not corrupt the
// decode baseline.

Rx_Entry :: struct {
	id:       knet.Net_Id,
	hist:     History, // received truth, owned by the Snap_Rx
	first:    u64, // the first tick this entity was ever ledgered here (0 = none yet) —
	// a fresh watched spawn has no truth before it, so the presenter holds
	// it at this pose (the muzzle) until the delayed watch clock arrives,
	// instead of leaving the node at its stale/default value
	revealed: bool, // has the present_ready hook fired (the watch clock reached `first`) —
	// the engine layer reveals the hidden node exactly once, on cue
}

// How many recent batch ticks the receiver remembers for bracket lookups
// (lane_present interpolates watched entities between two of them). At the
// default 20 Hz snap rate this is ~800ms of history — the stream ring's
// depth, by the stream ring's reasoning.
SNAP_APPLIED_CAP :: knet.INTERP_CAP

Snap_Rx :: struct {
	entries:       [dynamic]Rx_Entry,
	slots:         int, // ledger depth for entities added later
	newest:        u64, // newest batch tick applied (stale/duplicate gate)
	acked:         u64, // newest FULLY-applied batch tick — THE ack to send
	// Ring of applied batch ticks, oldest first — batches apply in tick
	// order (stale ones drop), so this is sorted by construction.
	applied:       [SNAP_APPLIED_CAP]u64,
	applied_count: int,
}

// `slots` must cover the ack round trip in batch ticks (an acked tick stays
// the decode baseline until the server hears the next ack).
snap_rx_make :: proc(slots: int, allocator := context.allocator) -> Snap_Rx {
	return Snap_Rx{entries = make([dynamic]Rx_Entry, allocator), slots = slots}
}

snap_rx_destroy :: proc(rx: ^Snap_Rx) {
	for &e in rx.entries {
		history_destroy(&e.hist)
	}
	delete(rx.entries)
	rx.entries = nil
}

// Track an entity (at spawn, from the reliable lane). Rows for ids nobody
// tracks are skipped by length — and stall the ack, which is the mechanism
// that keeps the server's baselines honest while this call is in flight.
snap_rx_add :: proc(
	rx: ^Snap_Rx,
	id: knet.Net_Id,
	desc: ^knet.Entity_Desc,
	allocator := context.allocator,
) {
	assert(find_rx(rx, id) == nil, "snap_rx_add: id tracked twice")
	append(&rx.entries, Rx_Entry{id = id, hist = history_make(desc, rx.slots, allocator)})
}

snap_rx_remove :: proc(rx: ^Snap_Rx, id: knet.Net_Id) -> bool {
	for &e, i in rx.entries {
		if e.id == id {
			history_destroy(&e.hist)
			ordered_remove(&rx.entries, i)
			return true
		}
	}
	return false
}

// Apply one received batch. Returns tick = 0 for stale/duplicate/malformed
// (nothing changed); otherwise the batch tick, the server's input ack (feed
// input_write), and how many rows applied. Truth rows for the applied
// entities are appended to `truths` — blobs are views into the received
// ledger, valid until the next apply; hand them straight to reconcile.
snap_rx_apply :: proc(
	rx: ^Snap_Rx,
	r: ^knet.Reader,
	truths: ^[dynamic]Truth,
) -> (
	tick: u64,
	input_ack: u64,
	applied: int,
) {
	// Validate the entire batch before noting any history row. This keeps a
	// truncated/malformed suffix from leaving phantom tick state behind.
	probe := r^
	probe_tick := knet.read_u64(&probe)
	_ = knet.read_u64(&probe)
	_ = knet.read_u64(&probe)
	probe_count := int(knet.read_u16(&probe))
	if probe.err || probe_tick <= rx.newest || !knet.reader_admit_count(&probe, probe_count, 7) {
		if probe.err {
			r.err = true
		}
		return 0, 0, 0
	}
	for _ in 0 ..< probe_count {
		_ = knet.read_net_id(&probe)
		flags := knet.read_u8(&probe)
		n := int(knet.read_u16(&probe))
		if flags & ~SNAP_FULL != 0 || n > knet.MAX_REPLICATED_ENTITY_BYTES {
			probe.err = true
			break
		}
		_ = knet.reader_view(&probe, n)
	}
	if probe.err {
		r.err = true
		return 0, 0, 0
	}
	tick = knet.read_u64(r)
	baseline := knet.read_u64(r)
	input_ack = knet.read_u64(r)
	count := int(knet.read_u16(r))
	if r.err || tick <= rx.newest {
		return 0, 0, 0 // stale or duplicate: superseded, drop whole batch
	}
	skipped := 0
	for _ in 0 ..< count {
		id := knet.read_net_id(r)
		flags := knet.read_u8(r)
		n := int(knet.read_u16(r))
		payload := knet.reader_view(r, n)
		if r.err {
			return 0, 0, 0
		}

		e := find_rx(rx, id)
		if e == nil {
			skipped += 1 // spawn still in flight on the reliable lane
			continue
		}
		pred := knet.subset_view(e.hist.desc, .Predicted)
		scratch := make([]u8, e.hist.size, context.temp_allocator)
		if flags & SNAP_FULL != 0 {
			if !knet.subset_decode_full(pred, scratch, payload) {
				skipped += 1
				continue
			}
		} else {
			base, have := history_read(&e.hist, baseline)
			if !have {
				skipped += 1 // we never confirmed that baseline; a full will come
				continue
			}
			copy(scratch, base)
			if !knet.subset_delta_apply(pred, scratch, payload) {
				skipped += 1
				continue
			}
		}
		history_note_bytes(&e.hist, tick, scratch)
		if e.first == 0 {
			e.first = tick // the earliest pose the presenter can hold this entity at
		}
		blob, _ := history_read(&e.hist, tick)
		append(truths, Truth{id = id, blob = blob})
		applied += 1
	}
	rx.newest = tick
	if skipped == 0 {
		// A recipient batch may omit rows because they are unchanged, outside
		// AOI, or over budget. Carry the acknowledged baseline forward locally;
		// the server's per-entity sent ledger decides whether that carry is exact
		// (eligible for a future delta) or stale (must receive a full on re-entry).
		for &e in rx.entries {
			if _, have_tick := history_read(&e.hist, tick); have_tick {
				continue
			}
			if base, have_base := history_read(&e.hist, baseline); have_base {
				history_note_bytes(&e.hist, tick, base)
				carried, _ := history_read(&e.hist, tick)
				append(truths, Truth{id = e.id, blob = carried})
			}
		}
		rx.acked = tick // every row landed: this tick is a valid future baseline
	}
	if rx.applied_count < SNAP_APPLIED_CAP {
		rx.applied[rx.applied_count] = tick
		rx.applied_count += 1
	} else {
		copy(rx.applied[:SNAP_APPLIED_CAP - 1], rx.applied[1:])
		rx.applied[SNAP_APPLIED_CAP - 1] = tick
	}
	return tick, input_ack, applied
}

// The applied batch ticks bracketing time `at` (in ticks, fractional).
// ok=false when fewer than two batches have applied or `at` predates the
// window; at-or-past the newest returns (newest, newest) — the clamp-and-
// hold rule, never extrapolation.
snap_rx_bracket :: proc(rx: ^Snap_Rx, at: f64) -> (prev: u64, next: u64, ok: bool) {
	if rx.applied_count < 2 {
		return 0, 0, false
	}
	newest := rx.applied[rx.applied_count - 1]
	if at >= f64(newest) {
		return newest, newest, true
	}
	if at < f64(rx.applied[0]) {
		return 0, 0, false
	}
	for i in 1 ..< rx.applied_count {
		if f64(rx.applied[i]) >= at {
			return rx.applied[i - 1], rx.applied[i], true
		}
	}
	return newest, newest, true // unreachable given the clamps; safe fallback
}

// The eight-byte client→server half of the ack loop (the driver appends it
// to the input packet).
snap_ack_write :: proc(w: ^knet.Writer, rx: ^Snap_Rx) {
	knet.write_u64(w, rx.acked)
}

snap_ack_read :: proc(r: ^knet.Reader) -> u64 {
	return knet.read_u64(r)
}

@(private) // lane.odin's presenter and fact paths resolve rx entries too
find_rx :: proc(rx: ^Snap_Rx, id: knet.Net_Id) -> ^Rx_Entry {
	for &e in rx.entries {
		if e.id == id {
			return &e
		}
	}
	return nil
}
