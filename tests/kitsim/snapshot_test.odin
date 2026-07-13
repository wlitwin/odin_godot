package kit_sim_test

// The snapshot lane: baseline-delta batches, the fully-applied ack rule, and
// the whole sim-lane conversation under loss — client and server driven in
// one process, packets as byte slices, losses injected by iteration. The
// last test here is the lane's acid: a 10-iteration input blackout (beyond
// the redundancy window, so the server genuinely holds-last and diverges)
// plus periodic snapshot loss, converging to byte-identical ledgers and a
// zero-resim steady state.

import "core:mem"
import "core:testing"
import knet "godot:kit/net"
import ksim "godot:kit/sim"

@(test)
snap_full_then_delta_roundtrip :: proc(t: ^testing.T) {
	desc := mover_desc()

	// Server: two movers, truth ledgers, tick 1 noted.
	s1 := Mover{x = 10, vx = 1}
	s2 := Mover{x = 20, vx = 2}
	h1 := ksim.history_make(&desc, 16)
	defer ksim.history_destroy(&h1)
	h2 := ksim.history_make(&desc, 16)
	defer ksim.history_destroy(&h2)
	entries := []ksim.Entry{{id = 1, entity = &s1, hist = &h1}, {id = 2, entity = &s2, hist = &h2}}
	ksim.note_all(entries, 1)

	rx := ksim.snap_rx_make(16)
	defer ksim.snap_rx_destroy(&rx)
	ksim.snap_rx_add(&rx, 1, &desc)
	ksim.snap_rx_add(&rx, 2, &desc)

	// Nothing acked: both rows ship full.
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	testing.expect_value(t, ksim.snap_write(&w, entries, 1, 0, 77), 2)

	truths := make([dynamic]ksim.Truth)
	defer delete(truths)
	r := knet.reader_make(knet.writer_bytes(&w))
	tick, input_ack, applied := ksim.snap_rx_apply(&rx, &r, &truths)
	testing.expect_value(t, tick, 1)
	testing.expect_value(t, input_ack, 77)
	testing.expect_value(t, applied, 2)
	testing.expect_value(t, rx.acked, 1) // every row landed → valid baseline
	full_len := len(knet.writer_bytes(&w))

	// One field of one entity moves; the next batch deltas against tick 1.
	s1.x = 11
	ksim.note_all(entries, 2)
	knet.writer_reset(&w)
	testing.expect_value(t, ksim.snap_write(&w, entries, 2, rx.acked, 78), 2)
	testing.expect(t, len(knet.writer_bytes(&w)) < full_len, "deltas beat fulls on the wire")

	clear(&truths)
	r = knet.reader_make(knet.writer_bytes(&w))
	tick, _, applied = ksim.snap_rx_apply(&rx, &r, &truths)
	testing.expect_value(t, tick, 2)
	testing.expect_value(t, applied, 2)
	testing.expect_value(t, rx.acked, 2)
	testing.expect_value(t, len(truths), 2)

	// The truths decode to the server's exact struct bytes.
	check := Mover{}
	for tr in truths {
		ksim.predict_restore(&check, &desc, tr.blob)
		if tr.id == 1 {
			testing.expect_value(t, check.x, 11)
			testing.expect_value(t, check.vx, 1)
		} else {
			testing.expect_value(t, check.x, 20)
			testing.expect_value(t, check.vx, 2)
		}
	}
}

@(test)
snap_unknown_id_stalls_ack :: proc(t: ^testing.T) {
	desc := mover_desc()
	s1 := Mover{x = 1}
	s2 := Mover{x = 2}
	h1 := ksim.history_make(&desc, 16)
	defer ksim.history_destroy(&h1)
	h2 := ksim.history_make(&desc, 16)
	defer ksim.history_destroy(&h2)
	entries := []ksim.Entry{{id = 1, entity = &s1, hist = &h1}, {id = 2, entity = &s2, hist = &h2}}
	ksim.note_all(entries, 1)

	// The client only knows entity 1 — entity 2's spawn is still in flight.
	rx := ksim.snap_rx_make(16)
	defer ksim.snap_rx_destroy(&rx)
	ksim.snap_rx_add(&rx, 1, &desc)

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	ksim.snap_write(&w, entries, 1, 0, 0)
	truths := make([dynamic]ksim.Truth)
	defer delete(truths)
	r := knet.reader_make(knet.writer_bytes(&w))
	tick, _, applied := ksim.snap_rx_apply(&rx, &r, &truths)
	testing.expect_value(t, tick, 1)
	testing.expect_value(t, applied, 1) // the known row lands
	testing.expect_value(t, rx.newest, 1)
	testing.expect_value(t, rx.acked, 0) // but a skipped row must stall the ack

	// The spawn arrives; the server (still seeing acked=0) ships fulls; the
	// ack advances again — self-healing, no request message.
	ksim.snap_rx_add(&rx, 2, &desc)
	ksim.note_all(entries, 2)
	knet.writer_reset(&w)
	ksim.snap_write(&w, entries, 2, rx.acked, 0)
	clear(&truths)
	r = knet.reader_make(knet.writer_bytes(&w))
	tick, _, applied = ksim.snap_rx_apply(&rx, &r, &truths)
	testing.expect_value(t, tick, 2)
	testing.expect_value(t, applied, 2)
	testing.expect_value(t, rx.acked, 2)
}

