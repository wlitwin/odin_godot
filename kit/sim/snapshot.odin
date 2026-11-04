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
import bd "godot:box3d/diagnostics"
import knet "godot:kit/net"
import ksess "godot:kit/session"

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

// Complete whole-world protocol encoding. Unlike SIM_SNAP, no recipient body
// filtering, raw typeid, host pointer, struct padding, or per-entity truth delta
// is a valid full physics attachment.
@(private)
world_wire_effect :: proc(n: ^World_Network, kind: u16) -> ^World_Effect_Def {
	for &e in n.effects {if e.kind == kind {return &e}}
	return nil
}
@(private)
world_wire_game :: proc(l: ^Lane, f: ^World_Frame) -> ([]u8, World_Error) {
	context.allocator=l.allocator
	n :=
		l.world.network; writer := knet.writer_make(256, l.allocator); defer knet.writer_destroy(&writer)
	knet.write_u32(&writer, u32(len(n.config.codec.fields)))
	for binding in l.world.bindings {
		for field in n.config.codec.fields {if field.id == binding.id {
				wire, err := make(
					[]u8,
					field.codec.wire_bytes,
					l.allocator,
				); if err != nil {return nil, .Allocation_Failed}
				e := field.codec.encode(
					field.codec.user,
					f.fields[binding.offset:binding.offset + binding.size],
					wire,
				)
				if e != .Ok {delete(wire); return nil, e}
				knet.write_net_id(
					&writer,
					field.id,
				); knet.write_u32(&writer, u32(len(wire))); for b in wire {knet.write_u8(&writer, b)}; delete(wire)
			}}
	}
	knet.write_u8(&writer, u8(len(n.drivers)))
	for d in n.drivers {knet.write_player_id(&writer, d.player); knet.write_u16(&writer, d.class)}
	first := f.tick
	for first > 0 &&
	    f.tick - first <
		    WORLD_REPAIR_TICKS -
			    1 {prior := &n.accepted[(first - 1) % WORLD_HISTORY_FRAMES]; if !prior.valid || prior.tick != first - 1 {break}; first -= 1}
	knet.write_u64(&writer, first); knet.write_u8(&writer, u8(f.tick - first + 1))
	for tick := first; tick <= f.tick; tick += 1 {
		row := &n.accepted[tick % WORLD_HISTORY_FRAMES]; if !row.valid || row.tick != tick {return nil, .History_Missing}
		data := world_net_data(n, n.accepted_data, tick)
		for d, i in n.drivers {
			c := world_net_input_codec(n, d.class); wire: [MAX_INPUT_SIZE]u8
			if e := c.encode(c.user, world_net_driver_bytes(n, data, i), wire[:c.wire_bytes]);
			   e != .Ok {return nil, e}
			knet.write_u8(
				&writer,
				u8(row.origin[i]),
			); knet.write_u64(&writer, row.sequence[i]); for b in wire[:c.wire_bytes] {knet.write_u8(&writer, b)}
		}
		if tick == max(u64) {break}
	}
	result, err := make(
		[]u8,
		len(knet.writer_bytes(&writer)),
		l.allocator,
	); if err != nil {return nil, .Allocation_Failed}; copy(result, knet.writer_bytes(&writer)); return result, .Ok
}
@(private)
world_wire_occurrences :: proc(l: ^Lane, f: ^World_Frame) -> ([]u8, World_Error) {
	context.allocator=l.allocator
	n :=
		l.world.network; writer := knet.writer_make(64, l.allocator); defer knet.writer_destroy(&writer)
	knet.write_u8(&writer, u8(f.effect_count))
	for &e in f.effects[:f.effect_count] {
		def := world_wire_effect(
			n,
			e.kind,
		); if def == nil || e.count != def.codec.local_bytes {return nil, .Incompatible}
		wire: [WORLD_EFFECT_BYTES]u8
		if err := def.codec.encode(def.codec.user, e.args[:e.count], wire[:def.codec.wire_bytes]);
		   err != .Ok {return nil, err}
		knet.write_u16(
			&writer,
			e.kind,
		); knet.write_u64(&writer, e.key); for b in wire[:def.codec.wire_bytes] {knet.write_u8(&writer, b)}
	}
	result, err := make(
		[]u8,
		len(knet.writer_bytes(&writer)),
		l.allocator,
	); if err != nil {return nil, .Allocation_Failed}; copy(result, knet.writer_bytes(&writer)); return result, .Ok
}

