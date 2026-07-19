package kit_sim

// history — the predict-subset serialization and the tick-indexed state ring.
//
// The predict subset mirrors kit/net/stream.odin's Owner_Stream subset: the
// .Predicted fields of an Entity_Desc, struct-layout, tightly packed in desc
// order. One more consumer of the one-serialization-many-masters descriptor.
//
// History is play.Trail generalized: where Trail hand-notes a [2]f32, History
// notes the whole predict set, descriptor-driven. Same ledger contract — each
// slot stores the tick that wrote it, so an unwritten or lapped slot reads
// ok=false instead of a sentinel; a caller finding no history decides what to
// do BY CHOICE, never by accident. Three masters share it:
//
//   client   a ring of its own predicted states, compared against arriving
//            authoritative ticks (reconcile.odin) — equal means skip resim
//   server   a ring of authoritative truth, the lag-compensation ledger
//            (rewind a hit test to what the shooter rendered) and the delta
//            baseline store for snapshot compression (snapshot.odin)
//   both     history is DERIVED state; it must never replicate.

import "core:mem"
import knet "godot:kit/net"

// ---------------------------------------------------------------------------
// The predict subset: .Predicted fields only, struct layout, desc order.

// Byte size of one predict-set snapshot. 0 = this entity type predicts nothing.
predict_size :: proc(desc: ^knet.Entity_Desc) -> int {
	return knet.subset_view(desc, .Predicted).struct_bytes
}

// Entity → blob (caller sizes dst with predict_size).
predict_capture :: proc(dst: []u8, entity: rawptr, desc: ^knet.Entity_Desc) {
	knet.subset_capture(knet.subset_view(desc, .Predicted), entity, dst)
}

// Blob → entity. The restore half of a reconcile: authoritative truth (or a
// stored prediction) lands on exactly the predicted fields, nothing else —
// delta-lane and owner-stream fields are never touched from here.
predict_restore :: proc(entity: rawptr, desc: ^knet.Entity_Desc, src: []u8) {
	knet.subset_restore(knet.subset_view(desc, .Predicted), entity, src)
}

// Does the entity's live predict set equal `blob`? The clean-skip test: equal
// means the prediction was right and nothing replays. Raw byte compare — the
// same memcmp discipline as the delta walk (POD fields, nothing follows
// pointers).
predict_matches :: proc(entity: rawptr, desc: ^knet.Entity_Desc, blob: []u8) -> bool {
	return knet.subset_equal(knet.subset_view(desc, .Predicted), entity, blob)
}

// ---------------------------------------------------------------------------
// History — the tick-indexed ring of predict-set snapshots.

History :: struct {
	desc:            ^knet.Entity_Desc,
	has_slack:       bool, // any predicted field carries a per-field slack (cached at make —
	                       // keeps the exact-compare fast path a single memcmp, no field walk)
	using ring:      Tick_Ring, // the tick-indexed store (slot .size = predict_size(desc), cached);
	                            // promoted so callers read hist.size / .slots as before
}

// `slots` is the window in TICKS the ledger holds — size it from what reads
// it: a client ring must cover its maximum lead (input RTT worth of ticks), a
// server lag-comp ring covers the rewind bound (~250ms of ticks).
history_make :: proc(desc: ^knet.Entity_Desc, slots: int, allocator := context.allocator) -> History {
	has_slack := false
	for f in desc.fields {
		if .Predicted in f.flags && f.slack > 0 {
			has_slack = true
			break
		}
	}
	return History {
		desc      = desc,
		has_slack = has_slack,
		ring      = tick_ring_make(predict_size(desc), slots, allocator),
	}
}

history_destroy :: proc(h: ^History) {
	tick_ring_destroy(&h.ring)
}

// Note the entity's live predict set as the state AT `tick` — the owner of
// the truth (server) or of the prediction (client), once per simulated tick.
history_note :: proc(h: ^History, tick: u64, entity: rawptr) {
	predict_capture(tick_ring_dst(&h.ring, tick), entity, h.desc)
}

// Note an already-captured blob as the state AT `tick` — how arriving
// authoritative truth replaces a wrong prediction in the ledger, so later
// rewinds and compares read truth, not the superseded guess.
history_note_bytes :: proc(h: ^History, tick: u64, blob: []u8) {
	tick_ring_note(&h.ring, tick, blob)
}

