package kit_sim_test

// Standalone tests for kit/sim — the server-authority resim companion's
// engine-free core. No Godot runtime.
//
//   odin test tests/kitsim -collection:godot=$PWD
//
// The Mover struct + hand-built Entity_Desc stand in for what scriptgen's
// gd:"replicate,predict" will generate in a later phase — like kit/net, the
// core must be fully exercisable without codegen. The mini-sim here is the
// documentation of the tick-proc contract in executable form: a pure step of
// (predicted fields, input), deterministic under replay.

import "core:testing"
import knet "godot:kit/net"
import ksim "godot:kit/sim"

// ---- fixtures ---------------------------------------------------------------

// One predicted entity: x/vx ride the sim lane, hp stays on the delta lane,
// aim is owner-streamed, local_only is off-wire entirely — the subset procs
// must touch exactly the first two and nothing else.
Mover :: struct {
	x, vx:      f32, // predicted
	hp:         i32, // host delta lane
	aim:        f32, // owner stream lane
	local_only: int,
}

mover_desc :: proc() -> knet.Entity_Desc {
	@(static) fields := [?]knet.Field_Desc{
		{offset = offset_of(Mover, x), size = size_of(f32), flags = {.Predicted, .Interp}, lerp = .F32},
		{offset = offset_of(Mover, vx), size = size_of(f32), flags = {.Predicted}},
		{offset = offset_of(Mover, hp), size = size_of(i32)},
		{offset = offset_of(Mover, aim), size = size_of(f32), flags = {.Owner_Stream}},
	}
	return knet.Entity_Desc{fields = fields[:]}
}

// The tick step: one input, fixed dt implicit. Deliberately integer-valued
// f32 math so replayed trajectories compare exactly.
mover_step :: proc(m: ^Mover, ax: i8) {
	m.vx += f32(ax)
	m.x += m.vx
}

// ---- predict subset ----------------------------------------------------------

@(test)
predict_subset_roundtrip :: proc(t: ^testing.T) {
	desc := mover_desc()
	testing.expect_value(t, ksim.predict_size(&desc), 8)

	m := Mover{x = 3, vx = 1, hp = 100, aim = 0.5, local_only = 7}
	snap := make([]u8, ksim.predict_size(&desc))
	defer delete(snap)
	ksim.predict_capture(snap, &m, &desc)
	testing.expect(t, ksim.predict_matches(&m, &desc, snap), "fresh capture matches")

	m.x = 99
	m.vx = -4
	m.hp = 55   // non-predicted churn must not affect subset compare/restore
	m.aim = 2.5
	testing.expect(t, !ksim.predict_matches(&m, &desc, snap), "moved entity mismatches")

	ksim.predict_restore(&m, &desc, snap)
	testing.expect_value(t, m.x, 3)
	testing.expect_value(t, m.vx, 1)
	testing.expect_value(t, m.hp, 55)      // untouched by restore
	testing.expect_value(t, m.aim, 2.5)    // untouched by restore
	testing.expect_value(t, m.local_only, 7)
	testing.expect(t, ksim.predict_matches(&m, &desc, snap), "restored entity matches")
}

// The kit/net side of the lane split: a predicted field never dirties the
// host delta walk, exactly like an owner-streamed one.
@(test)
predicted_fields_skip_delta_walk :: proc(t: ^testing.T) {
	desc := mover_desc()
	m := Mover{x = 1, vx = 1, hp = 100, aim = 1}
	shadow := knet.shadow_make(&desc)
	defer delete(shadow)
	knet.shadow_capture(&m, shadow, &desc)

	m.x = 50 // predicted: excluded from the diff
	m.aim = 9 // owner stream: excluded from the diff
	testing.expect_value(t, knet.diff_mask(&m, shadow, &desc), 0)

	m.hp = 99 // delta lane: field index 2
	testing.expect_value(t, knet.diff_mask(&m, shadow, &desc), u64(1) << 2)
}

// ---- history ------------------------------------------------------------------

