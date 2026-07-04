package kit_net_test

// Standalone tests for kit/net — the pure replication core. No Godot runtime.
//
//   odin test tests/kitnet -collection:godot=$PWD
//
// The Probe struct + hand-built Entity_Desc stand in for what scriptgen's
// gd:"replicate" will generate later in phase 0 — the core must be fully
// exercisable without codegen.

import "core:testing"
import knet "godot:kit/net"

// ---- wire ------------------------------------------------------------------

@(test)
wire_roundtrip :: proc(t: ^testing.T) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, 0xAB)
	knet.write_bool(&w, true)
	knet.write_u16(&w, 0xBEEF)
	knet.write_u32(&w, 0xDEADBEEF)
	knet.write_u64(&w, 0x0123456789ABCDEF)
	knet.write_i32(&w, -42)
	knet.write_f32(&w, 3.5)
	knet.write_f64(&w, -0.25)
	knet.write_string(&w, "chest_open")
	knet.write_bytes(&w, []u8{1, 2, 3})
	knet.write_net_id(&w, knet.Net_Id(77))
	knet.write_player_id(&w, knet.Player_Id(0xFFFF_FFFF_0000_0001))

	r := knet.reader_make(knet.writer_bytes(&w))
	testing.expect_value(t, knet.read_u8(&r), 0xAB)
	testing.expect_value(t, knet.read_bool(&r), true)
	testing.expect_value(t, knet.read_u16(&r), 0xBEEF)
	testing.expect_value(t, knet.read_u32(&r), 0xDEADBEEF)
	testing.expect_value(t, knet.read_u64(&r), 0x0123456789ABCDEF)
	testing.expect_value(t, knet.read_i32(&r), -42)
	testing.expect_value(t, knet.read_f32(&r), 3.5)
	testing.expect_value(t, knet.read_f64(&r), -0.25)
	testing.expect_value(t, knet.read_string(&r), "chest_open")
	b := knet.read_bytes(&r)
	testing.expect_value(t, len(b), 3)
	testing.expect_value(t, knet.read_net_id(&r), knet.Net_Id(77))
	testing.expect_value(t, knet.read_player_id(&r), knet.Player_Id(0xFFFF_FFFF_0000_0001))
	testing.expect(t, !r.err, "clean roundtrip must not set err")
	testing.expect_value(t, r.off, len(r.data))
}

@(test)
wire_truncated_is_safe :: proc(t: ^testing.T) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u32(&w, 123)
	full := knet.writer_bytes(&w)

	r := knet.reader_make(full[:2]) // cut mid-value
	v := knet.read_u32(&r)
	testing.expect_value(t, v, 0)
	testing.expect(t, r.err, "truncated read must set sticky err")
	// Everything after a sticky error reads as zero, never panics/overruns.
	testing.expect_value(t, knet.read_u64(&r), 0)
	testing.expect_value(t, knet.read_string(&r), "")

	// A string whose length prefix promises more than the buffer holds.
	w2 := knet.writer_make()
	defer knet.writer_destroy(&w2)
	knet.write_u16(&w2, 1000) // lie: no payload follows
	r2 := knet.reader_make(knet.writer_bytes(&w2))
	testing.expect_value(t, knet.read_string(&r2), "")
	testing.expect(t, r2.err)
}

// ---- delta -----------------------------------------------------------------

Probe :: struct {
	hp:    i32,
	x:     f32,
	y:     f32,
	state: u8,
	local_only: int, // NOT in the descriptor — must never be touched
}

probe_desc :: proc() -> knet.Entity_Desc {
	@(static) fields := [?]knet.Field_Desc{
		{offset = offset_of(Probe, hp), size = size_of(i32)},
		{offset = offset_of(Probe, x), size = size_of(f32), flags = {.Interp, .Owner_Stream}},
		{offset = offset_of(Probe, y), size = size_of(f32), flags = {.Interp, .Owner_Stream}},
		{offset = offset_of(Probe, state), size = size_of(u8)},
	}
	return knet.Entity_Desc{fields = fields[:]}
}

@(test)
delta_initial_and_idle :: proc(t: ^testing.T) {
	desc := probe_desc()
	e := Probe{hp = 10, x = 1, y = 2, state = 3, local_only = 99}
	shadow := knet.shadow_make(&desc)
	defer delete(shadow)

	// Fresh shadow is zero: every non-zero field is dirty (the initial full send).
	testing.expect_value(t, knet.diff_mask(&e, shadow, &desc), u64(0b1111))

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	mask := knet.write_delta(&w, &e, shadow, &desc)
	testing.expect_value(t, mask, u64(0b1111))

	// Idle entity: zero mask, zero bytes written.
	knet.writer_reset(&w)
	testing.expect_value(t, knet.write_delta(&w, &e, shadow, &desc), u64(0))
	testing.expect_value(t, len(knet.writer_bytes(&w)), 0)
}