// The snapshot AT `tick`, if the ledger still holds it (a view into the ring —
// valid until that slot is re-noted). ok=false per THE LEDGER CONTRACT (ring.odin).
history_read :: proc(h: ^History, tick: u64) -> (blob: []u8, ok: bool) {
	return tick_ring_read(&h.ring, tick)
}

// Restore the entity's predict set to its state AT `tick`. false = the ledger
// no longer holds that tick (nothing written; the caller chooses the fallback).
history_restore :: proc(h: ^History, tick: u64, entity: rawptr) -> bool {
	blob, ok := history_read(h, tick)
	if !ok {
		return false
	}
	predict_restore(entity, h.desc, blob)
	return true
}

// Stored@tick == blob? false when the tick is missing — a compare against
// history the client no longer holds must read as a mismatch (resim from
// truth), never as silently fine.
history_matches :: proc(h: ^History, tick: u64, blob: []u8) -> bool {
	stored, ok := history_read(h, tick)
	if !ok {
		return false
	}
	return mem.compare(stored, blob) == 0
}

// The TOLERANT compare: float fields (Lerp_Kind .F32/.F64 — scriptgen
// classifies predict fields' float-ness even without interp) match within
// `eps` per component; everything else matches EXACTLY — a differing flag
// byte is a real event, only continuous drift earns slack. This is what
// keeps predict-world from resimming on every batch of held-input noise:
// sub-epsilon drift rides until it accumulates past the line, then one
// normal reconcile absorbs it.
// `eps` is the lane default tolerance; a field's own Field_Desc.slack (> 0)
// overrides it for that field — so a fast contested object rides loose drift
// while precise fields in the same lane stay tight. slack is meaningful only
// on float (.F32/.F64) fields; discrete predicted state always compares exact
// (a differing byte is a real event), whatever the tolerances say.
predict_within :: proc(a: []u8, b: []u8, desc: ^knet.Entity_Desc, eps: f32) -> bool {
	off := 0
	for f in desc.fields {
		if .Predicted not_in f.flags {
			continue
		}
		defer off += f.size
		fe := f.slack > 0 ? f.slack : eps // per-field slack overrides the lane default
		#partial switch f.lerp {
		case .F32:
			for i in 0 ..< f.size / 4 {
				av := (^f32)(rawptr(&a[off + i * 4]))^
				bv := (^f32)(rawptr(&b[off + i * 4]))^
				if abs(av - bv) > fe {
					return false
				}
			}
		case .Angle:
			for i in 0 ..< f.size / 4 {
				// wrapped compare: 3.14 vs -3.14 is a sliver, not a mismatch
				if abs(knet.angle_arc((^f32)(rawptr(&a[off + i * 4]))^, (^f32)(rawptr(&b[off + i * 4]))^)) > fe {
					return false
				}
			}
		case .F64:
			for i in 0 ..< f.size / 8 {
				av := (^f64)(rawptr(&a[off + i * 8]))^
				bv := (^f64)(rawptr(&b[off + i * 8]))^
				if abs(av - bv) > f64(fe) {
					return false
				}
			}
		case:
			if mem.compare(a[off:off + f.size], b[off:off + f.size]) != 0 {
				return false
			}
		}
	}
	return true
}

// history_matches with the tolerant compare. The exact fast path (one memcmp,
// no field walk) holds only when NOTHING wants slack — neither the lane
// default nor any per-field override; otherwise the per-field compare runs.
history_within :: proc(h: ^History, tick: u64, blob: []u8, eps: f32) -> bool {
	if eps <= 0 && !h.has_slack {
		return history_matches(h, tick, blob)
	}
	stored, ok := history_read(h, tick)
	if !ok {
		return false
	}
	return predict_within(stored, blob, h.desc, eps)
}

// Lag-compensation rewind lives in lane.odin (lane_rewound_begin/end): it
// winds EVERY watched entity to the bracket pair and alpha the shooter's
// screen actually drew — the single-tick per-entity begin/end pair that once
// sat here predated the blend and survived only in tests, a stale rung a
// game could mistake for the real mechanism.