@(private)
world_wire_parts :: proc(l: ^Lane, f: ^World_Frame) -> (parts: [bd.Part][]u8, error: World_Error) {
	context.allocator=l.allocator
	n := l.world.network; success := false
	defer {if !success {for part in parts {delete(part)}}}
	for p in ([?]bd.Part{.Solver, .Side, .Observations}) {
		count, e := n.config.codec.encode(n.config.codec.user, f.image, p, nil)
		if e !=
		   .Ok {return parts, e}; if count < 0 || count > WORLD_NETWORK_BYTES {return parts, .Capacity}
		part, allocation_error := make(
			[]u8,
			count,
			l.allocator,
		); if allocation_error != nil {return parts, .Allocation_Failed}
		parts[p] = part
		_, e = n.config.codec.encode(
			n.config.codec.user,
			f.image,
			p,
			part,
		); if e != .Ok {return parts, e}
	}
	parts[.Game], error = world_wire_game(l, f); if error != .Ok {return parts, error}
	parts[.Occurrences], error = world_wire_occurrences(
		l,
		f,
	); if error != .Ok {return parts, error}
	total :=
		bd.SIGNATURE_BYTES; for part in parts {if len(part) > WORLD_NETWORK_BYTES - total {return parts, .Capacity}; total += len(part)}
	success = true; return parts, .Ok
}
// A complete export is an owning byte buffer; caller deletes it with the Lane
// allocator. It survives source Lane/provider/world destruction. No local image
// pointer or process schema fingerprint appears in the wire bytes.
lane_world_export :: proc(l: ^Lane, tick: u64) -> ([]u8, World_Error) {
	if l == nil || l.world == nil || l.world.network == nil {return nil, .Unsupported}
	context.allocator=l.allocator
	w :=
		l.world; n := w.network; if !l.ses.is_host {return nil, .Rejected}; if w.busy || w.presenting {return nil, .Busy}
	f := world_record(w, tick); if f == nil {return nil, .History_Missing}
	if e := w.provider.admit_detached(
		world_external_bytes(l) + WORLD_NETWORK_BYTES * 2,
		w.config.reservation_bytes,
	); e != .Ok {return nil, e}
	n.outbound_bytes +=
		WORLD_NETWORK_BYTES * 2; defer {n.outbound_bytes -= WORLD_NETWORK_BYTES * 2}
	parts, e := world_wire_parts(
		l,
		f,
	); if e != .Ok {return nil, e}; defer {for part in parts {delete(part)}}
	sig, se := bd.sign(
		{n.config.identity, n.epoch, tick, parts},
	); if se != .None {return nil, .Incompatible}
	recovery_count, re := n.config.codec.recovery_encode(n.config.codec.user, f.image, nil)
	if re !=
	   .Ok {return nil, re}; if recovery_count <= 0 || recovery_count > WORLD_NETWORK_BYTES {return nil, .Capacity}
	recovery, allocation_error := make(
		[]u8,
		recovery_count,
		l.allocator,
	); if allocation_error != nil {return nil, .Allocation_Failed}; defer delete(recovery, l.allocator)
	_, re = n.config.codec.recovery_encode(
		n.config.codec.user,
		f.image,
		recovery,
	); if re != .Ok {return nil, re}
	total :=
		bd.SIGNATURE_BYTES +
		4 +
		recovery_count; for part in parts {if len(part) > WORLD_NETWORK_BYTES - total {return nil, .Capacity}; total += len(part)}
	result, err := make([]u8, total, l.allocator); if err != nil {return nil, .Allocation_Failed}
	_, se = bd.signature_encode(
		sig,
		result[:bd.SIGNATURE_BYTES],
	); if se != .None {delete(result); return nil, .Invalid}
	for i in 0 ..< 4 {result[bd.SIGNATURE_BYTES + i] = u8(u32(recovery_count) >> uint(i * 8))}
	copy(result[bd.SIGNATURE_BYTES + 4:], recovery)
	at :=
		bd.SIGNATURE_BYTES +
		4 +
		recovery_count; for part in parts {copy(result[at:], part); at += len(part)}
	return result, .Ok
}
lane_world_send_checkpoint :: proc(
	l: ^Lane,
	to: ksess.Peer_Id,
	mode: World_Transfer_Mode,
) -> World_Error {
	if l == nil || l.world == nil || l.world.network == nil || !l.ses.is_host {return .Unsupported}
	n := l.world.network
	bootstrap:=mode==.Welcome || mode==.Reset
	if to==ksess.NO_PEER {return .Invalid}
	if n.sequence == max(u64) {return .Capacity}

	bytes, e := lane_world_export(
		l,
		l.world.head,
	); if e != .Ok {world_network_fail(l, e); return e}; defer delete(bytes, l.allocator)
	n.outbound_bytes += u64(len(bytes)); defer {n.outbound_bytes -= u64(len(bytes))}
	if n.protocol.full_states_sent==max(u64) {return .Capacity}
	n.sequence += 1
	// This records a generated expected ID, NOT a void-send success receipt.
	if bootstrap {world_protocol_expect_bootstrap(l,to,n.sequence)}
	digest := bd.hash_bytes(bytes); chunks := (len(bytes) + WORLD_NETWORK_CHUNK - 1) / WORLD_NETWORK_CHUNK
	for index in 0 ..< chunks {
		writer := ksess.session_app_begin(l.ses, l.tag); knet.write_u8(writer, SIM_WORLD_CHUNK)
		knet.write_u32(
			writer,
			WORLD_NETWORK_REV,
		); knet.write_u8(writer, u8(mode)); knet.write_u64(writer, n.sequence); knet.write_u64(writer, n.epoch); knet.write_u64(writer, l.world.head); knet.write_u32(writer, u32(len(bytes))); knet.write_u16(writer, u16(index)); knet.write_u16(writer, u16(chunks))
		for b in digest {knet.write_u8(writer, b)}
		for b in bytes[index * WORLD_NETWORK_CHUNK:min(len(bytes), (index + 1) * WORLD_NETWORK_CHUNK)] {knet.write_u8(writer, b)}
		ksess.session_app_flush(l.ses, to, .Reliable)
	}
	n.protocol.full_states_sent+=1
	return .Ok
}
@(private)
world_wire_decode :: proc(
	l: ^Lane,
	bytes: []u8,
) -> (
	cp: World_Checkpoint,
	baseline: World_Input_Row,
	values: []u8,
	signature: bd.Signature,
	error: World_Error,
) {
	w := l.world; n := w.network
	context.allocator=w.allocator
	// Retain actual detached data/code for adoption; on failure the live origin
	// still owns every callback and allocator used by cleanup.
	if e := world_owner_check(w.provider.owner, WORLD_OWNER_EXECUTE); e != .Ok {
		return cp, baseline, nil, signature, e
	}
	lifetime := w.provider.detached_owner
	if e := world_owner_retain(lifetime); e != .Ok {
		return cp, baseline, nil, signature, e
	}
	lifetime_transferred := false
	defer {if !lifetime_transferred {_ = world_owner_drop(lifetime)}}
	effect_lifetime:=w.provider.effect_owner
	if e:=world_owner_retain(effect_lifetime);e!=.Ok {return cp,baseline,nil,signature,e}
	effects_transferred:=false
	defer {if !effects_transferred {_=world_owner_drop(effect_lifetime)}}
	if len(bytes) < bd.SIGNATURE_BYTES ||
	   len(bytes) > WORLD_NETWORK_BYTES {return cp, baseline, nil, signature, .Invalid}
	sig, se := bd.signature_decode(
		bytes[:bd.SIGNATURE_BYTES],
	); if se != .None || sig.identity != n.config.identity {return cp, baseline, nil, signature, .Incompatible}
	parts, recovery, parse_error := world_wire_view(
		bytes,
		sig,
	); if parse_error != .Ok {return cp, baseline, nil, signature, parse_error}
	actual, ae := bd.sign(
		{sig.identity, sig.epoch, sig.tick, parts},
	); if ae != .None || bd.compare(sig, actual) != .Match {return cp, baseline, nil, signature, .Invalid}
	charge := u64(
		w.field_bytes + size_of(World_Checkpoint),
	); need := charge + u64(n.value_bytes * WORLD_REPAIR_TICKS)
	if need > WORLD_MEMORY_BYTES ||
	   world_external_bytes(l) >
		   WORLD_MEMORY_BYTES - need {return cp, baseline, nil, signature, .Budget}
	if e := w.provider.admit_detached(world_external_bytes(l) + need, w.config.reservation_bytes);
	   e != .Ok {return cp, baseline, nil, signature, e}
	n.outbound_bytes += need; defer {n.outbound_bytes -= need}
	fields, err := make(
		[]u8,
		w.field_bytes,
		w.allocator,
	); if err != nil {return cp, baseline, nil, signature, .Allocation_Failed}
	values, err = make(
		[]u8,
		n.value_bytes * WORLD_REPAIR_TICKS,
		w.allocator,
	); if err != nil {delete(fields); return cp, baseline, nil, signature, .Allocation_Failed}
	success :=
		false; defer {if !success {delete(fields); delete(values); if cp.image != nil {w.provider.release(cp.image)}; cp = {}}}
	r := knet.reader_make(
		parts[.Game],
	); count := int(knet.read_u32(&r)); if r.err || count != len(w.bindings) {return cp, baseline, values, signature, .Incompatible}
	for b in w.bindings {
		id := knet.read_net_id(
			&r,
		); length := int(knet.read_u32(&r)); if r.err || id != b.id {return cp, baseline, values, signature, .Incompatible}
		for field in n.config.codec.fields {if field.id == b.id {
				if length !=
				   field.codec.wire_bytes {return cp, baseline, values, signature, .Incompatible}
				wire := knet.reader_view(
					&r,
					length,
				); if r.err {return cp, baseline, values, signature, .Invalid}
				if e := field.codec.decode(
					field.codec.user,
					wire,
					fields[b.offset:b.offset + b.size],
				); e != .Ok {return cp, baseline, values, signature, e}
			}}
	}
	drivers := int(
		knet.read_u8(&r),
	); if drivers != len(n.drivers) {return cp, baseline, values, signature, .Incompatible}
	for d in n.drivers {player := knet.read_player_id(&r); class := knet.read_u16(&r); if r.err || player != d.player || class != d.class {return cp, baseline, values, signature, .Incompatible}}
	first := knet.read_u64(&r); window_count := int(knet.read_u8(&r))
	if r.err ||
	   window_count < 1 ||
	   window_count > WORLD_REPAIR_TICKS ||
	   first > max(u64) - u64(window_count - 1) ||
	   first + u64(window_count - 1) != sig.tick {return cp, baseline, values, signature, .Invalid}
	n.incoming_count = 0
	for j in 0 ..< window_count {
		row := World_Input_Row {
			tick  = first + u64(j),
			valid = true,
		}
		for d, i in n.drivers {
			origin := World_Input_Origin(knet.read_u8(&r)); sequence := knet.read_u64(&r)
			if r.err ||
			   origin == .Unknown ||
			   origin > .Authority ||
			   sequence > row.tick ||
			   (origin != .Held &&
					   sequence != row.tick) {return cp, baseline, values, signature, .Invalid}
			c := world_net_input_codec(
				n,
				d.class,
			); wire := knet.reader_view(&r, c.wire_bytes); if r.err {return cp, baseline, values, signature, .Invalid}
			if e := c.decode(
				c.user,
				wire,
				world_net_driver_bytes(n, values[j * n.value_bytes:(j + 1) * n.value_bytes], i),
			); e != .Ok {return cp, baseline, values, signature, e}
			row.origin[i] = origin; row.sequence[i] = sequence
		}
		n.incoming[j] = row; baseline = row
	}
	n.incoming_count = window_count
	if len(knet.reader_remaining(&r)) != 0 {return cp, baseline, values, signature, .Invalid}
	r = knet.reader_make(
		parts[.Occurrences],
	); cp.effects_known = true; cp.effect_count = int(knet.read_u8(&r)); if r.err || cp.effect_count > WORLD_EFFECTS_PER_TICK {return cp, baseline, values, signature, .Invalid}
	for &event, i in cp.effects[:cp.effect_count] {
		kind := knet.read_u16(
			&r,
		); key := knet.read_u64(&r); def := world_wire_effect(n, kind); if r.err || def == nil || key == 0 {return cp, baseline, values, signature, .Invalid}
		for prior in cp.effects[:i] {if prior.key == key {return cp, baseline, values, signature, .Conflict}}
		event = {
			kind  = kind,
			key   = key,
			fire  = def.fire,
			user  = def.user,
			count = def.codec.local_bytes,
		}; wire := knet.reader_view(&r, def.codec.wire_bytes)
		if r.err {return cp, baseline, values, signature, .Invalid}; if e := def.codec.decode(def.codec.user, wire, event.args[:event.count]); e != .Ok {return cp, baseline, values, signature, e}
	}
	if len(knet.reader_remaining(&r)) != 0 {return cp, baseline, values, signature, .Invalid}
	cp.image, error = n.config.codec.decode(
		n.config.codec.user,
		recovery,
		parts[.Side],
		parts[.Observations],
	); if error != .Ok {return cp, baseline, values, signature, error}
	// Logical diagnostic bytes are never imported. Independently reconstructed
	// native state must reproduce every signed logical solver byte before use.
	normalized_count, encode_error := n.config.codec.encode(
		n.config.codec.user,
		cp.image,
		.Solver,
		nil,
	)
	if encode_error != .Ok ||
	   normalized_count !=
		   len(parts[.Solver]) {return cp, baseline, values, signature, .Incompatible}
	if e := w.provider.admit_detached(
		world_external_bytes(l) + u64(normalized_count),
		w.config.reservation_bytes,
	); e != .Ok {return cp, baseline, values, signature, e}
	n.outbound_bytes += u64(normalized_count); defer {n.outbound_bytes -= u64(normalized_count)}
	comparison, comparison_error := make(
		[]u8,
		normalized_count,
		w.allocator,
	); if comparison_error != nil {return cp, baseline, values, signature, .Allocation_Failed}; defer delete(comparison, w.allocator)
	_, encode_error = n.config.codec.encode(n.config.codec.user, cp.image, .Solver, comparison)
	if encode_error != .Ok ||
	   mem.compare(comparison, parts[.Solver]) !=
		   0 {return cp, baseline, values, signature, .Incompatible}
	cp.tick =
		sig.tick; cp.asset_id = w.provider.asset_id; cp.field_schema = w.field_schema; cp.side_type = w.provider.side_type; cp.fields = fields; cp.clone = w.provider.clone; cp.release = w.provider.release; cp.equal = w.provider.equal; cp.allocator = w.allocator; cp.admit_detached = w.provider.admit_detached; cp.charge_bytes = charge; cp.reservation_bytes = w.config.reservation_bytes
	cp.owner = lifetime
	cp.effect_owner=effect_lifetime
	cp.budget=w.provider.budget
	g_world_checkpoint_bytes += charge; success = true; lifetime_transferred = true; effects_transferred=true; return cp, baseline, values, sig, .Ok
}

