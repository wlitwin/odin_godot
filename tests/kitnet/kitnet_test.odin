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

// All-host-state fixture (no stream flags — owner streams have their own Mover
// fixture below; .Owner_Stream fields are excluded from deltas by design).
probe_desc :: proc() -> knet.Entity_Desc {
	@(static) fields := [?]knet.Field_Desc{
		{offset = offset_of(Probe, hp), size = size_of(i32)},
		{offset = offset_of(Probe, x), size = size_of(f32), flags = {.Interp}},
		{offset = offset_of(Probe, y), size = size_of(f32), flags = {.Interp}},
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

// ---- nested replicated fields (through using/embedded sub-structs) ----------
//
// A gd:"replicate" field can live inside a sub-struct the entity embeds — promoted
// (`using m: Nested_Move`) or plain (`d: Nested_Deep`, one level deeper). scriptgen
// discovers those and emits COMPOSED offset expressions that name no intermediate
// type (`offset_of(E, m) + offset_of(type_of(E{}.m), x)`), so the wire core sees an
// ordinary flat descriptor. This fixture hand-builds exactly that descriptor — the
// same shape widget.gen.odin emits — and proves the wire path replicates nested
// fields identically to flat ones (nested-replicate-fields KB doc).

Nested_Move :: struct {
	x, y: f32,
	vx:   f32,
}

Nested_Deep :: struct {
	inner: Nested_Move,
	flag:  u8,
}

Nested_Entity :: struct {
	hp:      i32,
	using m: Nested_Move, // promoted: self.x / self.y / self.vx
	d:       Nested_Deep, // plain: self.d.inner.x / self.d.flag
	tint:    u8,
}

// Depth-first, declaration order — the order scriptgen produces. Offsets are the
// verbatim composed expressions from the generator.
nested_desc :: proc() -> knet.Entity_Desc {
	@(static) fields := [?]knet.Field_Desc {
		{offset = offset_of(Nested_Entity, hp), size = size_of(i32)},
		{offset = offset_of(Nested_Entity, m) + offset_of(type_of(Nested_Entity{}.m), x), size = size_of(f32), flags = {.Interp}, lerp = .F32},
		{offset = offset_of(Nested_Entity, m) + offset_of(type_of(Nested_Entity{}.m), vx), size = size_of(f32)},
		{offset = offset_of(Nested_Entity, d) + offset_of(type_of(Nested_Entity{}.d), inner) + offset_of(type_of(Nested_Entity{}.d.inner), x), size = size_of(f32), flags = {.Interp}, lerp = .F32},
		{offset = offset_of(Nested_Entity, d) + offset_of(type_of(Nested_Entity{}.d), flag), size = size_of(u8)},
		{offset = offset_of(Nested_Entity, tint), size = size_of(u8)},
	}
	return knet.Entity_Desc{fields = fields[:]}
}

@(test)
nested_composed_offsets_match_layout :: proc(t: ^testing.T) {
	// The composed offset a nested path emits must equal the field's true offset —
	// the promoted equivalent for the `using` field, the manual chain for the plain one.
	d := nested_desc()
	testing.expect_value(t, d.fields[1].offset, offset_of(Nested_Entity, x)) // promoted
	testing.expect_value(
		t,
		d.fields[3].offset,
		offset_of(Nested_Entity, d) + offset_of(Nested_Deep, inner) + offset_of(Nested_Move, x),
	)
}

@(test)
nested_full_snapshot_roundtrip :: proc(t: ^testing.T) {
	desc := nested_desc()
	src := Nested_Entity{hp = 42, tint = 9}
	src.x = 3.5;src.y = 1.0;src.vx = -2.0 // through `using m`
	src.d.inner.x = 7.25;src.d.flag = 200 // deep plain path

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_full(&w, &src, &desc)

	dst: Nested_Entity
	r := knet.reader_make(knet.writer_bytes(&w))
	knet.apply_full(&r, &dst, &desc)
	testing.expect(t, !r.err)
	testing.expect_value(t, dst.hp, i32(42))
	testing.expect_value(t, dst.x, f32(3.5)) // nested via using
	testing.expect_value(t, dst.vx, f32(-2.0))
	testing.expect_value(t, dst.d.inner.x, f32(7.25)) // deep plain
	testing.expect_value(t, dst.d.flag, u8(200))
	testing.expect_value(t, dst.tint, u8(9))
	testing.expect_value(t, dst.y, f32(0)) // y is not in the descriptor — untouched
}

@(test)
nested_delta_roundtrip :: proc(t: ^testing.T) {
	desc := nested_desc()
	sender := Nested_Entity{hp = 42, tint = 9}
	sender.d.inner.x = 7.25
	shadow := knet.shadow_make(&desc)
	defer delete(shadow)
	knet.shadow_capture(&sender, shadow, &desc) // baselines agree

	receiver := sender
	sender.d.inner.x = 99.0 // mutate ONE deep nested field (descriptor index 3)

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	mask := knet.write_delta(&w, &sender, shadow, &desc)
	testing.expect_value(t, mask, u64(0b001000)) // only bit 3

	r := knet.reader_make(knet.writer_bytes(&w))
	applied := knet.apply_delta(&r, &receiver, &desc)
	testing.expect(t, !r.err)
	testing.expect_value(t, applied, u64(0b001000))
	testing.expect_value(t, receiver.d.inner.x, f32(99.0))
	testing.expect_value(t, receiver.hp, i32(42)) // untouched
	testing.expect_value(t, receiver.tint, u8(9)) // untouched
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
	knet.pending_dispose(p)

	// Expire: s3 (issued at 108) ages out at tick 128 with max age 20.
	expired := make([dynamic]knet.Pending)
	defer delete(expired)
	knet.pending_expire(&tbl, 128, 20, &expired)
	testing.expect_value(t, len(expired), 1)
	testing.expect_value(t, expired[0].seq, s3)
	testing.expect_value(t, knet.pending_count(&tbl), 0)
	knet.pending_dispose(expired[0])
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

@(test)
ping_pong_feeds_clock :: proc(t: ^testing.T) {
	// Two peers with disagreeing clocks exchange ping/pong purely through the
	// wire messages; the estimate must converge on the true skew.
	TRUE_OFFSET :: 12.75 // remote clock is ahead
	ONE_WAY :: 0.030
	c := knet.Clock_Sync{}
	local := 50.0
	for _ in 0 ..< 40 {
		ping := knet.writer_make()
		knet.ping_write(&ping, local)

		remote_recv_time := (local + ONE_WAY) + TRUE_OFFSET
		pr := knet.reader_make(knet.writer_bytes(&ping))
		pong := knet.writer_make()
		knet.ping_answer(&pr, &pong, remote_recv_time)

		gr := knet.reader_make(knet.writer_bytes(&pong))
		testing.expect(t, knet.pong_apply(&gr, &c, local + 2 * ONE_WAY))
		knet.writer_destroy(&ping)
		knet.writer_destroy(&pong)
		local += 1.0
	}
	est := knet.clock_remote_now(&c, local) - local
	testing.expect(t, abs(est - TRUE_OFFSET) < 0.001, "wire ping/pong must converge on the true offset")

	// Truncated pong: nothing sampled, no error escapes.
	before := c.offset
	short := [4]u8{}
	sr := knet.reader_make(short[:])
	testing.expect(t, !knet.pong_apply(&sr, &c, local))
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

// ---- command loop ------------------------------------------------------------
//
// Hand-built thunks + Command_Set stand in for what @(gd_command) generates.
// "Client" and "host" are two Probe copies wired through a capture callback —
// the full intent→command→result loop without a socket.

CMD_ADD :: u16(0) // predicted; rejects when state == 9 ("locked")
CMD_TORN :: u16(1) // hostile: mutates BEFORE rejecting — restore must undo it
CMD_MARK :: u16(2) // non-predicted host-only action

probe_cmd_add :: proc(entity: rawptr, r: ^knet.Reader) -> bool {
	p := cast(^Probe)entity
	amount := knet.read_i32(r)
	if r.err {return false}
	if p.state == 9 {return false}
	p.hp += amount
	return true
}

probe_cmd_torn :: proc(entity: rawptr, r: ^knet.Reader) -> bool {
	p := cast(^Probe)entity
	p.hp = -999
	p.x = -999
	return false // "false = no mutation" must be enforced by the framework, not trusted
}

probe_cmd_mark :: proc(entity: rawptr, r: ^knet.Reader) -> bool {
	p := cast(^Probe)entity
	p.state = knet.read_u8(r)
	return !r.err
}

probe_commands := [?]knet.Command_Desc {
	{name = "add", predict = true, invoke = probe_cmd_add},
	{name = "torn", predict = true, invoke = probe_cmd_torn},
	{name = "mark", predict = false, invoke = probe_cmd_mark},
}

Capture :: struct {
	msgs: [dynamic][]u8,
}

capture_send :: proc(user: rawptr, bytes: []u8) {
	c := cast(^Capture)user
	cloned := make([]u8, len(bytes))
	copy(cloned, bytes)
	append(&c.msgs, cloned)
}

capture_destroy :: proc(c: ^Capture) {
	for m in c.msgs {delete(m)}
	delete(c.msgs)
}

// Host side of the loop: dedup → execute → result bytes (what the session layer
// will do per received command message).
host_handle :: proc(host: ^Probe, set: ^knet.Command_Set, hctx: ^knet.Command_Ctx, peer: u64, msg: []u8, result: ^knet.Writer) -> (executed: bool) {
	r := knet.reader_make(msg)
	h := knet.command_read_header(&r)
	if !knet.command_dedup(hctx, peer, h.seq) {
		return false
	}
	ok := knet.command_execute(host, set, h.cmd, &r)
	knet.command_result_write(result, h, ok, host, set)
	return true
}

// Client side: read the result, confirm or reject(+truth).
client_handle_result :: proc(cctx: ^knet.Command_Ctx, client: ^Probe, set: ^knet.Command_Set, bytes: []u8) {
	r := knet.reader_make(bytes)
	res := knet.command_result_read(&r)
	if res.ok {
		knet.command_confirm(cctx, res.seq)
	} else {
		knet.command_reject(cctx, res, &r, client, set)
	}
}

@(test)
command_predict_confirm :: proc(t: ^testing.T) {
	desc := probe_desc()
	set := knet.Command_Set{entity_desc = &desc, commands = probe_commands[:]}

	client := Probe{hp = 10}
	host := Probe{hp = 10}

	cap := Capture{}
	defer capture_destroy(&cap)
	cctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&cctx)
	cctx.send = capture_send
	cctx.send_user = &cap
	hctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&hctx)
	hctx.is_authority = true

	// Issue add(+5): predicted immediately, message captured.
	knet.command_begin(&cctx, knet.Net_Id(1), CMD_ADD)
	knet.write_i32(&cctx.msg, 5)
	predicted := knet.command_issue(&cctx, &client, &set, CMD_ADD)
	testing.expect(t, predicted, "prediction should apply")
	testing.expect_value(t, client.hp, i32(15))
	testing.expect_value(t, knet.pending_count(&cctx.pending), 1)
	testing.expect_value(t, len(cap.msgs), 1)

	// Host executes the same bytes and confirms.
	result := knet.writer_make()
	defer knet.writer_destroy(&result)
	testing.expect(t, host_handle(&host, &set, &hctx, 7, cap.msgs[0], &result))
	testing.expect_value(t, host.hp, i32(15)) // identical input, identical outcome

	client_handle_result(&cctx, &client, &set, knet.writer_bytes(&result))
	testing.expect_value(t, client.hp, i32(15)) // optimistic state stands, nothing replays
	testing.expect_value(t, knet.pending_count(&cctx.pending), 0)
}

@(test)
command_predict_reject_carries_truth :: proc(t: ^testing.T) {
	desc := probe_desc()
	set := knet.Command_Set{entity_desc = &desc, commands = probe_commands[:]}

	// The client is STALE: the host has moved on (hp 100, locked) but no delta
	// arrived yet. The prediction applies locally, the host rejects, and the
	// reject's embedded truth must win over the client's local revert (10).
	client := Probe{hp = 10}
	host := Probe{hp = 100, state = 9}

	cap := Capture{}
	defer capture_destroy(&cap)
	cctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&cctx)
	cctx.send = capture_send
	cctx.send_user = &cap
	hctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&hctx)

	knet.command_begin(&cctx, knet.Net_Id(1), CMD_ADD)
	knet.write_i32(&cctx.msg, 5)
	testing.expect(t, knet.command_issue(&cctx, &client, &set, CMD_ADD))
	testing.expect_value(t, client.hp, i32(15))

	result := knet.writer_make()
	defer knet.writer_destroy(&result)
	_ = host_handle(&host, &set, &hctx, 7, cap.msgs[0], &result)
	testing.expect_value(t, host.hp, i32(100)) // locked: rejected, untouched

	client_handle_result(&cctx, &client, &set, knet.writer_bytes(&result))
	testing.expect_value(t, client.hp, i32(100)) // truth, not the stale revert
	testing.expect_value(t, client.state, u8(9))
	testing.expect_value(t, knet.pending_count(&cctx.pending), 0)
}