@(test)
history_ledger_contract :: proc(t: ^testing.T) {
	desc := mover_desc()
	h := ksim.history_make(&desc, 4)
	defer ksim.history_destroy(&h)

	m := Mover{}
	for tick in u64(1) ..= 6 {
		m.x = f32(tick * 10)
		ksim.history_note(&h, tick, &m)
	}

	_, ok := ksim.history_read(&h, 2)
	testing.expect(t, !ok, "tick 2 lapped by tick 6 in a 4-slot ring")
	_, ok = ksim.history_read(&h, 0)
	testing.expect(t, !ok, "tick 0 predates any note")
	_, ok = ksim.history_read(&h, 7)
	testing.expect(t, !ok, "the future is unwritten")

	blob, ok6 := ksim.history_read(&h, 6)
	testing.expect(t, ok6, "newest tick held")
	testing.expect(t, ksim.history_matches(&h, 6, blob), "self-compare")

	m.x = -1
	testing.expect(t, ksim.history_restore(&h, 5, &m), "tick 5 still held")
	testing.expect_value(t, m.x, 50)
	testing.expect(t, !ksim.history_restore(&h, 2, &m), "lapped restore refuses")
	testing.expect_value(t, m.x, 50) // and leaves the entity alone
}

@(test)
history_rewind_pair :: proc(t: ^testing.T) {
	desc := mover_desc()
	h := ksim.history_make(&desc, 8)
	defer ksim.history_destroy(&h)

	m := Mover{x = 10, vx = 2, hp = 77}
	ksim.history_note(&h, 5, &m)
	m.x = 100
	m.vx = 9

	live, ok := ksim.history_rewind_begin(&h, 5, &m)
	testing.expect(t, ok, "tick 5 held")
	testing.expect_value(t, m.x, 10) // the hit test sees the past
	testing.expect_value(t, m.vx, 2)
	testing.expect_value(t, m.hp, 77) // non-predicted state never rewinds
	ksim.history_rewind_end(&h, &m, live)
	testing.expect_value(t, m.x, 100) // the present returns
	testing.expect_value(t, m.vx, 9)

	_, ok = ksim.history_rewind_begin(&h, 3, &m)
	testing.expect(t, !ok, "a tick the ledger lost refuses to rewind — test live, by choice")
}

// ---- input pipeline -------------------------------------------------------------

@(test)
input_redundant_window :: proc(t: ^testing.T) {
	ring := ksim.input_ring_make(1, 16)
	defer ksim.input_ring_destroy(&ring)
	for tick in u64(1) ..= 5 {
		ax := i8(tick)
		ksim.input_note(&ring, tick, &ax)
	}

	// Nothing acked: the window is everything within redundancy.
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	testing.expect_value(t, ksim.input_write(&w, &ring, acked = 0), 5)

	buf := ksim.input_buffer_make(1, 16)
	defer ksim.input_buffer_destroy(&buf)
	r := knet.reader_make(knet.writer_bytes(&w))
	testing.expect_value(t, ksim.input_buffer_apply(&buf, &r), 5)
	testing.expect(t, !r.err, "well-formed packet")
	testing.expect_value(t, buf.newest, 5)

	// Redundant re-delivery of the same packet: zero fresh, zero fuss.
	r = knet.reader_make(knet.writer_bytes(&w))
	testing.expect_value(t, ksim.input_buffer_apply(&buf, &r), 0)

	// Acked window: only the unacked tail ships.
	knet.writer_reset(&w)
	testing.expect_value(t, ksim.input_write(&w, &ring, acked = 3), 2)

	// The server consumes in order, fresh throughout.
	for tick in u64(1) ..= 5 {
		in_bytes, fresh := ksim.input_buffer_pop(&buf, tick)
		testing.expect(t, fresh, "buffered tick pops fresh")
		testing.expect_value(t, transmute(i8)in_bytes[0], i8(tick))
	}
}

