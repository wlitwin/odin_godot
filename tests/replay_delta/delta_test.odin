package replay_delta_test

import "core:mem"
import "core:testing"
import d "godot:replay/delta"
import r "godot:replay"
import sc "godot:replay/schema"

@(test)
prehashed_cache_keeps_copy_ownership_and_duplicate_identity_checks :: proc(t:^testing.T) {
	c:d.Cache;testing.expect(t,d.cache_init(&c,4,2));defer d.cache_destroy(&c)
	bytes:=[4]u8{1,2,3,4};digest:=sc.digest(bytes[:])
	testing.expect(t,d.cache_note_prehashed(&c,1,bytes[:],digest))
	stored,hash,found:=d.cache_find(&c,1);testing.expect(t,found);testing.expect_value(t,hash,digest)
	testing.expect(t,!d.cache_note_prehashed(&c,1,bytes[:],digest~1))
	bytes[0]=9;testing.expect_value(t,stored[0],u8(1))
	// Even a supplied matching digest cannot redefine an existing ID's bytes.
	testing.expect(t,!d.cache_note_prehashed(&c,1,bytes[:],digest))
	testing.expect(t,d.cache_note_prehashed(&c,2,bytes[:],sc.digest(bytes[:])))
}

@(test)
sparse_runs_roundtrip_and_dense_fallback_size_is_honest :: proc(t: ^testing.T) {
	base, target, restored: [1024]u8
	target[3], target[4], target[800] = 1, 2, 3
	encoded: [2048]u8
	n, ok := d.encode(base[:], target[:], encoded[:])
	testing.expect(t, ok && n == 13)
	testing.expect(t, d.apply(base[:], encoded[:n], restored[:]))
	testing.expect_value(t, restored, target)
	for &b in target {b = 255}
	n, ok = d.encode(base[:], target[:], encoded[:])
	testing.expect(t, ok && n > len(target)) // sender chooses the full value
	before := encoded
	_, ok = d.encode(base[:], target[:], encoded[:10])
	testing.expect(t, !ok)
	testing.expect_value(t, encoded, before)
}

@(test)
every_truncation_and_invalid_run_leaves_destination_unchanged :: proc(t: ^testing.T) {
	base, target: [64]u8
	target[4], target[5], target[40] = 3, 7, 9
	encoded: [128]u8
	n, _ := d.encode(base[:], target[:], encoded[:])
	for cut in 0 ..< n {
		dst: [64]u8
		for &b in dst {b = 0xaa}
		before := dst
		testing.expect(t, !d.apply(base[:], encoded[:cut], dst[:]))
		testing.expect_value(t, dst, before)
	}
	mutations := [?][2]int{{2, 63}, {4, 255}, {6, 0}, {8, 0}}
	for mutation in mutations {
		copy := encoded
		copy[mutation[0]] = u8(mutation[1])
		dst := base
		testing.expect(t, !d.apply(base[:], copy[:n], dst[:]))
		testing.expect_value(t, dst, base)
	}
}

@(test)
randomized_byte_corpus_roundtrips :: proc(t: ^testing.T) {
	rng := r.rng_make(42)
	base, target, dst: [512]u8
	encoded: [4096]u8
	for _ in 0 ..< 300 {
		for &b in base {b = u8(r.rng_next(&rng))}
		target = base
		for _ in 0 ..< 64 {target[r.rng_next(&rng) % 512] = u8(r.rng_next(&rng))}
		n, ok := d.encode(base[:], target[:], encoded[:])
		testing.expect(t, ok)
		testing.expect(t, d.apply(base[:], encoded[:n], dst[:]))
		testing.expect_value(t, dst, target)
	}
}

@(test)
cache_owns_values_and_does_not_alias_evicted_snapshots :: proc(t: ^testing.T) {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	c: d.Cache
	testing.expect(t, d.cache_init(&c, 2, 2, mem.tracking_allocator(&track)))
	bytes := [2]u8{1, 2}
	testing.expect(t, d.cache_note(&c, 1, bytes[:]))
	bytes[0] = 8
	stored, _, ok := d.cache_find(&c, 1)
	testing.expect(t, ok && stored[0] == 1)
	testing.expect(t, !d.cache_note(&c, 1, bytes[:]))
	d.cache_note(&c, 2, bytes[:])
	d.cache_note(&c, 3, bytes[:])
	_, _, ok = d.cache_find(&c, 1)
	testing.expect(t, !ok)
	d.cache_clear(&c)
	_, _, ok = d.cache_find(&c, 3)
	testing.expect(t, !ok)
	d.cache_destroy(&c)
	testing.expect_value(t, track.current_memory_allocated, i64(0))
}