@(test)
snap_stale_and_duplicate_drop :: proc(t: ^testing.T) {
	desc := mover_desc()
	s := Mover{x = 5}
	h := ksim.history_make(&desc, 16)
	defer ksim.history_destroy(&h)
	entries := []ksim.Entry{{id = 1, entity = &s, hist = &h}}
	ksim.note_all(entries, 1)
	ksim.note_all(entries, 2)

	rx := ksim.snap_rx_make(16)
	defer ksim.snap_rx_destroy(&rx)
	ksim.snap_rx_add(&rx, 1, &desc)

	old := knet.writer_make()
	defer knet.writer_destroy(&old)
	ksim.snap_write(&old, entries, 1, 0, 0)
	newer := knet.writer_make()
	defer knet.writer_destroy(&newer)
	ksim.snap_write(&newer, entries, 2, 0, 0)

	truths := make([dynamic]ksim.Truth)
	defer delete(truths)
	r := knet.reader_make(knet.writer_bytes(&newer))
	tick, _, _ := ksim.snap_rx_apply(&rx, &r, &truths)
	testing.expect_value(t, tick, 2)

	// The reordered older batch and a duplicate of the applied one: both
	// superseded, both dropped whole.
	r = knet.reader_make(knet.writer_bytes(&old))
	tick, _, _ = ksim.snap_rx_apply(&rx, &r, &truths)
	testing.expect_value(t, tick, 0)
	r = knet.reader_make(knet.writer_bytes(&newer))
	tick, _, _ = ksim.snap_rx_apply(&rx, &r, &truths)
	testing.expect_value(t, tick, 0)
}

// A predicted field with a wire re-encoding: the batch carries f16 bytes,
// the ledgers hold decoded struct bytes on both sides — which is exactly
// why the server's delta mask and the client's baseline agree.
Probe16 :: struct {
	x:  f32,
	hp: i32,
}

probe16_desc :: proc() -> knet.Entity_Desc {
	@(static) fields := [?]knet.Field_Desc{
		{offset = offset_of(Probe16, x), size = size_of(f32), flags = {.Predicted}, wire = .F16},
		{offset = offset_of(Probe16, hp), size = size_of(i32)},
	}
	return knet.Entity_Desc{fields = fields[:]}
}

@(test)
snap_wire_codec_rides_the_lane :: proc(t: ^testing.T) {
	desc := probe16_desc()
	testing.expect_value(t, ksim.predict_size(&desc), 4)
	testing.expect_value(t, ksim.predict_wire_size(&desc), 2)

	s := Probe16{x = 100.5} // exactly representable in f16
	h := ksim.history_make(&desc, 8)
	defer ksim.history_destroy(&h)
	entries := []ksim.Entry{{id = 9, entity = &s, hist = &h}}
	ksim.note_all(entries, 1)

	rx := ksim.snap_rx_make(8)
	defer ksim.snap_rx_destroy(&rx)
	ksim.snap_rx_add(&rx, 9, &desc)

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	ksim.snap_write(&w, entries, 1, 0, 0)
	truths := make([dynamic]ksim.Truth)
	defer delete(truths)
	r := knet.reader_make(knet.writer_bytes(&w))
	_, _, applied := ksim.snap_rx_apply(&rx, &r, &truths)
	testing.expect_value(t, applied, 1)

	c := Probe16{}
	ksim.predict_restore(&c, &desc, truths[0].blob)
	testing.expect_value(t, c.x, 100.5)

	// And the delta path: one dirty f16 field = 1 mask byte + 2 wire bytes.
	s.x = 101.5
	ksim.note_all(entries, 2)
	knet.writer_reset(&w)
	ksim.snap_write(&w, entries, 2, rx.acked, 0)
	clear(&truths)
	r = knet.reader_make(knet.writer_bytes(&w))
	_, _, applied = ksim.snap_rx_apply(&rx, &r, &truths)
	testing.expect_value(t, applied, 1)
	ksim.predict_restore(&c, &desc, truths[0].blob)
	testing.expect_value(t, c.x, 101.5)
}

// ---- the lane's acid: converge through loss ----------------------------------