@(test)
delta_partial_roundtrip :: proc(t: ^testing.T) {
	desc := probe_desc()
	sender := Probe{hp = 10, x = 1, y = 2, state = 3}
	shadow := knet.shadow_make(&desc)
	defer delete(shadow)
	knet.shadow_capture(&sender, shadow, &desc) // baseline in sync

	receiver := sender
	receiver.local_only = 55 // receiver-side private state

	sender.hp = 7 // only field 0 changes
	sender.y = 9  // and field 2

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	mask := knet.write_delta(&w, &sender, shadow, &desc)
	testing.expect_value(t, mask, u64(0b0101))

	r := knet.reader_make(knet.writer_bytes(&w))
	applied := knet.apply_delta(&r, &receiver, &desc)
	testing.expect(t, !r.err)
	testing.expect_value(t, applied, u64(0b0101))
	testing.expect_value(t, receiver.hp, sender.hp)
	testing.expect_value(t, receiver.y, sender.y)
	testing.expect_value(t, receiver.x, f32(1)) // untouched
	testing.expect_value(t, receiver.local_only, 55) // never replicated

	// Shadow committed: nothing dirty now.
	testing.expect_value(t, knet.diff_mask(&sender, shadow, &desc), u64(0))
}

@(test)
delta_truncated_sets_err :: proc(t: ^testing.T) {
	desc := probe_desc()
	sender := Probe{hp = 1, x = 2, y = 3, state = 4}
	shadow := knet.shadow_make(&desc)
	defer delete(shadow)

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	_ = knet.write_delta(&w, &sender, shadow, &desc)
	full := knet.writer_bytes(&w)

	receiver := Probe{}
	r := knet.reader_make(full[:len(full) - 2])
	_ = knet.apply_delta(&r, &receiver, &desc)
	testing.expect(t, r.err, "truncated delta must set err so the packet is discarded")
}

@(test)
full_snapshot_and_revert :: proc(t: ^testing.T) {
	desc := probe_desc()
	src := Probe{hp = 42, x = -1, y = 8, state = 2}

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_full(&w, &src, &desc)

	dst := Probe{local_only = 7}
	r := knet.reader_make(knet.writer_bytes(&w))
	knet.apply_full(&r, &dst, &desc)
	testing.expect(t, !r.err)
	testing.expect_value(t, dst.hp, src.hp)
	testing.expect_value(t, dst.state, src.state)
	testing.expect_value(t, dst.local_only, 7)

	// The prediction revert path: capture → optimistic mutation → restore.
	snap := knet.fields_capture(&src, &desc)
	defer delete(snap)
	src.hp = 0
	src.state = 9
	knet.fields_restore(&src, &desc, snap)
	testing.expect_value(t, src.hp, i32(42))
	testing.expect_value(t, src.state, u8(2))
}

// ---- intent ----------------------------------------------------------------

@(test)
pending_confirm_reject_expire :: proc(t: ^testing.T) {
	desc := probe_desc()
	e := Probe{hp = 5}
	tbl := knet.pending_table_make()
	defer knet.pending_table_destroy(&tbl)

	s1 := knet.pending_add(&tbl, knet.Net_Id(1), knet.fields_capture(&e, &desc), 100)
	s2 := knet.pending_add(&tbl, knet.Net_Id(1), knet.fields_capture(&e, &desc), 101)
	s3 := knet.pending_add(&tbl, knet.Net_Id(2), knet.fields_capture(&e, &desc), 108)
	testing.expect(t, s1 != s2 && s2 != s3)
	testing.expect_value(t, knet.pending_count(&tbl), 3)

	// Confirm the middle one: state stands, revert freed internally.
	testing.expect(t, knet.pending_confirm(&tbl, s2))
	testing.expect(t, !knet.pending_confirm(&tbl, s2), "double confirm must miss")
	testing.expect_value(t, knet.pending_count(&tbl), 2)

	// Reject: record handed back for the caller to restore + free.
	p, ok := knet.pending_reject(&tbl, s1)
	testing.expect(t, ok)
	testing.expect_value(t, p.entity, knet.Net_Id(1))
	e.hp = 0
	knet.fields_restore(&e, &desc, p.revert)
	testing.expect_value(t, e.hp, i32(5))
	delete(p.revert)

	// Expire: s3 (issued at 108) ages out at tick 128 with max age 20.
	expired := make([dynamic]knet.Pending)
	defer delete(expired)
	knet.pending_expire(&tbl, 128, 20, &expired)
	testing.expect_value(t, len(expired), 1)
	testing.expect_value(t, expired[0].seq, s3)
	testing.expect_value(t, knet.pending_count(&tbl), 0)
	delete(expired[0].revert)
}

