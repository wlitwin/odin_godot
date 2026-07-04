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
	responded, ok := knet.registry_host_command(&sreg, &hctx, 7, &rr, &result)
	testing.expect(t, responded && ok)
	testing.expect_value(t, host.hp, i32(15))
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
	responded2, _ := knet.registry_host_command(&sreg, &hctx, 7, &rr2, &result)
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
