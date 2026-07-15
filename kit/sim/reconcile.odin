package kit_sim

// reconcile — compare the prediction to the truth; when they differ, rewind
// the world and replay it.
//
// This is kit/net's unwind → apply → replay generalized from per-entity
// discrete commands to per-tick world state. The shape of a client frame:
//
//   input_note(ring, tick, &in)      // sample intent for the tick
//   step the world one tick          // the game's tick procs, speculatively
//   note_all(entries, tick)          // ledger the prediction
//
// and when authoritative state for tick T arrives (T < the predicted head,
// because the client runs ahead):
//
//   n := reconcile(entries, truths, T, head, game, resim_step)
//
// THE COMMON CASE COSTS A MEMCMP. Every truth row is compared against the
// prediction ledgered AT that tick; all equal means the speculation was
// right, the ledger simply absorbs the truth, and NOTHING replays — at
// steady state a client resims zero ticks. On any mismatch the WHOLE
// predicted set rewinds to T (the world steps together — one wrong entity
// invalidates every later tick it could have touched) and the resim callback
// replays T+1..head, feeding each tick its ledgered input back.
//
// Resim rules the callback must honor (the tick-proc contract, enforced by
// discipline now and scriptgen later):
//
//   * a resim tick reads inputs from the ring (input_read), never the device;
//   * tick procs touch predicted fields + ctx queries only — no clocks, no
//     node state, no un-ledgered randomness (ksim RNG seeds by (tick, id));
//   * presentation NEVER runs during resim — the sim state snaps, the render
//     error smooths out over frames (the puppet layer's job, phase 3).
//
// Entities without a truth row in this batch (interest filtering, partial
// snapshots) rewind to their OWN ledgered prediction at T — the replay must
// start from a coherent world, not a mix of tick-T and tick-head state. An
// entity whose ledger no longer holds T (spawned mid-window, ring lapped)
// counts as mismatched when named by truth, and replays from live state when
// not — approximate, and self-healing at the next snapshot that names it.

import knet "godot:kit/net"

// One predicted entity under reconcile. The session glue will derive these
// from the registry; tests build them by hand. `hist` is the client's OWN
// prediction ledger for the entity (one History per predicted entity).
Entry :: struct {
	id:     knet.Net_Id,
	entity: rawptr,
	hist:   ^History,
	// The tick this entity was BORN (0 = existed from the start). A predicted
	// spawn (a projectile fired mid-window) has no state before `born`, so the
	// ledger, the rewind, and the resim must treat ticks < born as "not yet
	// existing" — otherwise a reconcile landing before the spawn (which happens
	// for the whole first round trip of the entity's life, the server running a
	// transit behind) re-flies it from stale head state. See run_tick/note_all.
	born:   u64,
}

// Authoritative predict-set state for one entity at the batch's tick —
// struct-layout bytes (the wire decode happens at the packet edge, phase 2).
Truth :: struct {
	id:   knet.Net_Id,
	blob: []u8,
}

// Step the whole predicted world one tick forward — the same proc the live
// frame uses, re-entered for replay. Reads its inputs from the ring.
Resim_Proc :: proc(user: rawptr, tick: u64)

// Ledger every entry's live predict set as the state AT `tick`. Call after
// stepping each predicted tick — live frames and replays alike.
note_all :: proc(entries: []Entry, tick: u64) {
	for &e in entries {
		if e.born != 0 && tick < e.born {
			continue // not born yet — no state to ledger before the spawn tick
		}
		history_note(e.hist, tick, e.entity)
	}
}

// Reconcile authoritative tick `auth_tick` against the prediction ledger.
// `head_tick` is the client's predicted head (the ticker's tick). Returns
// how many ticks were resimmed (0 = every truth matched, or nothing to do).
// `mismatched` (optional) collects the ids whose predictions were wrong —
// diagnostics and the phase-3 smoothing hook ride on it.
reconcile :: proc(
	entries: []Entry,
	truths: []Truth,
	auth_tick: u64,
	head_tick: u64,
	user: rawptr,
	resim: Resim_Proc,
	mismatched: ^[dynamic]knet.Net_Id = nil,
	eps: f32 = 0, // tolerant float compare (predict-world's anti-churn; 0 = exact)
) -> int {
	if auth_tick == 0 || len(truths) == 0 {
		return 0
	}

	// Pass 1: compare every truth against the ledger. No state is touched —
	// the clean path must cost nothing but the memcmps.
	wrong := 0
	for t in truths {
		e := find_entry(entries, t.id)
		if e == nil {
			continue // not under reconcile here (unknown / not predicted)
		}
		assert(len(t.blob) == e.hist.size, "truth blob must be the entity's predict-set size")
		if !history_within(e.hist, auth_tick, t.blob, eps) {
			wrong += 1
			if mismatched != nil {
				append(mismatched, t.id)
			}
		}
	}

	if wrong == 0 {
		// Right everywhere: absorb the truth into the ledger (it is equal
		// bytes, but the slot stamp may be fresher knowledge than a lapped
		// hole) and keep the speculation.
		for t in truths {
			if e := find_entry(entries, t.id); e != nil {
				history_note_bytes(e.hist, auth_tick, t.blob)
			}
		}
		return 0
	}

	// Pass 2: rewind the world to auth_tick. Truth-named entities take the
	// truth; the rest take their own ledgered prediction (a coherent tick-T
	// world, not a mix of T and head).
	for t in truths {
		if e := find_entry(entries, t.id); e != nil {
			predict_restore(e.entity, e.hist.desc, t.blob)
			history_note_bytes(e.hist, auth_tick, t.blob)
		}
	}
	for &e in entries {
		if find_truth(truths, e.id) == nil {
			_ = history_restore(e.hist, auth_tick, e.entity) // miss = replay from live, see header
		}
	}

	// Pass 3: replay. The callback steps the same tick procs the live frame
	// runs; the ledger re-notes each tick so the NEXT authoritative batch
	// compares against this corrected timeline.
	resimmed := 0
	for t := auth_tick + 1; t <= head_tick; t += 1 {
		resim(user, t)
		note_all(entries, t)
		resimmed += 1
	}
	return resimmed
}

@(private = "file")
find_entry :: proc(entries: []Entry, id: knet.Net_Id) -> ^Entry {
	for &e in entries {
		if e.id == id {
			return &e
		}
	}
	return nil
}

@(private = "file")
find_truth :: proc(truths: []Truth, id: knet.Net_Id) -> ^Truth {
	for &t in truths {
		if t.id == id {
			return &t
		}
	}
	return nil
}