@(test)
command_local_reject_restores_and_still_sends :: proc(t: ^testing.T) {
	desc := probe_desc()
	set := knet.Command_Set{entity_desc = &desc, commands = probe_commands[:]}

	client := Probe{hp = 10, state = 9} // locked locally: prediction rejects
	cap := Capture{}
	defer capture_destroy(&cap)
	cctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&cctx)
	cctx.send = capture_send
	cctx.send_user = &cap

	knet.command_begin(&cctx, knet.Net_Id(1), CMD_ADD)
	knet.write_i32(&cctx.msg, 5)
	testing.expect(t, !knet.command_issue(&cctx, &client, &set, CMD_ADD))
	testing.expect_value(t, client.hp, i32(10)) // restored
	testing.expect_value(t, knet.pending_count(&cctx.pending), 0)
	// Still sent: the local copy may be stale — only the host may say no.
	testing.expect_value(t, len(cap.msgs), 1)
}

@(test)
command_execute_restores_torn_state :: proc(t: ^testing.T) {
	desc := probe_desc()
	set := knet.Command_Set{entity_desc = &desc, commands = probe_commands[:]}

	// Host side: a proc that mutates then returns false must leave no trace.
	host := Probe{hp = 42, x = 1}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	r := knet.reader_make(knet.writer_bytes(&w)) // no args
	testing.expect(t, !knet.command_execute(&host, &set, CMD_TORN, &r))
	testing.expect_value(t, host.hp, i32(42))
	testing.expect_value(t, host.x, f32(1))

	// Client side: the predicted run of the same proc is restored the same way.
	client := Probe{hp = 42, x = 1}
	cctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&cctx)
	knet.command_begin(&cctx, knet.Net_Id(1), CMD_TORN)
	testing.expect(t, !knet.command_issue(&cctx, &client, &set, CMD_TORN))
	testing.expect_value(t, client.hp, i32(42))
	testing.expect_value(t, client.x, f32(1))
}

@(test)
command_dedup_replay_executes_once :: proc(t: ^testing.T) {
	desc := probe_desc()
	set := knet.Command_Set{entity_desc = &desc, commands = probe_commands[:]}

	host := Probe{hp = 10}
	cap := Capture{}
	defer capture_destroy(&cap)
	cctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&cctx)
	cctx.send = capture_send
	cctx.send_user = &cap
	hctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&hctx)

	client := Probe{hp = 10}
	knet.command_begin(&cctx, knet.Net_Id(1), CMD_ADD)
	knet.write_i32(&cctx.msg, 5)
	_ = knet.command_issue(&cctx, &client, &set, CMD_ADD)

	result := knet.writer_make()
	defer knet.writer_destroy(&result)
	testing.expect(t, host_handle(&host, &set, &hctx, 7, cap.msgs[0], &result), "first delivery executes")
	testing.expect_value(t, host.hp, i32(15))
	// Replay of the exact same bytes (retransmit / reconnect replay): dropped.
	testing.expect(t, !host_handle(&host, &set, &hctx, 7, cap.msgs[0], &result), "replay must be dropped")
	testing.expect_value(t, host.hp, i32(15))
	// Same seq from a DIFFERENT peer is a different command: executes.
	testing.expect(t, host_handle(&host, &set, &hctx, 8, cap.msgs[0], &result))
	testing.expect_value(t, host.hp, i32(20))
}