@(test)
input_gap_holds_last :: proc(t: ^testing.T) {
	ring := ksim.input_ring_make(1, 16)
	defer ksim.input_ring_destroy(&ring)
	buf := ksim.input_buffer_make(1, 16)
	defer ksim.input_buffer_destroy(&buf)
	w := knet.writer_make()
	defer knet.writer_destroy(&w)

	// Before anything arrives, a pop coasts on the neutral (zeroed) input.
	in_bytes, fresh := ksim.input_buffer_pop(&buf, 1)
	testing.expect(t, !fresh, "nothing arrived yet")
	testing.expect_value(t, in_bytes[0], 0)

	// Ticks 2 and 3 arrive; 4 is lost in a gap; 5 arrives.
	for tick in u64(2) ..= 3 {
		ax := i8(7)
		ksim.input_note(&ring, tick, &ax)
	}
	ksim.input_write(&w, &ring, acked = 1)
	r := knet.reader_make(knet.writer_bytes(&w))
	ksim.input_buffer_apply(&buf, &r)

	_, fresh = ksim.input_buffer_pop(&buf, 2)
	testing.expect(t, fresh)
	_, fresh = ksim.input_buffer_pop(&buf, 3)
	testing.expect(t, fresh)

	in_bytes, fresh = ksim.input_buffer_pop(&buf, 4)
	testing.expect(t, !fresh, "gap tick")
	testing.expect_value(t, transmute(i8)in_bytes[0], 7) // hold-last repeats tick 3
	testing.expect_value(t, buf.held_count, 2)

	// Tick 4's input arriving AFTER tick 4 simulated is stale: dropped.
	ax := i8(9)
	ksim.input_note(&ring, 4, &ax)
	knet.writer_reset(&w)
	ksim.input_write(&w, &ring, acked = 3)
	r = knet.reader_make(knet.writer_bytes(&w))
	testing.expect_value(t, ksim.input_buffer_apply(&buf, &r), 0)
}

@(test)
input_malformed_is_safe :: proc(t: ^testing.T) {
	ring := ksim.input_ring_make(2, 8) // sender claims 2-byte inputs
	defer ksim.input_ring_destroy(&ring)
	in2 := [2]u8{1, 2}
	ksim.input_note(&ring, 1, &in2)
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	ksim.input_write(&w, &ring, acked = 0)

	buf := ksim.input_buffer_make(1, 8) // receiver expects 1-byte inputs
	defer ksim.input_buffer_destroy(&buf)
	r := knet.reader_make(knet.writer_bytes(&w))
	testing.expect_value(t, ksim.input_buffer_apply(&buf, &r), 0)
	testing.expect(t, r.err, "size mismatch is a malformed packet, not a buffer write")

	// Truncated mid-blob: sticky err, partial fresh only.
	full := knet.writer_bytes(&w)
	r = knet.reader_make(full[:len(full) - 1])
	buf2 := ksim.input_buffer_make(2, 8)
	defer ksim.input_buffer_destroy(&buf2)
	testing.expect_value(t, ksim.input_buffer_apply(&buf2, &r), 0)
	testing.expect(t, r.err, "truncation sets the sticky error")
}

@(test)
input_margin_tracks_headroom :: proc(t: ^testing.T) {
	ring := ksim.input_ring_make(1, 16)
	defer ksim.input_ring_destroy(&ring)
	buf := ksim.input_buffer_make(1, 16)
	defer ksim.input_buffer_destroy(&buf)
	w := knet.writer_make()
	defer knet.writer_destroy(&w)

	for tick in u64(1) ..= 3 {
		ax := i8(1)
		ksim.input_note(&ring, tick, &ax)
	}
	ksim.input_write(&w, &ring, acked = 0)
	r := knet.reader_make(knet.writer_bytes(&w))
	ksim.input_buffer_apply(&buf, &r)
	// Nothing consumed yet: newest=3 vs next-consumed=1 → 2 ticks of headroom.
	testing.expect_value(t, buf.margin, 2)
}

// ---- ticker + lead ---------------------------------------------------------------