@(private)
world_wire_view :: proc(
	bytes: []u8,
	sig: bd.Signature,
) -> (
	parts: [bd.Part][]u8,
	recovery: []u8,
	error: World_Error,
) {
	if len(bytes) < bd.SIGNATURE_BYTES + 4 {return parts, nil, .Invalid}
	r := knet.reader_make(bytes[bd.SIGNATURE_BYTES:]); count := int(knet.read_u32(&r))
	if r.err || count <= 0 || count > WORLD_NETWORK_BYTES {return parts, nil, .Missing_Attachment}
	recovery = knet.reader_view(&r, count); if r.err {return parts, nil, .Invalid}
	for p in bd.Part {if sig.lengths[p] > u64(len(knet.reader_remaining(&r))) {return parts, nil, .Invalid}; parts[p] = knet.reader_view(&r, int(sig.lengths[p]))}
	if r.err || len(knet.reader_remaining(&r)) != 0 {return parts, nil, .Invalid}
	return parts, recovery, .Ok
}

// Same complete canonical five parts as full recovery, reusing the retained
// frame image. No provider.capture, clone or native world restore is added.
@(private)
world_protocol_frame_signature :: proc(l:^Lane,frame:^World_Frame)->(bd.Signature,World_Error) {
 n:=l.world.network
 if e:=l.world.provider.admit_detached(world_external_bytes(l)+WORLD_NETWORK_BYTES,l.world.config.reservation_bytes);e!=.Ok {return {},e}
 n.outbound_bytes+=WORLD_NETWORK_BYTES;defer {n.outbound_bytes-=WORLD_NETWORK_BYTES}
 parts,e:=world_wire_parts(l,frame);if e!=.Ok {return {},e};defer {for part in parts {delete(part,l.allocator)}}
 signature,se:=bd.sign({n.config.identity,n.epoch,frame.tick,parts})
 return signature,se==.None?.Ok:.Invalid
}
@(private)
world_protocol_send_signature :: proc(l:^Lane)->World_Error {
 n:=l.world.network
 if !l.ses.is_host {return .Rejected}
 if n.protocol.signatures_sent==max(u64) {return .Capacity}
 frame:=world_record(l.world,l.world.head);if frame==nil {return .History_Missing}
 signature,e:=world_protocol_frame_signature(l,frame);if e!=.Ok {return e}
 bytes:[bd.SIGNATURE_BYTES]u8;_,se:=bd.signature_encode(signature,bytes[:]);if se!=.None {return .Invalid}
 writer:=ksess.session_app_begin(l.ses,l.tag);knet.write_u8(writer,SIM_WORLD_SIGNATURE);knet.write_u32(writer,WORLD_NETWORK_REV)
 for b in bytes {knet.write_u8(writer,b)}
 ksess.session_app_flush(l.ses,ksess.BROADCAST_PEER,.Reliable);n.protocol.signatures_sent+=1
 return .Ok
}