// Per-tick intent: mostly forward, a hard brake every fifth tick — enough
// variety that a held-last input genuinely diverges from the real one.
loop_ax :: proc(tick: u64) -> i8 {
	return tick % 5 == 0 ? -2 : 1
}

@(test)
sim_lane_converges_through_loss :: proc(t: ^testing.T) {
	desc := mover_desc()
	LEAD :: 3 // client runs 3 ticks ahead; the input for tick T ships from iteration T-3
	TICKS :: 60

	// Server.
	s := Mover{}
	hs := ksim.history_make(&desc, 64)
	defer ksim.history_destroy(&hs)
	entries_s := []ksim.Entry{{id = 1, entity = &s, hist = &hs}}
	buf := ksim.input_buffer_make(1, 64)
	defer ksim.input_buffer_destroy(&buf)
	acked_at_server := u64(0) // newest snap tick the client confirmed (from its ack)

	// Client.
	c := Mover{}
	hc := ksim.history_make(&desc, 64)
	defer ksim.history_destroy(&hc)
	entries_c := []ksim.Entry{{id = 1, entity = &c, hist = &hc}}
	ring := ksim.input_ring_make(1, 64)
	defer ksim.input_ring_destroy(&ring)
	rx := ksim.snap_rx_make(64)
	defer ksim.snap_rx_destroy(&rx)
	ksim.snap_rx_add(&rx, 1, &desc)
	world := Test_World{mover = &c, ring = &ring}
	input_ack_client := u64(0) // newest input tick the server confirmed (from batch headers)

	client_tick :: proc(ct: u64, c: ^Mover, ring: ^ksim.Input_Ring, entries: []ksim.Entry) {
		ax := loop_ax(ct)
		ksim.input_note(ring, ct, &ax)
		mover_step(c, ax)
		ksim.note_all(entries, ct)
	}

	// The client's head start.
	for ct in u64(1) ..= LEAD {
		client_tick(ct, &c, &ring, entries_c)
	}

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	truths := make([dynamic]ksim.Truth)
	defer delete(truths)
	total_resim, late_resim, held := 0, 0, u64(0)

	for st in u64(1) ..= TICKS {
		ct := st + LEAD
		client_tick(ct, &c, &ring, entries_c)

		// client → server: [input window][snap ack]. Iterations 20..29 black
		// out — ten in a row, wider than the 8-deep redundancy window, so
		// some inputs are genuinely unrecoverable and the server must hold.
		knet.writer_reset(&w)
		ksim.input_write(&w, &ring, acked = input_ack_client)
		ksim.snap_ack_write(&w, &rx)
		if !(st >= 20 && st < 30) {
			r := knet.reader_make(knet.writer_bytes(&w))
			ksim.input_buffer_apply(&buf, &r)
			acked_at_server = ksim.snap_ack_read(&r)
			testing.expect(t, !r.err, "composed packet parses whole")
		}

		// Server simulates its tick from whatever it has.
		in_bytes, fresh := ksim.input_buffer_pop(&buf, st)
		if !fresh {
			held += 1
		}
		mover_step(&s, transmute(i8)in_bytes[0])
		ksim.note_all(entries_s, st)

		// server → client: a batch every other tick, some lost early on.
		if st % 2 == 0 {
			knet.writer_reset(&w)
			ksim.snap_write(&w, entries_s, st, acked_at_server, buf.newest)
			if !(st % 10 == 0 && st < 40) {
				clear(&truths)
				r := knet.reader_make(knet.writer_bytes(&w))
				tick, iack, _ := ksim.snap_rx_apply(&rx, &r, &truths)
				if tick != 0 {
					input_ack_client = iack
					n := ksim.reconcile(entries_c, truths[:], tick, ct, &world, world_resim)
					total_resim += n
					if st > 50 {
						late_resim += n
					}
				}
			}
		}
	}

	// The blackout really exercised hold-last, and the divergence really
	// forced replays.
	testing.expect(t, held > 0, "the blackout must out-run redundancy")
	testing.expect(t, total_resim > 0, "held inputs must diverge and reconcile")

	// Steady state after the weather clears: reconciles are pure memcmp.
	testing.expect_value(t, late_resim, 0)

	// Convergence, byte-exact: at the last acked snapshot tick, the client's
	// PREDICTION ledger equals the server's truth ledger.
	final := rx.acked
	testing.expect(t, final > 50, "acks kept flowing to the end")
	cb, cok := ksim.history_read(&hc, final)
	sb, sok := ksim.history_read(&hs, final)
	testing.expect(t, cok && sok, "both ledgers hold the final acked tick")
	testing.expect(t, mem.compare(cb, sb) == 0, "client prediction == server truth, byte for byte")
}
