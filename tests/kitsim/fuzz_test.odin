package kit_sim_test

// Deterministic property corpus for the simulation's two allocation-bearing
// decoders: input windows and snapshot batches.

import "core:testing"
import knet "godot:kit/net"
import ksim "godot:kit/sim"

@(private = "file")
sim_fuzz_next :: proc(s: ^u64) -> u64 {
	x := s^
	x ~= x << 13
	x ~= x >> 7
	x ~= x << 17
	s^ = x
	return x
}

@(test)
input_window_decoder_rejects_every_strict_prefix :: proc(t: ^testing.T) {
	ring := ksim.input_ring_make(2, 32)
	defer ksim.input_ring_destroy(&ring)
	for tick in u64(1) ..= 16 {
		input := [2]u8{u8(tick), u8(tick * 3)}
		ksim.input_note(&ring, tick, &input)
	}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	_ = ksim.input_write(&w, &ring, 0, 16)
	packet := knet.writer_bytes(&w)
	for cut in 0 ..< len(packet) {
		buf := ksim.input_buffer_make(2, 32)
		r := knet.reader_make(packet[:cut])
		testing.expect_value(t, ksim.input_buffer_apply(&buf, &r), 0)
		testing.expect(t, r.err)
		testing.expect_value(t, buf.newest, u64(0))
		ksim.input_buffer_destroy(&buf)
	}
}

@(test)
snapshot_decoder_is_atomic_under_truncation_and_mutation :: proc(t: ^testing.T) {
	desc := mover_desc()
	server := Mover {
		x  = 33,
		vx = 4,
	}
	hist := ksim.history_make(&desc, 32)
	defer ksim.history_destroy(&hist)
	entries := []ksim.Entry{{id = 1, entity = &server, hist = &hist}}
	ksim.note_all(entries, 1)
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	_ = ksim.snap_write(&w, entries, 1, 0, 9)
	packet := knet.writer_bytes(&w)

	for cut in 0 ..< len(packet) {
		rx := ksim.snap_rx_make(32)
		ksim.snap_rx_add(&rx, 1, &desc)
		truths := make([dynamic]ksim.Truth)
		r := knet.reader_make(packet[:cut])
		tick, ack, applied := ksim.snap_rx_apply(&rx, &r, &truths)
		testing.expect_value(t, tick, u64(0))
		testing.expect_value(t, ack, u64(0))
		testing.expect_value(t, applied, 0)
		testing.expect(t, r.err)
		testing.expect_value(t, rx.newest, u64(0))
		testing.expect_value(t, rx.acked, u64(0))
		testing.expect_value(t, len(truths), 0)
		delete(truths)
		ksim.snap_rx_destroy(&rx)
	}

	seed := u64(0x51A5F00DCAFE)
	mut := make([]u8, len(packet))
	defer delete(mut)
	for _ in 0 ..< 512 {
		copy(mut, packet)
		at := int(sim_fuzz_next(&seed) % u64(len(mut)))
		mut[at] ~= u8(1 << uint(sim_fuzz_next(&seed) % 8))
		rx := ksim.snap_rx_make(32)
		ksim.snap_rx_add(&rx, 1, &desc)
		truths := make([dynamic]ksim.Truth)
		r := knet.reader_make(mut)
		_, _, _ = ksim.snap_rx_apply(&rx, &r, &truths)
		if r.err {
			testing.expect_value(t, rx.newest, u64(0))
			testing.expect_value(t, rx.acked, u64(0))
			testing.expect_value(t, len(truths), 0)
		}
		delete(truths)
		ksim.snap_rx_destroy(&rx)
	}
}

@(test)
snapshot_ack_is_monotonic_and_replay_is_deterministic :: proc(t: ^testing.T) {
	desc := mover_desc()
	server := Mover{}
	hist := ksim.history_make(&desc, 128)
	defer ksim.history_destroy(&hist)
	entries := []ksim.Entry{{id = 7, entity = &server, hist = &hist}}
	a := ksim.snap_rx_make(128)
	b := ksim.snap_rx_make(128)
	defer ksim.snap_rx_destroy(&a)
	defer ksim.snap_rx_destroy(&b)
	ksim.snap_rx_add(&a, 7, &desc)
	ksim.snap_rx_add(&b, 7, &desc)
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	prev_ack := u64(0)
	receivers := []^ksim.Snap_Rx{&a, &b}
	for tick in u64(1) ..= 96 {
		server.x = f32(tick * 2)
		server.vx = f32(tick % 7)
		ksim.note_all(entries, tick)
		knet.writer_reset(&w)
		_ = ksim.snap_write(&w, entries, tick, 0, tick - 1)
		for rx in receivers {
			truths := make([dynamic]ksim.Truth)
			r := knet.reader_make(knet.writer_bytes(&w))
			got, _, applied := ksim.snap_rx_apply(rx, &r, &truths)
			testing.expect_value(t, got, tick)
			testing.expect_value(t, applied, 1)
			delete(truths)
			// Reliable duplicates/out-of-order replays are superseded and cannot
			// move either acknowledgement cursor backwards.
			r = knet.reader_make(knet.writer_bytes(&w))
			got, _, _ = ksim.snap_rx_apply(rx, &r, nil)
			testing.expect_value(t, got, u64(0))
		}
		testing.expect(t, a.acked >= prev_ack)
		testing.expect_value(t, a.acked, b.acked)
		testing.expect_value(t, a.newest, b.newest)
		prev_ack = a.acked
	}
}