@(test)
command_malformed_input_rejects :: proc(t: ^testing.T) {
	desc := probe_desc()
	set := knet.Command_Set{entity_desc = &desc, commands = probe_commands[:]}
	host := Probe{hp = 10}

	// Truncated args: the thunk sees r.err before calling the proc.
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u16(&w, 0xFF) // 2 bytes where read_i32 wants 4
	r := knet.reader_make(knet.writer_bytes(&w))
	testing.expect(t, !knet.command_execute(&host, &set, CMD_ADD, &r))
	testing.expect_value(t, host.hp, i32(10))

	// Unknown command index from a hostile/mismatched peer: rejected, no panic.
	r2 := knet.reader_make(nil)
	testing.expect(t, !knet.command_execute(&host, &set, 200, &r2))
}

@(test)
command_non_predicted_defers_to_host :: proc(t: ^testing.T) {
	desc := probe_desc()
	set := knet.Command_Set{entity_desc = &desc, commands = probe_commands[:]}

	client := Probe{state = 1}
	cap := Capture{}
	defer capture_destroy(&cap)
	cctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&cctx)
	cctx.send = capture_send
	cctx.send_user = &cap

	knet.command_begin(&cctx, knet.Net_Id(1), CMD_MARK)
	knet.write_u8(&cctx.msg, 4)
	testing.expect(t, !knet.command_issue(&cctx, &client, &set, CMD_MARK))
	testing.expect_value(t, client.state, u8(1)) // untouched: no prediction declared
	testing.expect_value(t, knet.pending_count(&cctx.pending), 0)
	testing.expect_value(t, len(cap.msgs), 1) // but the intent went to the host

	host := Probe{state = 1}
	hctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&hctx)
	result := knet.writer_make()
	defer knet.writer_destroy(&result)
	_ = host_handle(&host, &set, &hctx, 7, cap.msgs[0], &result)
	testing.expect_value(t, host.state, u8(4))
}

// ---- registry ------------------------------------------------------------
//
// A second entity type proves heterogeneous batching: per-entity mask widths,
// dispatch by id, and a descriptor with no commands at all.

Dot :: struct {
	v:      u16,
	hidden: int, // not replicated
}

dot_desc :: proc() -> knet.Entity_Desc {
	@(static) fields := [?]knet.Field_Desc{{offset = offset_of(Dot, v), size = size_of(u16)}}
	return knet.Entity_Desc{fields = fields[:]}
}

@(test)
registry_batched_deltas :: proc(t: ^testing.T) {
	pdesc := probe_desc()
	pset := knet.Command_Set{entity_desc = &pdesc, commands = probe_commands[:]}
	ddesc := dot_desc()
	dset := knet.Command_Set{entity_desc = &ddesc} // desc-only: no commands

	// Authority side: spawn allocates ids; fresh shadows make the first walk
	// the initial full send.
	sreg := knet.registry_make()
	defer knet.registry_destroy(&sreg)
	sprobe := Probe{hp = 10, x = 1}
	sdot := Dot{v = 7}
	pid := knet.registry_spawn(&sreg, &sprobe, &pset)
	did := knet.registry_spawn(&sreg, &sdot, &dset)
	testing.expect(t, pid != did)

	// Remote side mirrors under the wire ids.
	creg := knet.registry_make()
	defer knet.registry_destroy(&creg)
	cprobe := Probe{local_only = 5}
	cdot := Dot{hidden = 5}
	knet.registry_insert(&creg, pid, &cprobe, &pset)
	knet.registry_insert(&creg, did, &cdot, &dset)

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	testing.expect_value(t, knet.registry_write_deltas(&w, &sreg), 2)
	r := knet.reader_make(knet.writer_bytes(&w))
	testing.expect_value(t, knet.registry_apply_deltas(&r, &creg), 2)
	testing.expect(t, !r.err)
	testing.expect_value(t, cprobe.hp, i32(10))
	testing.expect_value(t, cprobe.x, f32(1))
	testing.expect_value(t, cdot.v, u16(7))
	testing.expect_value(t, cprobe.local_only, 5) // private state untouched
	testing.expect_value(t, cdot.hidden, 5)

	// Idle tick: zero entities, callers may skip the send.
	knet.writer_reset(&w)
	testing.expect_value(t, knet.registry_write_deltas(&w, &sreg), 0)

	// Partial tick: only the dot moves — the probe contributes zero bytes.
	sdot.v = 8
	knet.writer_reset(&w)
	testing.expect_value(t, knet.registry_write_deltas(&w, &sreg), 1)
	r2 := knet.reader_make(knet.writer_bytes(&w))
	testing.expect_value(t, knet.registry_apply_deltas(&r2, &creg), 1)
	testing.expect_value(t, cdot.v, u16(8))
}

@(test)
registry_unknown_id_abandons_batch :: proc(t: ^testing.T) {
	pdesc := probe_desc()
	pset := knet.Command_Set{entity_desc = &pdesc, commands = probe_commands[:]}

	sreg := knet.registry_make()
	defer knet.registry_destroy(&sreg)
	a := Probe{hp = 1}
	b := Probe{hp = 2}
	_ = knet.registry_spawn(&sreg, &a, &pset)
	bid := knet.registry_spawn(&sreg, &b, &pset)

	// The receiver only knows entity b: an unknown id mid-batch is unrecoverable
	// (no descriptor to size the fields) — err set, no crash, no overrun.
	creg := knet.registry_make()
	defer knet.registry_destroy(&creg)
	cb := Probe{}
	knet.registry_insert(&creg, bid, &cb, &pset)

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	_ = knet.registry_write_deltas(&w, &sreg)
	r := knet.reader_make(knet.writer_bytes(&w))
	_ = knet.registry_apply_deltas(&r, &creg)
	testing.expect(t, r.err, "unknown id must abandon the batch with a sticky error")
}

@(test)
registry_full_snapshot_roundtrip :: proc(t: ^testing.T) {
	pdesc := probe_desc()
	pset := knet.Command_Set{entity_desc = &pdesc, commands = probe_commands[:]}

	sreg := knet.registry_make()
	defer knet.registry_destroy(&sreg)
	s1 := Probe{hp = 11, x = 2, state = 3}
	s2 := Probe{hp = 22}
	id1 := knet.registry_spawn(&sreg, &s1, &pset)
	id2 := knet.registry_spawn(&sreg, &s2, &pset)

	creg := knet.registry_make()
	defer knet.registry_destroy(&creg)
	c1 := Probe{}
	c2 := Probe{}
	knet.registry_insert(&creg, id1, &c1, &pset)
	knet.registry_insert(&creg, id2, &c2, &pset)

	// The join snapshot: everything, no masks. Then commit shadows so the new
	// peer's own first diff (were it to become authority) is clean.
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	testing.expect_value(t, knet.registry_write_fulls(&w, &sreg), 2)
	r := knet.reader_make(knet.writer_bytes(&w))
	testing.expect_value(t, knet.registry_apply_fulls(&r, &creg), 2)
	testing.expect(t, !r.err)
	testing.expect_value(t, c1.hp, i32(11))
	testing.expect_value(t, c1.state, u8(3))
	testing.expect_value(t, c2.hp, i32(22))

	knet.registry_commit_shadows(&creg)
	w2 := knet.writer_make()
	defer knet.writer_destroy(&w2)
	testing.expect_value(t, knet.registry_write_deltas(&w2, &creg), 0)

	// registry_insert keeps allocation ahead of mirrored ids (migration-ready).
	extra := Probe{}
	nid := knet.registry_spawn(&creg, &extra, &pset)
	testing.expect(t, nid != id1 && nid != id2)
}

