package kit_sim

// snapshot — the authority's wire: tick-stamped predict-set batches, delta-
// compressed against the last state the client CONFIRMED holding.
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
// length, never abandons the batch) and EVERY registered entity rides every
// batch — an unchanged entity costs its header + an all-zero mask (~10 bytes).
// Absence therefore never carries meaning, which is what makes the carry-
// forward story trivial; per-recipient interest filtering can reintroduce
// absence later, the way registry_collect_deltas composes today.
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

// Byte size of one predict-set snapshot ON THE WIRE (Wire_Kind encodings
// applied) — what a full row's payload occupies. The stream_wire_size of
// this lane.
predict_wire_size :: proc(desc: ^knet.Entity_Desc) -> int {
	n := 0
	for f in desc.fields {
		if .Predicted in f.flags {
			n += knet.field_wire_size(f)
		}
	}
	return n
}

@(private = "file")
subset_mask_bytes :: proc(desc: ^knet.Entity_Desc) -> int {
	n := 0
	for f in desc.fields {
		if .Predicted in f.flags {
			n += 1
		}
	}
	return (n + 7) / 8
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
snap_write :: proc(w: ^knet.Writer, entries: []Entry, tick: u64, baseline: u64, input_ack: u64) -> int {
	knet.write_u64(w, tick)
	knet.write_u64(w, baseline)
	knet.write_u64(w, input_ack)
	count_at := len(w.buf)
	knet.write_u16(w, 0) // patched below
	count := 0
	for &e in entries {
		desc := e.hist.desc
		if e.hist.size == 0 {
			continue // predicts nothing — not this lane's entity
		}
		now, have_now := history_read(e.hist, tick)
		assert(have_now, "snap_write ships ledgered ticks: note_all before snapping")
		base, have_base := history_read(e.hist, baseline)

		knet.write_net_id(w, e.id)
		if !have_base {
			// New entity or lapped baseline: the full row that needs nothing.
			knet.write_u8(w, SNAP_FULL)
			knet.write_u16(w, u16(predict_wire_size(desc)))
			write_subset_full(w, now, desc)
			count += 1
			continue
		}
		knet.write_u8(w, 0)
		len_at := len(w.buf)
		knet.write_u16(w, 0) // patched below
		payload_from := len(w.buf)
		write_subset_delta(w, now, base, desc)
		payload := len(w.buf) - payload_from
		assert(payload <= int(max(u16)))
		w.buf[len_at] = u8(payload)
		w.buf[len_at + 1] = u8(payload >> 8)
		count += 1
	}
	assert(count <= int(max(u16)))
	w.buf[count_at] = u8(count)
	w.buf[count_at + 1] = u8(count >> 8)
	return count
}

// The whole subset, wire-encoded from a struct-layout ledger blob.
@(private = "file")
write_subset_full :: proc(w: ^knet.Writer, blob: []u8, desc: ^knet.Entity_Desc) {
	off := 0
	for f in desc.fields {
		if .Predicted not_in f.flags {
			continue
		}
		knet.field_encode(w, &blob[off], f)
		off += f.size
	}
}

// Mask + dirty fields, diffed blob-vs-baseline on struct bytes (the same
// rule as the delta walk: dirtiness is judged in memory, encoding happens
// at the wire edge).
@(private = "file")
write_subset_delta :: proc(w: ^knet.Writer, now: []u8, base: []u8, desc: ^knet.Entity_Desc) {
	mask: u64
	off := 0
	ord := 0
	for f in desc.fields {
		if .Predicted not_in f.flags {
			continue
		}
		if mem.compare(now[off:off + f.size], base[off:off + f.size]) != 0 {
			mask |= 1 << u64(ord)
		}
		off += f.size
		ord += 1
	}
	nbytes := subset_mask_bytes(desc)
	for i in 0 ..< nbytes {
		knet.write_u8(w, u8(mask >> (u64(i) * 8)))
	}
	off = 0
	ord = 0
	for f in desc.fields {
		if .Predicted not_in f.flags {
			continue
		}
		if mask & (1 << u64(ord)) != 0 {
			knet.field_encode(w, &now[off], f)
		}
		off += f.size
		ord += 1
	}
}

// ---------------------------------------------------------------------------
// Client side: wire → RECEIVED ledger → Truths for the reconcile.
//
// The received ledger is distinct from the prediction ledger on purpose:
// deltas decode against what the server SENT (and the client acked), never
// against what the client guessed — a mispredict must not corrupt the
// decode baseline.

Rx_Entry :: struct {
	id:   knet.Net_Id,
	hist: History, // received truth, owned by the Snap_Rx
}

// How many recent batch ticks the receiver remembers for bracket lookups
// (lane_present interpolates watched entities between two of them). At the
// default 20 Hz snap rate this is ~800ms of history — the stream ring's
// INTERP_CAP reasoning.
SNAP_APPLIED_CAP :: 16

Snap_Rx :: struct {
	entries: [dynamic]Rx_Entry,
	slots:   int, // ledger depth for entities added later
	newest:  u64, // newest batch tick applied (stale/duplicate gate)
	acked:   u64, // newest FULLY-applied batch tick — THE ack to send
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
snap_rx_add :: proc(rx: ^Snap_Rx, id: knet.Net_Id, desc: ^knet.Entity_Desc, allocator := context.allocator) {
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
snap_rx_apply :: proc(rx: ^Snap_Rx, r: ^knet.Reader, truths: ^[dynamic]Truth) -> (tick: u64, input_ack: u64, applied: int) {
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
		if r.err || r.off + n > len(r.data) {
			r.err = true
			return 0, 0, 0 // truncated mid-batch: drop it all, the next one supersedes
		}
		payload := r.data[r.off:r.off + n]
		r.off += n

		e := find_rx(rx, id)
		if e == nil {
			skipped += 1 // spawn still in flight on the reliable lane
			continue
		}
		scratch := make([]u8, e.hist.size, context.temp_allocator)
		if flags & SNAP_FULL != 0 {
			if !decode_subset_full(scratch, payload, e.hist.desc) {
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
			if !decode_subset_delta(scratch, payload, e.hist.desc) {
				skipped += 1
				continue
			}
		}
		history_note_bytes(&e.hist, tick, scratch)
		blob, _ := history_read(&e.hist, tick)
		append(truths, Truth{id = id, blob = blob})
		applied += 1
	}
	rx.newest = tick
	if skipped == 0 {
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

@(private = "file")
find_rx :: proc(rx: ^Snap_Rx, id: knet.Net_Id) -> ^Rx_Entry {
	for &e in rx.entries {
		if e.id == id {
			return &e
		}
	}
	return nil
}

// false = payload malformed for this descriptor (wrong length) — the row is
// skipped, the batch survives. A well-formed payload decodes exactly.
@(private = "file")
decode_subset_full :: proc(dst: []u8, payload: []u8, desc: ^knet.Entity_Desc) -> bool {
	if len(payload) != predict_wire_size(desc) {
		return false
	}
	doff, woff := 0, 0
	for f in desc.fields {
		if .Predicted not_in f.flags {
			continue
		}
		knet.field_decode(&dst[doff], ([^]u8)(&payload[woff]), f)
		doff += f.size
		woff += knet.field_wire_size(f)
	}
	return true
}

@(private = "file")
decode_subset_delta :: proc(dst: []u8, payload: []u8, desc: ^knet.Entity_Desc) -> bool {
	nbytes := subset_mask_bytes(desc)
	if len(payload) < nbytes {
		return false
	}
	mask: u64
	for i in 0 ..< nbytes {
		mask |= u64(payload[i]) << (u64(i) * 8)
	}
	doff, woff := 0, nbytes
	ord := 0
	for f in desc.fields {
		if .Predicted not_in f.flags {
			continue
		}
		if mask & (1 << u64(ord)) != 0 {
			n := knet.field_wire_size(f)
			if woff + n > len(payload) {
				return false
			}
			knet.field_decode(&dst[doff], ([^]u8)(&payload[woff]), f)
			woff += n
		}
		doff += f.size
		ord += 1
	}
	return woff == len(payload) // trailing garbage is malformed, not ignored
}