@(test)
dedup_window_semantics :: proc(t: ^testing.T) {
	d := knet.Dedup_Window{}
	testing.expect(t, knet.dedup_accept(&d, 1), "first seq is new")
	testing.expect(t, !knet.dedup_accept(&d, 1), "duplicate rejected")
	testing.expect(t, knet.dedup_accept(&d, 2))
	testing.expect(t, knet.dedup_accept(&d, 5), "gap jump accepted")
	testing.expect(t, knet.dedup_accept(&d, 3), "late-but-new within window accepted")
	testing.expect(t, knet.dedup_accept(&d, 4))
	testing.expect(t, !knet.dedup_accept(&d, 3), "late duplicate rejected")
	testing.expect(t, !knet.dedup_accept(&d, 0), "seq 0 never valid")

	testing.expect(t, knet.dedup_accept(&d, 500))
	testing.expect(t, !knet.dedup_accept(&d, 400), "older than 64-window = stale, rejected")
	testing.expect(t, knet.dedup_accept(&d, 460), "within window and unseen = accepted")
}

// ---- tick / clock ----------------------------------------------------------

@(test)
ticker_pacing :: proc(t: ^testing.T) {
	tk := knet.ticker_make(20) // dt = 50ms
	testing.expect_value(t, knet.ticker_advance(&tk, 0.016), 0)
	testing.expect_value(t, knet.ticker_advance(&tk, 0.016), 0)
	testing.expect_value(t, knet.ticker_advance(&tk, 0.020), 1) // 52ms accumulated
	testing.expect_value(t, tk.tick, u64(1))
	testing.expect_value(t, knet.ticker_advance(&tk, 0.100), 2)
	// A 10s stall is capped at 8 ticks and the backlog is dropped.
	testing.expect_value(t, knet.ticker_advance(&tk, 10.0), 8)
	testing.expect_value(t, tk.acc, 0)
}

@(test)
clock_sync_converges :: proc(t: ^testing.T) {
	c := knet.Clock_Sync{}
	TRUE_OFFSET :: 3.2 // remote clock is 3.2s ahead
	RTT :: 0.080
	local := 100.0
	for _ in 0 ..< 50 {
		send := local
		remote := (send + RTT / 2) + TRUE_OFFSET
		recv := send + RTT
		knet.clock_sample(&c, send, remote, recv)
		local += 0.5
	}
	est := knet.clock_remote_now(&c, local) - local
	testing.expect(t, abs(est - TRUE_OFFSET) < 0.001, "offset should converge under symmetric latency")
	testing.expect(t, abs(c.rtt - RTT) < 0.001)

	// A negative-rtt nonsense sample is dropped, not blended.
	before := c.offset
	knet.clock_sample(&c, 200, 999, 199)
	testing.expect_value(t, c.offset, before)
}

// ---- interp ----------------------------------------------------------------

@(private = "file")
lerp_f32 :: proc(a, b: f32, alpha: f32) -> f32 {
	return a + (b - a) * alpha
}

@(test)
interp_bracketing_and_clamps :: proc(t: ^testing.T) {
	b := knet.Interp_Buffer(f32){}
	_, ok := knet.interp_sample(&b, 1.0, lerp_f32)
	testing.expect(t, !ok, "empty buffer samples nothing")

	knet.interp_push(&b, 1.0, 10)
	knet.interp_push(&b, 2.0, 20)
	knet.interp_push(&b, 3.0, 40)

	v, _ := knet.interp_sample(&b, 1.5, lerp_f32)
	testing.expect_value(t, v, f32(15))
	v, _ = knet.interp_sample(&b, 2.5, lerp_f32)
	testing.expect_value(t, v, f32(30))
	v, _ = knet.interp_sample(&b, 0.5, lerp_f32) // before oldest: clamp
	testing.expect_value(t, v, f32(10))
	v, _ = knet.interp_sample(&b, 9.0, lerp_f32) // past newest: clamp-and-hold
	testing.expect_value(t, v, f32(40))

	// Out-of-order (stale) push is dropped.
	knet.interp_push(&b, 2.5, 999)
	v, _ = knet.interp_sample(&b, 2.75, lerp_f32)
	testing.expect_value(t, v, f32(35)) // still the 2.0→3.0 segment

	// A dropped packet = a wider gap; the lerp simply spans it.
	knet.interp_push(&b, 5.0, 80) // 4.0 never arrived
	v, _ = knet.interp_sample(&b, 4.0, lerp_f32)
	testing.expect_value(t, v, f32(60))
}

@(test)
interp_ring_wraps :: proc(t: ^testing.T) {
	b := knet.Interp_Buffer(f32){}
	for i in 0 ..< 40 { // > INTERP_CAP: oldest evicted
		knet.interp_push(&b, f64(i), f32(i * 10))
	}
	testing.expect_value(t, b.count, knet.INTERP_CAP)
	v, ok := knet.interp_sample(&b, 38.5, lerp_f32)
	testing.expect(t, ok)
	testing.expect_value(t, v, f32(385))
	v, _ = knet.interp_sample(&b, 0, lerp_f32) // evicted history clamps to oldest kept
	testing.expect_value(t, v, f32((40 - knet.INTERP_CAP) * 10))
}