@(test)
sim_ticker_paces_and_caps :: proc(t: ^testing.T) {
	tk := ksim.sim_ticker_make(60)
	testing.expect_value(t, ksim.sim_ticker_advance(&tk, 1.0 / 60.0), 1)
	testing.expect_value(t, ksim.sim_ticker_advance(&tk, 1.0 / 240.0), 0)

	// A one-second stall owes 60 ticks; the cap fast-forwards 32 and drops
	// the rest instead of replaying a dead gap.
	stalled := ksim.sim_ticker_make(60)
	testing.expect_value(t, ksim.sim_ticker_advance(&stalled, 1.0), ksim.MAX_CATCHUP_TICKS)
	testing.expect_value(t, stalled.acc, 0)
}

@(test)
sim_ticker_scale_bends_time :: proc(t: ^testing.T) {
	tk := ksim.sim_ticker_make(60)
	tk.scale = 1.0 + ksim.SCALE_NUDGE_MAX
	total := 0
	for _ in 0 ..< 100 {
		total += ksim.sim_ticker_advance(&tk, 1.0 / 60.0)
	}
	// 100 frames at +2% ≈ 102 ticks — the client gains ~2 ticks of lead.
	testing.expect(t, total >= 101 && total <= 103, "2% nudge gains ~2 ticks per 100")
}

@(test)
lead_targets_and_control :: proc(t: ^testing.T) {
	clock := knet.Clock_Sync{rtt = 0.1, jitter = 0.01, initialized = true}
	dt := 1.0 / 60.0
	// 50ms one-way + 20ms jitter allowance = 70ms → 5 ticks, +1 slack.
	testing.expect_value(t, ksim.lead_target(&clock, dt), 6)
	// More jitter demands more lead; never below 1 + slack.
	clock.jitter = 0.05
	testing.expect(t, ksim.lead_target(&clock, dt) > 6, "jitter widens the lead")
	calm := knet.Clock_Sync{initialized = true}
	testing.expect_value(t, ksim.lead_target(&calm, dt), 2)

	tk := ksim.sim_ticker_make(60)
	ksim.lead_control(&tk, 2)   // behind: full speed-up
	testing.expect_value(t, tk.scale, 1.0 + ksim.SCALE_NUDGE_MAX)
	ksim.lead_control(&tk, -2)  // pooling: full slow-down
	testing.expect_value(t, tk.scale, 1.0 - ksim.SCALE_NUDGE_MAX)
	ksim.lead_control(&tk, 1)   // inside the taper: proportional
	testing.expect_value(t, tk.scale, 1.0 + ksim.SCALE_NUDGE_MAX / 2)
	ksim.lead_control(&tk, 0)   // converged: the clock runs true
	testing.expect_value(t, tk.scale, 1.0)
}

// ---- reconcile --------------------------------------------------------------------

// The client's world for the resim callback: the mover, its input ring, and
// the call count the tests assert on.
Test_World :: struct {
	mover: ^Mover,
	ring:  ^ksim.Input_Ring,
	calls: int,
}

world_resim :: proc(user: rawptr, tick: u64) {
	w := cast(^Test_World)user
	w.calls += 1
	ax: i8
	if in_bytes, ok := ksim.input_read(w.ring, tick); ok {
		ax = transmute(i8)in_bytes[0]
	}
	mover_step(w.mover, ax)
}

// Drive a client 10 predicted ticks (ax=1 each), ledgering as it goes — the
// canonical frame loop, shared by both reconcile tests.
predict_ten :: proc(m: ^Mover, ring: ^ksim.Input_Ring, h: ^ksim.History, entries: []ksim.Entry) {
	for tick in u64(1) ..= 10 {
		ax := i8(1)
		ksim.input_note(ring, tick, &ax)
		mover_step(m, ax)
		ksim.note_all(entries, tick)
	}
}