// ---- prediction reconcile (unwind → apply → replay) -------------------------
//
// The race THE ACID TEST exposed: the host broadcasts a delta it wrote BEFORE
// executing a command the client has already predicted. Reconcile must keep
// the optimistic values alive by re-running the pending command on top of the
// authoritative state (the SAME proc, the SAME wire bytes).

@(test)
registry_delta_replays_pending_prediction :: proc(t: ^testing.T) {
	pdesc := probe_desc()
	pset := knet.Command_Set{entity_desc = &pdesc, commands = probe_commands[:]}

	sreg := knet.registry_make()
	defer knet.registry_destroy(&sreg)
	host := Probe{hp = 10}
	id := knet.registry_spawn(&sreg, &host, &pset)

	creg := knet.registry_make()
	defer knet.registry_destroy(&creg)
	client := Probe{hp = 10}
	knet.registry_insert(&creg, id, &client, &pset)
	knet.registry_commit_shadows(&sreg) // baseline delivered (join snapshot)

	cap := Capture{}
	defer capture_destroy(&cap)
	cctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&cctx)
	cctx.send = capture_send
	cctx.send_user = &cap
	hctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&hctx)
	hctx.is_authority = true

	// Client predicts TWO adds back to back: +5 then +3.
	knet.command_begin(&cctx, id, CMD_ADD)
	knet.write_i32(&cctx.msg, 5)
	testing.expect(t, knet.command_issue(&cctx, &client, &pset, CMD_ADD))
	knet.command_begin(&cctx, id, CMD_ADD)
	knet.write_i32(&cctx.msg, 3)
	testing.expect(t, knet.command_issue(&cctx, &client, &pset, CMD_ADD))
	testing.expect_value(t, client.hp, i32(18))
	testing.expect_value(t, knet.pending_count(&cctx.pending), 2)

	// Host executes ONLY the first command and answers it. On the ordered
	// channel the result precedes any delta carrying its effect — so the
	// client confirms (+5's pending pops) BEFORE that delta arrives.
	res1 := knet.writer_make()
	defer knet.writer_destroy(&res1)
	rr := knet.reader_make(cap.msgs[0])
	responded, ok, _ := knet.registry_host_command(&sreg, &hctx, 7, &rr, &res1)
	testing.expect(t, responded && ok)
	testing.expect_value(t, host.hp, i32(15))
	cr1 := knet.reader_make(knet.writer_bytes(&res1))
	_ = knet.registry_client_result(&creg, &cctx, &cr1)
	testing.expect_value(t, knet.pending_count(&cctx.pending), 1)
	testing.expect_value(t, client.hp, i32(18)) // confirm replays nothing

	// The host's net tick: hp=15 (WITHOUT the second command). Naively applied,
	// it would stomp the client back to 15; reconcile must land on 18.
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	testing.expect_value(t, knet.registry_write_deltas(&w, &sreg), 1)
	dr := knet.reader_make(knet.writer_bytes(&w))
	testing.expect_value(t, knet.registry_apply_deltas(&dr, &creg, &cctx), 1)
	testing.expect(t, !dr.err)
	testing.expect_value(t, client.hp, i32(18)) // authoritative 15 + replayed +3
	testing.expect_value(t, knet.pending_count(&cctx.pending), 1)

	// The +3 lands host-side; its confirm drains the last pending. Converged.
	res2 := knet.writer_make()
	defer knet.writer_destroy(&res2)
	rr2 := knet.reader_make(cap.msgs[1])
	responded, ok, _ = knet.registry_host_command(&sreg, &hctx, 7, &rr2, &res2)
	testing.expect(t, responded && ok)
	cr2 := knet.reader_make(knet.writer_bytes(&res2))
	_ = knet.registry_client_result(&creg, &cctx, &cr2)
	testing.expect_value(t, knet.pending_count(&cctx.pending), 0)
	testing.expect_value(t, client.hp, i32(18))
	testing.expect_value(t, host.hp, i32(18))
}

@(test)
registry_delta_untouched_fields_do_not_double_apply :: proc(t: ^testing.T) {
	pdesc := probe_desc()
	pset := knet.Command_Set{entity_desc = &pdesc, commands = probe_commands[:]}

	sreg := knet.registry_make()
	defer knet.registry_destroy(&sreg)
	host := Probe{hp = 10, state = 1}
	id := knet.registry_spawn(&sreg, &host, &pset)

	creg := knet.registry_make()
	defer knet.registry_destroy(&creg)
	client := Probe{hp = 10, state = 1}
	knet.registry_insert(&creg, id, &client, &pset)
	knet.registry_commit_shadows(&sreg)

	cctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&cctx)

	knet.command_begin(&cctx, id, CMD_ADD)
	knet.write_i32(&cctx.msg, 5)
	testing.expect(t, knet.command_issue(&cctx, &client, &pset, CMD_ADD))
	testing.expect_value(t, client.hp, i32(15))

	// The host changed an UNRELATED field: the delta's mask does not carry hp.
	// Unwind-then-replay must keep hp at exactly one prediction's worth (15),
	// not re-add on top of the still-applied optimistic value (20).
	host.state = 2
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	testing.expect_value(t, knet.registry_write_deltas(&w, &sreg), 1)
	dr := knet.reader_make(knet.writer_bytes(&w))
	testing.expect_value(t, knet.registry_apply_deltas(&dr, &creg, &cctx), 1)
	testing.expect_value(t, client.hp, i32(15))
	testing.expect_value(t, client.state, u8(2))
	testing.expect_value(t, knet.pending_count(&cctx.pending), 1)
}

@(test)
registry_replay_precondition_failure_drops_prediction :: proc(t: ^testing.T) {
	pdesc := probe_desc()
	pset := knet.Command_Set{entity_desc = &pdesc, commands = probe_commands[:]}

	sreg := knet.registry_make()
	defer knet.registry_destroy(&sreg)
	host := Probe{hp = 10, state = 1}
	id := knet.registry_spawn(&sreg, &host, &pset)

	creg := knet.registry_make()
	defer knet.registry_destroy(&creg)
	client := Probe{hp = 10, state = 1}
	knet.registry_insert(&creg, id, &client, &pset)
	knet.registry_commit_shadows(&sreg)

	cctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&cctx)

	knet.command_begin(&cctx, id, CMD_ADD)
	knet.write_i32(&cctx.msg, 5)
	testing.expect(t, knet.command_issue(&cctx, &client, &pset, CMD_ADD))
	testing.expect_value(t, client.hp, i32(15))

	// Authoritative state now LOCKS the entity (CMD_ADD's reject condition):
	// the replay must fail cleanly and leave pure authoritative values — the
	// host's reject (in flight) will pop the pending with the same outcome.
	host.state = 9
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	testing.expect_value(t, knet.registry_write_deltas(&w, &sreg), 1)
	dr := knet.reader_make(knet.writer_bytes(&w))
	testing.expect_value(t, knet.registry_apply_deltas(&dr, &creg, &cctx), 1)
	testing.expect_value(t, client.hp, i32(10)) // prediction dropped, not doubled
	testing.expect_value(t, client.state, u8(9))
	testing.expect_value(t, knet.pending_count(&cctx.pending), 1) // result still owed
}

