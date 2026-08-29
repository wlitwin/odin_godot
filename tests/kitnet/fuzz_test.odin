package kit_net_test

// Deterministic fuzz/property corpus for the pure wire and replication
// decoders. No external fuzzer runtime is required, so these invariants run on
// every normal test invocation (including wasm/cross builds that compile it).

import "core:testing"
import knet "godot:kit/net"

@(private = "file")
fuzz_next :: proc(s: ^u64) -> u64 {
	x := s^
	x ~= x << 13
	x ~= x >> 7
	x ~= x << 17
	s^ = x
	return x
}

@(test)
wire_decoder_fuzz_properties :: proc(t: ^testing.T) {
	seed := u64(0xC0DEC0FFEE123456)
	buf: [256]u8
	for _ in 0 ..< 1024 {
		n := int(fuzz_next(&seed) % len(buf))
		for i in 0 ..< n {
			buf[i] = u8(fuzz_next(&seed))
		}
		r := knet.reader_make(buf[:n])
		for _ in 0 ..< 24 {
			switch fuzz_next(&seed) % 10 {
			case 0:
				_ = knet.read_u8(&r)
			case 1:
				_ = knet.read_u16(&r)
			case 2:
				_ = knet.read_u32(&r)
			case 3:
				_ = knet.read_u64(&r)
			case 4:
				_ = knet.read_bool(&r)
			case 5:
				_ = knet.read_string_limited(&r, 32)
			case 6:
				_ = knet.read_bytes_limited(&r, 64)
			case 7:
				_ = knet.reader_view(&r, int(fuzz_next(&seed) % 96))
			case 8:
				_ = knet.reader_admit_count(&r, int(fuzz_next(&seed) % 5000), 3)
			case 9:
				_ = knet.reader_remaining(&r)
			}
			testing.expect(
				t,
				r.off >= 0 && r.off <= len(r.data),
				"a fuzzed reader cursor always stays inside its slice",
			)
			if r.err {
				off := r.off
				_ = knet.read_u64(&r)
				testing.expect_value(t, r.off, off) // sticky failure does no more work
				break
			}
		}
	}

	too_big := make([]u8, knet.MAX_PACKET_BYTES + 1)
	defer delete(too_big)
	r := knet.reader_make(too_big)
	testing.expect(t, !knet.reader_admit_packet(&r), "whole packets are refused before dispatch")
	testing.expect(t, r.err)

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u32(&w, u32(knet.MAX_FIELD_BYTES + 1))
	r = knet.reader_make(knet.writer_bytes(&w))
	_ = knet.read_bytes(&r)
	testing.expect(t, r.err, "a representable u32 length still obeys the semantic field ceiling")
}

@(test)
registry_decoder_truncation_and_mutation_properties :: proc(t: ^testing.T) {
	desc := probe_desc()
	set := knet.Command_Set {
		entity_desc = &desc,
	}
	host := Probe {
		hp    = 81,
		x     = 4,
		y     = 9,
		state = 3,
	}
	client := Probe {
		hp         = -7,
		x          = -2,
		y          = -3,
		state      = 6,
		local_only = 99,
	}

	sreg := knet.registry_make()
	defer knet.registry_destroy(&sreg)
	id := knet.registry_spawn(&sreg, &host, &set)
	creg := knet.registry_make()
	defer knet.registry_destroy(&creg)
	knet.registry_insert(&creg, id, &client, &set)

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	testing.expect_value(t, knet.registry_write_deltas(&w, &sreg), 1)
	packet := knet.writer_bytes(&w)
	before := client
	for cut in 0 ..< len(packet) {
		client = before
		r := knet.reader_make(packet[:cut])
		testing.expect_value(t, knet.registry_apply_deltas(&r, &creg), 0)
		testing.expect(t, r.err, "every strict prefix of a delta packet is malformed")
		testing.expect_value(t, client, before)
	}

	// Byte mutations are deterministic and bounded. Any mutation diagnosed as
	// malformed must leave the complete entity untouched; mutations that remain
	// a valid packet may, correctly, decode to another value.
	seed := u64(0x5EED5EED1234)
	mut := make([]u8, len(packet))
	defer delete(mut)
	for _ in 0 ..< 512 {
		copy(mut, packet)
		at := int(fuzz_next(&seed) % u64(len(mut)))
		mut[at] ~= u8(1 << uint(fuzz_next(&seed) % 8))
		client = before
		r := knet.reader_make(mut)
		_ = knet.registry_apply_deltas(&r, &creg)
		if r.err {
			testing.expect_value(t, client, before)
		}
	}
}

@(test)
dedup_state_machine_is_monotonic_and_deterministic :: proc(t: ^testing.T) {
	a, b: knet.Dedup_Window
	seed := u64(0xD3D0BEEF9876)
	prev_latest := knet.Intent_Seq(0)
	for _ in 0 ..< 4096 {
		seq := knet.Intent_Seq(u32(fuzz_next(&seed) % 600))
		aa := knet.dedup_accept(&a, seq)
		bb := knet.dedup_accept(&b, seq)
		testing.expect_value(t, aa, bb)
		testing.expect_value(t, a, b)
		testing.expect(
			t,
			a.latest >= prev_latest,
			"dedup acknowledgement state never moves backwards",
		)
		prev_latest = a.latest
	}
}