@(test)
reconcile_clean_skips_resim :: proc(t: ^testing.T) {
	desc := mover_desc()
	m := Mover{}
	ring := ksim.input_ring_make(1, 32)
	defer ksim.input_ring_destroy(&ring)
	h := ksim.history_make(&desc, 32)
	defer ksim.history_destroy(&h)
	entries := []ksim.Entry{{id = 1, entity = &m, hist = &h}}
	predict_ten(&m, &ring, &h, entries)
	testing.expect_value(t, m.x, 55) // sum 1..10 — the speculative head

	// The server agreed at tick 4: its truth is exactly what we ledgered.
	truth_blob, ok := ksim.history_read(&h, 4)
	testing.expect(t, ok)
	truth := make([]u8, len(truth_blob))
	defer delete(truth)
	copy(truth, truth_blob)

	world := Test_World{mover = &m, ring = &ring}
	truths := []ksim.Truth{{id = 1, blob = truth}}
	resimmed := ksim.reconcile(entries, truths, 4, 10, &world, world_resim)
	testing.expect_value(t, resimmed, 0)
	testing.expect_value(t, world.calls, 0) // the common case costs a memcmp
	testing.expect_value(t, m.x, 55)        // and the speculation stands
}

@(test)
reconcile_mismatch_replays :: proc(t: ^testing.T) {
	desc := mover_desc()
	m := Mover{hp = 88}
	ring := ksim.input_ring_make(1, 32)
	defer ksim.input_ring_destroy(&ring)
	h := ksim.history_make(&desc, 32)
	defer ksim.history_destroy(&h)
	entries := []ksim.Entry{{id = 1, entity = &m, hist = &h}}
	predict_ten(&m, &ring, &h, entries)

	// The server disagreed: a lost input meant it held ax=0 at tick 3, so its
	// tick-4 truth is x=8, vx=3 (vs the client's predicted x=10, vx=4).
	server := Mover{}
	server_ax := [4]i8{1, 1, 0, 1}
	for tick in 0 ..< 4 {
		mover_step(&server, server_ax[tick])
	}
	truth := make([]u8, ksim.predict_size(&desc))
	defer delete(truth)
	ksim.predict_capture(truth, &server, &desc)

	world := Test_World{mover = &m, ring = &ring}
	mismatched := make([dynamic]knet.Net_Id)
	defer delete(mismatched)
	truths := []ksim.Truth{{id = 1, blob = truth}}
	resimmed := ksim.reconcile(entries, truths, 4, 10, &world, world_resim, &mismatched)

	testing.expect_value(t, resimmed, 6) // ticks 5..10 replayed
	testing.expect_value(t, world.calls, 6)
	testing.expect_value(t, len(mismatched), 1)

	// Truth@4 {x=8,vx=3} + the ledgered inputs (ax=1 for 5..10): vx climbs
	// 4..9, x = 8+4+5+6+7+8+9 = 47 — the corrected timeline, exactly.
	testing.expect_value(t, m.x, 47)
	testing.expect_value(t, m.vx, 9)
	testing.expect_value(t, m.hp, 88) // the delta lane never resims

	// The ledger now records the corrected timeline: a repeat of the same
	// truth is clean and replays nothing.
	world.calls = 0
	testing.expect_value(t, ksim.reconcile(entries, truths, 4, 10, &world, world_resim), 0)
	testing.expect_value(t, world.calls, 0)
	testing.expect_value(t, m.x, 47)
}

@(test)
reconcile_ignores_unknown_ids :: proc(t: ^testing.T) {
	desc := mover_desc()
	m := Mover{}
	ring := ksim.input_ring_make(1, 32)
	defer ksim.input_ring_destroy(&ring)
	h := ksim.history_make(&desc, 32)
	defer ksim.history_destroy(&h)
	entries := []ksim.Entry{{id = 1, entity = &m, hist = &h}}
	predict_ten(&m, &ring, &h, entries)

	bogus := make([]u8, 8)
	defer delete(bogus)
	world := Test_World{mover = &m, ring = &ring}
	truths := []ksim.Truth{{id = 42, blob = bogus}} // nobody here by that id
	testing.expect_value(t, ksim.reconcile(entries, truths, 4, 10, &world, world_resim), 0)
	testing.expect_value(t, m.x, 55)
}