@(test)
registry_command_routing :: proc(t: ^testing.T) {
	pdesc := probe_desc()
	pset := knet.Command_Set{entity_desc = &pdesc, commands = probe_commands[:]}

	sreg := knet.registry_make()
	defer knet.registry_destroy(&sreg)
	host := Probe{hp = 10}
	hid := knet.registry_spawn(&sreg, &host, &pset)

	creg := knet.registry_make()
	defer knet.registry_destroy(&creg)
	client := Probe{hp = 10}
	knet.registry_insert(&creg, hid, &client, &pset)

	cap := Capture{}
	defer capture_destroy(&cap)
	cctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&cctx)
	cctx.send = capture_send
	cctx.send_user = &cap
	hctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&hctx)

	// Confirmed command through the registry resolver.
	knet.command_begin(&cctx, hid, CMD_ADD)
	knet.write_i32(&cctx.msg, 5)
	testing.expect(t, knet.command_issue(&cctx, &client, &pset, CMD_ADD))
	result := knet.writer_make()
	defer knet.writer_destroy(&result)
	rr := knet.reader_make(cap.msgs[0])
	responded, ok, h := knet.registry_host_command(&sreg, &hctx, 7, &rr, &result)
	testing.expect(t, responded && ok)
	testing.expect_value(t, host.hp, i32(15))
	testing.expect(t, h.entity == hid && h.cmd == CMD_ADD, "the header comes back for command hooks")
	res_r := knet.reader_make(knet.writer_bytes(&result))
	res := knet.registry_client_result(&creg, &cctx, &res_r)
	testing.expect(t, res.ok)
	testing.expect_value(t, knet.pending_count(&cctx.pending), 0)

	// A command naming an entity the host doesn't have: NO response (expiry is
	// the client's safety net), nothing executes.
	knet.command_begin(&cctx, knet.Net_Id(999), CMD_ADD)
	knet.write_i32(&cctx.msg, 5)
	_ = knet.command_issue(&cctx, &client, &pset, CMD_ADD) // predicts against the local copy
	knet.writer_reset(&result)
	rr2 := knet.reader_make(cap.msgs[1])
	responded2, _, _ := knet.registry_host_command(&sreg, &hctx, 7, &rr2, &result)
	testing.expect(t, !responded2)
	testing.expect_value(t, len(knet.writer_bytes(&result)), 0)
}

@(test)
registry_expire_reverts_lost_predictions :: proc(t: ^testing.T) {
	pdesc := probe_desc()
	pset := knet.Command_Set{entity_desc = &pdesc, commands = probe_commands[:]}

	creg := knet.registry_make()
	defer knet.registry_destroy(&creg)
	alive := Probe{hp = 10}
	doomed := Probe{hp = 10}
	aid := knet.Net_Id(1)
	did := knet.Net_Id(2)
	knet.registry_insert(&creg, aid, &alive, &pset)
	knet.registry_insert(&creg, did, &doomed, &pset)

	cctx := knet.command_ctx_make()
	defer knet.command_ctx_destroy(&cctx)
	cctx.now_tick = 100

	issue :: proc(cctx: ^knet.Command_Ctx, e: ^Probe, set: ^knet.Command_Set, id: knet.Net_Id) {
		knet.command_begin(cctx, id, CMD_ADD)
		knet.write_i32(&cctx.msg, 5)
		_ = knet.command_issue(cctx, e, set, CMD_ADD)
	}
	issue(&cctx, &alive, &pset, aid)
	issue(&cctx, &doomed, &pset, did)
	testing.expect_value(t, alive.hp, i32(15))
	testing.expect_value(t, knet.pending_count(&cctx.pending), 2)

	// The doomed entity despawns while its prediction is in flight.
	testing.expect(t, knet.registry_remove(&creg, did))

	// No result ever arrives: both predictions age out; the live one reverts,
	// the despawned one is skipped without crashing (revert buffer still freed).
	cctx.now_tick = 200
	testing.expect_value(t, knet.registry_expire_pending(&creg, &cctx, 50), 2)
	testing.expect_value(t, alive.hp, i32(10))
	testing.expect_value(t, knet.pending_count(&cctx.pending), 0)
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

// ---- owner streams -----------------------------------------------------------
//
// Fields flagged .Owner_Stream are authoritative on the entity's OWNER: they
// travel as last-value snapshots on the unreliable channel and are SAMPLED
// (delayed, interpolated) by everyone else — and they are excluded from
// authority delta batches by construction.

Mover :: struct {
	hp:    i32, // host state: the delta path
	x, y:  f32, // owner-streamed, lerped
	face:  u8, // owner-streamed, snapped (steps between samples)
	local: int,
}

mover_desc :: proc() -> knet.Entity_Desc {
	@(static) fields := [?]knet.Field_Desc{
		{offset = offset_of(Mover, hp), size = size_of(i32)},
		{offset = offset_of(Mover, x), size = size_of(f32), flags = {.Interp, .Owner_Stream}, lerp = .F32},
		{offset = offset_of(Mover, y), size = size_of(f32), flags = {.Interp, .Owner_Stream}, lerp = .F32},
		{offset = offset_of(Mover, face), size = size_of(u8), flags = {.Owner_Stream}},
	}
	return knet.Entity_Desc{fields = fields[:]}
}

@(test)
stream_ring_lerps_and_snaps :: proc(t: ^testing.T) {
	desc := mover_desc()
	testing.expect_value(t, knet.stream_data_size(&desc), 9) // x + y + face

	owner := Mover{hp = 77, x = 0, y = 10, face = 1}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.stream_write(&w, &owner, &desc)
	testing.expect_value(t, len(knet.writer_bytes(&w)), 9) // hp/local never stream

	ring := knet.Stream_Ring{}
	defer knet.stream_ring_destroy(&ring)
	knet.stream_ring_push(&ring, 1.0, knet.writer_bytes(&w))

	owner.x = 10
	owner.y = 20
	owner.face = 2
	knet.writer_reset(&w)
	knet.stream_write(&w, &owner, &desc)
	knet.stream_ring_push(&ring, 2.0, knet.writer_bytes(&w))

	remote := Mover{hp = 5, local = 9}
	// Midpoint: floats lerp, the snap field HOLDS the earlier sample.
	testing.expect(t, knet.stream_ring_sample(&ring, 1.5, &remote, &desc))
	testing.expect_value(t, remote.x, f32(5))
	testing.expect_value(t, remote.y, f32(15))
	testing.expect_value(t, remote.face, u8(1))
	testing.expect_value(t, remote.hp, i32(5)) // non-streamed fields untouched
	testing.expect_value(t, remote.local, 9)

	// Clamp semantics: before the oldest → oldest; past the newest → hold.
	testing.expect(t, knet.stream_ring_sample(&ring, 0.5, &remote, &desc))
	testing.expect_value(t, remote.x, f32(0))
	testing.expect_value(t, remote.face, u8(1))
	testing.expect(t, knet.stream_ring_sample(&ring, 9.0, &remote, &desc))
	testing.expect_value(t, remote.x, f32(10))
	testing.expect_value(t, remote.face, u8(2))

	// Stale (reordered) push is dropped: the timeline never goes backwards.
	knet.writer_reset(&w)
	owner.x = -999
	knet.stream_write(&w, &owner, &desc)
	knet.stream_ring_push(&ring, 1.5, knet.writer_bytes(&w))
	testing.expect(t, knet.stream_ring_sample(&ring, 9.0, &remote, &desc))
	testing.expect_value(t, remote.x, f32(10))
}

@(test)
delta_excludes_owner_stream_fields :: proc(t: ^testing.T) {
	desc := mover_desc()
	e := Mover{hp = 1, x = 100, y = 200, face = 3}
	shadow := knet.shadow_make(&desc)
	defer delete(shadow)
	knet.shadow_capture(&e, shadow, &desc)

	// Streamed fields changing NEVER dirty the delta mask — the host samples
	// them locally every frame; if they dirtied, deltas would re-broadcast the
	// owner's stream on the reliable channel forever.
	e.x = 500
	e.face = 4
	testing.expect_value(t, knet.diff_mask(&e, shadow, &desc), u64(0))
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	testing.expect_value(t, knet.write_delta(&w, &e, shadow, &desc), u64(0))

	// Host state still deltas normally alongside.
	e.hp = 2
	testing.expect_value(t, knet.write_delta(&w, &e, shadow, &desc), u64(0b0001))

	// Fulls still carry EVERYTHING — the join snapshot seeds streamed fields.
	knet.writer_reset(&w)
	knet.write_full(&w, &e, &desc)
	fresh := Mover{}
	r := knet.reader_make(knet.writer_bytes(&w))
	knet.apply_full(&r, &fresh, &desc)
	testing.expect_value(t, fresh.x, f32(500))
	testing.expect_value(t, fresh.face, u8(4))
}

@(test)
registry_streams_end_to_end :: proc(t: ^testing.T) {
	mdesc := mover_desc()
	mset := knet.Command_Set{entity_desc = &mdesc}
	ME :: knet.Player_Id(2)
	OTHER :: knet.Player_Id(3)

	// Owner side: two owned movers, plus one owned by someone else (must not
	// be streamed by this peer).
	oreg := knet.registry_make()
	defer knet.registry_destroy(&oreg)
	m1 := Mover{x = 0, y = 10, face = 1}
	m2 := Mover{x = 100, y = 0, face = 7}
	other := Mover{x = -5}
	id1 := knet.registry_spawn(&oreg, &m1, &mset, ME)
	id2 := knet.registry_spawn(&oreg, &m2, &mset, ME)
	_ = knet.registry_spawn(&oreg, &other, &mset, OTHER)

	// Receiver knows only m1 (m2's spawn hasn't arrived — stream batches skip
	// unknown ids by LENGTH instead of abandoning, unlike delta batches).
	rreg := knet.registry_make()
	defer knet.registry_destroy(&rreg)
	r1 := Mover{hp = 42}
	knet.registry_insert(&rreg, id1, &r1, &mset, ME)
	_ = id2

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	testing.expect_value(t, knet.registry_write_streams(&w, &oreg, ME, 1.0), 2)

	r := knet.reader_make(knet.writer_bytes(&w))
	testing.expect_value(t, knet.registry_stream_time(&r), 1.0)
	testing.expect_value(t, knet.registry_apply_streams(&r, &rreg, OTHER, 1.0), 1)
	testing.expect(t, !r.err, "unknown id in a stream batch is skipped, not an error")

	// Second tick: m1 moved.
	m1.x = 10
	m1.y = 30
	m1.face = 2
	knet.writer_reset(&w)
	_ = knet.registry_write_streams(&w, &oreg, ME, 2.0)
	r2 := knet.reader_make(knet.writer_bytes(&w))
	_ = knet.registry_stream_time(&r2)
	testing.expect_value(t, knet.registry_apply_streams(&r2, &rreg, OTHER, 2.0), 1)

	// Sample the midpoint into the receiver's entity.
	testing.expect_value(t, knet.registry_sample_streams(&rreg, 1.5, OTHER), 1)
	testing.expect_value(t, r1.x, f32(5))
	testing.expect_value(t, r1.y, f32(20))
	testing.expect_value(t, r1.face, u8(1))
	testing.expect_value(t, r1.hp, i32(42)) // host state untouched by streams

	// A peer NEVER accepts a stream for an entity it owns itself.
	knet.writer_reset(&w)
	_ = knet.registry_write_streams(&w, &oreg, ME, 3.0)
	r3 := knet.reader_make(knet.writer_bytes(&w))
	_ = knet.registry_stream_time(&r3)
	testing.expect_value(t, knet.registry_apply_streams(&r3, &rreg, ME, 3.0), 0)
}

@(test)
stream_frequency_tier_skips_off_phase_ticks :: proc(t: ^testing.T) {
	mdesc := mover_desc()
	mset := knet.Command_Set{entity_desc = &mdesc}
	ME :: knet.Player_Id(2)

	oreg := knet.registry_make()
	defer knet.registry_destroy(&oreg)
	full := Mover{x = 1}
	tiered := Mover{x = 2}
	id_full := knet.registry_spawn(&oreg, &full, &mset, ME)
	id_tier := knet.registry_spawn(&oreg, &tiered, &mset, ME)
	knet.registry_set_stream_tier(&oreg, id_tier, 2) // 30Hz at a 60Hz base

	w := knet.writer_make()
	defer knet.writer_destroy(&w)

	// The tier's phase is (tick + id) % tier == 0. Across two consecutive
	// ticks the tiered entity sends on EXACTLY one of them, and the untiered
	// one on both — so the pair alternates 2,1 (or 1,2), never 2,2.
	knet.writer_reset(&w)
	a := knet.registry_write_streams(&w, &oreg, ME, 1.0, 10)
	knet.writer_reset(&w)
	b := knet.registry_write_streams(&w, &oreg, ME, 1.0, 11)
	testing.expect(t, a + b == 3, "over two ticks the tiered entity streams once, the untiered twice")
	testing.expect(t, a == 1 || a == 2, "each tick carries the untiered entity plus maybe the tiered one")

	// The untiered entity is ALWAYS present (tier 0 = every tick).
	for tick in u64(100) ..< 106 {
		knet.writer_reset(&w)
		n := knet.registry_write_streams(&w, &oreg, ME, 1.0, tick)
		testing.expect(t, n >= 1, "the full-rate entity streams on every tick")
	}
	_ = id_full
}

// ---- special interpolation math (quat nlerp + custom blends) ------------------

Turret :: struct {
	rot:     [4]f32, // quaternion xyzw — hemisphere-safe nlerp
	heading: f32, // degrees — custom shortest-arc blend
}

// A knet.Blend_Proc: degrees along the shortest arc, wrapped to [0, 360).
blend_heading :: proc(dst, a, b: rawptr, alpha: f32) {
	av := (^f32)(a)^
	bv := (^f32)(b)^
	d := bv - av
	for d > 180 {d -= 360}
	for d < -180 {d += 360}
	v := av + d * alpha
	for v >= 360 {v -= 360}
	for v < 0 {v += 360}
	(^f32)(dst)^ = v
}

turret_desc :: proc() -> knet.Entity_Desc {
	@(static) fields := [?]knet.Field_Desc{
		{offset = offset_of(Turret, rot), size = size_of([4]f32), flags = {.Interp, .Owner_Stream}, lerp = .Quat},
		{offset = offset_of(Turret, heading), size = size_of(f32), flags = {.Interp, .Owner_Stream}, lerp = .Custom, blend = blend_heading},
	}
	return knet.Entity_Desc{fields = fields[:]}
}

@(test)
stream_quat_and_custom_blend :: proc(t: ^testing.T) {
	desc := turret_desc()
	near :: proc(a, b: f32) -> bool {return abs(a - b) < 0.0005}

	// Sample A: identity rotation, heading 350°. Sample B: 90° about X — but
	// streamed as the NEGATED quaternion (-q == q as a rotation): the exact
	// input that collapses a raw componentwise lerp through zero.
	owner := Turret{rot = {0, 0, 0, 1}, heading = 350}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.stream_write(&w, &owner, &desc)
	ring := knet.Stream_Ring{}
	defer knet.stream_ring_destroy(&ring)
	knet.stream_ring_push(&ring, 1.0, knet.writer_bytes(&w))

	S45 :: f32(0.70710678)
	owner.rot = {-S45, 0, 0, -S45}
	owner.heading = 10
	knet.writer_reset(&w)
	knet.stream_write(&w, &owner, &desc)
	knet.stream_ring_push(&ring, 2.0, knet.writer_bytes(&w))

	// Midpoint must be 45° about X — unit length, right hemisphere — and the
	// heading must cross 360° the short way (350° -> 10° lands on 0°, not 180°).
	remote := Turret{}
	testing.expect(t, knet.stream_ring_sample(&ring, 1.5, &remote, &desc))
	SIN22_5 :: f32(0.38268343)
	COS22_5 :: f32(0.92387953)
	testing.expect(t, near(remote.rot[0], SIN22_5), "quat x: hemisphere flip + nlerp")
	testing.expect(t, near(remote.rot[1], 0) && near(remote.rot[2], 0))
	testing.expect(t, near(remote.rot[3], COS22_5), "quat w")
	len2 := remote.rot[0] * remote.rot[0] + remote.rot[1] * remote.rot[1] + remote.rot[2] * remote.rot[2] + remote.rot[3] * remote.rot[3]
	testing.expect(t, near(len2, 1), "nlerp renormalizes")
	testing.expect(t, near(remote.heading, 0), "custom blend takes the shortest arc across 360")

	// Quarter point for the custom blend: 350° + 20°*0.25 = 355°.
	testing.expect(t, knet.stream_ring_sample(&ring, 1.25, &remote, &desc))
	testing.expect(t, near(remote.heading, 355))
}

@(test)
stream_ring_snaps_across_teleport_warp :: proc(t: ^testing.T) {
	desc := mover_desc()
	owner := Mover{x = 0, y = 0, face = 1}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	ring := knet.Stream_Ring{}
	defer knet.stream_ring_destroy(&ring)

	knet.stream_write(&w, &owner, &desc)
	knet.stream_ring_push(&ring, 1.0, knet.writer_bytes(&w), 0)
	owner.x = 10
	knet.writer_reset(&w)
	knet.stream_write(&w, &owner, &desc)
	knet.stream_ring_push(&ring, 2.0, knet.writer_bytes(&w), 0)

	remote := Mover{}
	// Inside one warp: ordinary interpolation.
	testing.expect(t, knet.stream_ring_sample(&ring, 1.5, &remote, &desc))
	testing.expect_value(t, remote.x, f32(5))

	// The owner TELEPORTS across the map (level change, respawn): same
	// stream, bumped warp counter. A warp is a CUT — the push FLUSHES the
	// buffered pre-warp timeline, so remote screens stop rendering the doomed
	// tail immediately instead of finishing it for a full interp delay while
	// the reliable channel's deltas have already moved the world on.
	owner.x = 500
	knet.writer_reset(&w)
	knet.stream_write(&w, &owner, &desc)
	knet.stream_ring_push(&ring, 3.0, knet.writer_bytes(&w), 1)

	// The old timeline is GONE: any render time now lands on the far side of
	// the jump — no slide through the void, and no lingering at the old spot.
	testing.expect(t, knet.stream_ring_sample(&ring, 1.5, &remote, &desc))
	testing.expect_value(t, remote.x, f32(500))
	testing.expect(t, knet.stream_ring_sample(&ring, 2.5, &remote, &desc))
	testing.expect_value(t, remote.x, f32(500))
	testing.expect(t, knet.stream_ring_sample(&ring, 3.0, &remote, &desc))
	testing.expect_value(t, remote.x, f32(500))

	// A straggler from BEFORE the jump (unreliable channel, reordered): its
	// stamp is older than the post-warp sample — dropped, never re-blended.
	owner.x = 20
	knet.writer_reset(&w)
	knet.stream_write(&w, &owner, &desc)
	knet.stream_ring_push(&ring, 2.5, knet.writer_bytes(&w), 0)
	testing.expect(t, knet.stream_ring_sample(&ring, 2.5, &remote, &desc))
	testing.expect_value(t, remote.x, f32(500))

	// THE OWNERSHIP-HANDOFF RACE: an old-owner packet with a NEWER ARRIVAL
	// STAMP but an OLDER WARP lands after the new owner's first sample (its
	// path was slower by ~an RTT). Older serial = doomed timeline: dropped —
	// a "different warp = flush" rule would wipe the good sample and snap
	// every screen backward, once per straggler.
	owner.x = 42
	knet.writer_reset(&w)
	knet.stream_write(&w, &owner, &desc)
	knet.stream_ring_push(&ring, 3.5, knet.writer_bytes(&w), 0) // warp 0 < warp 1: serial-older
	testing.expect(t, knet.stream_ring_sample(&ring, 3.5, &remote, &desc))
	testing.expect_value(t, remote.x, f32(500)) // the new timeline stands

	// EQUAL STAMPS across a warp (two packets pumped in one frame): the cut
	// must still win — warp is checked before the stale-stamp guard.
	owner.x = 900
	knet.writer_reset(&w)
	knet.stream_write(&w, &owner, &desc)
	knet.stream_ring_push(&ring, 3.0, knet.writer_bytes(&w), 2) // same stamp as warp-1 sample
	testing.expect(t, knet.stream_ring_sample(&ring, 3.0, &remote, &desc))
	testing.expect_value(t, remote.x, f32(900))

	// Serial wrap-around: 255 -> 0 is NEWER (u8 serial space), not older.
	ring2 := knet.Stream_Ring{}
	defer knet.stream_ring_destroy(&ring2)
	owner.x = 1
	knet.writer_reset(&w)
	knet.stream_write(&w, &owner, &desc)
	knet.stream_ring_push(&ring2, 1.0, knet.writer_bytes(&w), 255)
	owner.x = 2
	knet.writer_reset(&w)
	knet.stream_write(&w, &owner, &desc)
	knet.stream_ring_push(&ring2, 2.0, knet.writer_bytes(&w), 0)
	testing.expect(t, knet.stream_ring_sample(&ring2, 2.0, &remote, &desc))
	testing.expect_value(t, remote.x, f32(2))
}

@(test)
truth_and_revert_spare_owner_fields_on_the_owner :: proc(t: ^testing.T) {
	desc := mover_desc()
	// The host's "truth" snapshot of the OWNER's entity: its streamed x/y
	// are a lagged echo (the owner kept moving while the command flew).
	stale := Mover{hp = 40, x = 100, y = 100, face = 1}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_full(&w, &stale, &desc)

	// The owner, meanwhile, is HERE.
	me := Mover{hp = 65, x = 300, y = 250, face = 2}
	r := knet.reader_make(knet.writer_bytes(&w))
	knet.apply_full(&r, &me, &desc, skip_owner = true)
	testing.expect_value(t, me.hp, i32(40)) // host state: truth applies
	testing.expect_value(t, me.x, f32(300)) // owner state: MINE, untouched
	testing.expect_value(t, me.y, f32(250))
	testing.expect_value(t, me.face, u8(2))
	testing.expect(t, !r.err, "skipped fields still consume their bytes")

	// Same contract for the local revert (expiry path): the capture's x/y
	// are stale by the time it restores.
	snap := knet.fields_capture(&me, &desc, context.temp_allocator)
	me.hp = 1
	me.x = 999 // kept moving
	knet.fields_restore(&me, &desc, snap, skip_owner = true)
	testing.expect_value(t, me.hp, i32(40)) // reverted
	testing.expect_value(t, me.x, f32(999)) // mine, untouched
}

// ---- wire codecs: encodings exist only inside packets ------------------------

// The Walter case: a big deterministic structure both sides grow locally means
// the wire only needs an INDEX into it. Here: a 32-step angle table — the f32
// heading ships as one byte naming the nearest entry.
@(private = "file")
heading_table :: proc(i: u8) -> f32 {
	return f32(i) * (360.0 / 32.0)
}

@(private = "file")
heading_codec :: knet.Wire_Codec {
	size   = 1,
	encode = proc(wire, field: rawptr) {
		deg := (^f32)(field)^
		(^u8)(wire)^ = u8(int(deg / (360.0 / 32.0) + 0.5) % 32)
	},
	decode = proc(field, wire: rawptr) {
		(^f32)(field)^ = heading_table((^u8)(wire)^)
	},
}

Scout :: struct {
	hp:      i32, // raw
	px, py:  f32, // wire = .F16 (half floats on the wire, f32 in the struct)
	heading: f32, // wire = .Custom (index into the shared table)
	local:   int,
}

scout_desc :: proc() -> knet.Entity_Desc {
	@(static) fields := [?]knet.Field_Desc{
		{offset = offset_of(Scout, hp), size = size_of(i32)},
		{offset = offset_of(Scout, px), size = size_of(f32), wire = .F16},
		{offset = offset_of(Scout, py), size = size_of(f32), wire = .F16},
		{offset = offset_of(Scout, heading), size = size_of(f32), wire = .Custom, codec = heading_codec},
	}
	return knet.Entity_Desc{fields = fields[:]}
}

@(test)
wire_sizes_and_delta_roundtrip :: proc(t: ^testing.T) {
	desc := scout_desc()
	testing.expect_value(t, knet.desc_data_size(&desc), 16) // struct layout: 4+4+4+4
	testing.expect_value(t, knet.desc_wire_size(&desc), 9) // wire: 4+2+2+1
	testing.expect(t, knet.desc_has_wire(&desc))

	sender := Scout{hp = 42, px = 640.5, py = 128.25, heading = 90}
	shadow := knet.shadow_make(&desc)
	defer delete(shadow)

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	mask := knet.write_delta(&w, &sender, shadow, &desc)
	testing.expect_value(t, mask, u64(0b1111))
	// 1 mask byte + the WIRE bytes, not the struct bytes.
	testing.expect_value(t, len(knet.writer_bytes(&w)), 1 + 9)

	receiver := Scout{local = 7}
	r := knet.reader_make(knet.writer_bytes(&w))
	applied := knet.apply_delta(&r, &receiver, &desc)
	testing.expect(t, !r.err)
	testing.expect_value(t, applied, u64(0b1111))
	testing.expect_value(t, receiver.hp, i32(42))
	// f16 carries these magnitudes to well under half a pixel.
	testing.expect(t, abs(receiver.px - 640.5) < 0.5, "px survived the half-float trip")
	testing.expect(t, abs(receiver.py - 128.25) < 0.25, "py survived the half-float trip")
	// The codec decodes to an exact TABLE entry — the shared-structure contract.
	testing.expect_value(t, receiver.heading, heading_table(8)) // 90° = entry 8
	testing.expect_value(t, receiver.local, 7) // untouched, as ever

	// The shadow committed STRUCT bytes: the sender is idle on the next diff
	// even though its full-precision values differ from what receivers decoded.
	testing.expect_value(t, knet.diff_mask(&sender, shadow, &desc), u64(0))
}

@(test)
wire_full_snapshot_roundtrip :: proc(t: ^testing.T) {
	desc := scout_desc()
	src := Scout{hp = 9, px = 33, py = -12.5, heading = 180}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_full(&w, &src, &desc)
	testing.expect_value(t, len(knet.writer_bytes(&w)), 9) // wire size, no mask

	dst := Scout{}
	r := knet.reader_make(knet.writer_bytes(&w))
	knet.apply_full(&r, &dst, &desc)
	testing.expect(t, !r.err)
	testing.expect_value(t, dst.hp, i32(9))
	testing.expect(t, abs(dst.px - 33) < 0.1)
	testing.expect(t, abs(dst.py - -12.5) < 0.1)
	testing.expect_value(t, dst.heading, heading_table(16)) // 180° = entry 16
}

// Streamed fields with wire encodings: packets carry wire bytes, rings hold
// struct-layout bytes (decoded at the packet edge), blending never knows.
Glider :: struct {
	x, y:  f32, // owner-streamed, lerped, f16 on the wire
	local: int,
}

glider_desc :: proc() -> knet.Entity_Desc {
	@(static) fields := [?]knet.Field_Desc{
		{offset = offset_of(Glider, x), size = size_of(f32), flags = {.Interp, .Owner_Stream}, lerp = .F32, wire = .F16},
		{offset = offset_of(Glider, y), size = size_of(f32), flags = {.Interp, .Owner_Stream}, lerp = .F32, wire = .F16},
	}
	return knet.Entity_Desc{fields = fields[:]}
}

@(test)
wire_streams_decode_at_the_packet_edge :: proc(t: ^testing.T) {
	desc := glider_desc()
	testing.expect_value(t, knet.stream_data_size(&desc), 8) // ring blobs: struct layout
	testing.expect_value(t, knet.stream_wire_size(&desc), 4) // packets: half floats

	set := knet.Command_Set{entity_desc = &desc}
	owner_side := knet.registry_make()
	defer knet.registry_destroy(&owner_side)
	remote_side := knet.registry_make()
	defer knet.registry_destroy(&remote_side)

	me := knet.Player_Id(2)
	viewer := knet.Player_Id(3)
	mine := Glider{x = 100, y = 200}
	id := knet.registry_spawn(&owner_side, &mine, &set, me)
	theirs := Glider{local = 5}
	knet.registry_insert(&remote_side, id, &theirs, &set, me)

	// Two ticks of owner motion, shipped as two stream batches.
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	testing.expect_value(t, knet.registry_write_streams(&w, &owner_side, me, 1.0), 1)
	r := knet.reader_make(knet.writer_bytes(&w))
	stamp := knet.registry_stream_time(&r)
	testing.expect_value(t, knet.registry_apply_streams(&r, &remote_side, viewer, stamp), 1)

	mine.x = 110
	mine.y = 220
	knet.writer_reset(&w)
	testing.expect_value(t, knet.registry_write_streams(&w, &owner_side, me, 2.0), 1)
	r = knet.reader_make(knet.writer_bytes(&w))
	stamp = knet.registry_stream_time(&r)
	testing.expect_value(t, knet.registry_apply_streams(&r, &remote_side, viewer, stamp), 1)

	// Sampling midway lerps DECODED values — half-float precision, full blend.
	testing.expect_value(t, knet.registry_sample_streams(&remote_side, 1.5, viewer), 1)
	testing.expect(t, abs(theirs.x - 105) < 0.5, "x lerped between decoded samples")
	testing.expect(t, abs(theirs.y - 210) < 0.5, "y lerped between decoded samples")
	testing.expect_value(t, theirs.local, 5)
}

// ---- entity blobs: the variable-length escape hatch ---------------------------

@(test)
blob_set_apply_and_dedup :: proc(t: ^testing.T) {
	desc := probe_desc()
	set := knet.Command_Set{entity_desc = &desc}
	reg := knet.registry_make()
	defer knet.registry_destroy(&reg)

	e := Probe{hp = 1}
	id := knet.registry_spawn(&reg, &e, &set)

	data, ver := knet.registry_blob(&reg, id)
	testing.expect_value(t, len(data), 0)
	testing.expect_value(t, ver, u32(0)) // never set

	testing.expect(t, knet.registry_set_blob(&reg, id, []u8{0xCA, 0xFE}))
	data, ver = knet.registry_blob(&reg, id)
	testing.expect_value(t, ver, u32(1))
	testing.expect_value(t, len(data), 2)
	testing.expect_value(t, data[0], u8(0xCA))

	// Receiver side: a fresh version applies, a re-received one is dropped
	// (a rejoin re-receives the world — the game must not re-react).
	reg2 := knet.registry_make()
	defer knet.registry_destroy(&reg2)
	e2 := Probe{}
	knet.registry_insert(&reg2, id, &e2, &set)
	testing.expect(t, knet.registry_apply_blob(&reg2, id, ver, data))
	testing.expect(t, !knet.registry_apply_blob(&reg2, id, ver, data), "duplicate version must be dropped")
	got, gv := knet.registry_blob(&reg2, id)
	testing.expect_value(t, gv, u32(1))
	testing.expect_value(t, got[1], u8(0xFE))

	// Clearing: empty payload, version still moves (receivers hear about it).
	testing.expect(t, knet.registry_set_blob(&reg, id, nil))
	data, ver = knet.registry_blob(&reg, id)
	testing.expect_value(t, len(data), 0)
	testing.expect_value(t, ver, u32(2))

	// Unknown ids refuse politely.
	testing.expect(t, !knet.registry_set_blob(&reg, knet.Net_Id(999), []u8{1}))
}

// ---- later: presenting on the render timeline ---------------------------------

@(private = "file")
Later_Log :: struct {
	calls: [dynamic]u64,
}

@(private = "file")
log_call :: proc(user: rawptr, id: knet.Net_Id, a: u64) {
	l := cast(^Later_Log)user
	append(&l.calls, u64(id) * 100 + a)
}

@(test)
later_runs_handlers_in_order_when_due :: proc(t: ^testing.T) {
	l: knet.Later
	defer knet.later_destroy(&l)
	log: Later_Log
	defer delete(log.calls)

	knet.later_push(&l, 10.0, &log, log_call, knet.Net_Id(7), 1)
	knet.later_push(&l, 10.0, &log, log_call, knet.Net_Id(7), 2) // same due: push order holds
	knet.later_push(&l, 12.0, &log, log_call, knet.Net_Id(8), 3)

	testing.expect_value(t, knet.later_drain(&l, 9.99), 0)
	testing.expect_value(t, knet.later_pending(&l), 3)

	testing.expect_value(t, knet.later_drain(&l, 10.0), 2)
	testing.expect_value(t, len(log.calls), 2)
	testing.expect_value(t, log.calls[0], u64(701))
	testing.expect_value(t, log.calls[1], u64(702))
	testing.expect_value(t, knet.later_pending(&l), 1)

	// A level change drops the pending world's effects wholesale.
	knet.later_clear(&l)
	testing.expect_value(t, knet.later_drain(&l, 99.0), 0)
}
