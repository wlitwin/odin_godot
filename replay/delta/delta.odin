package replay_delta

import "base:intrinsics"

// Sparse XOR runs over equal-size canonical values. Format (little-endian):
// run_count:u16, then (offset:u16, size:u16, nonzero XOR bytes) per run.
// Runs are ordered and non-overlapping. Both encoding and decoding preflight
// completely before writing output. This codec allocates no memory.
encode :: proc(base, target, dst: []u8) -> (size: int, ok: bool) {
 return encode_runs(base,target,dst,len(dst),true)
}

// Writes the exact sparse encoding only when it fits the budget and destination.
// Unlike encode, failure returns no required-size estimate: scanning may stop as
// soon as the candidate cannot win. Failure never changes the destination.
encode_bounded :: proc(base,target,dst:[]u8,budget:int)->(size:int,ok:bool) {
 if budget<0 || overlaps(dst,base) || overlaps(dst,target) {return}
 return encode_runs(base,target,dst,min(budget,len(dst)),false)
}

@(private)
encode_runs :: proc(base,target,dst:[]u8,budget:int,$Exact:bool)->(size:int,ok:bool) {
 when !Exact {if budget<2 {return}}
	if len(base) != len(target) || len(base) > 65535 {return 0, false}
	needed, runs := 2, 0
	for i := 0; i < len(base); {
		// Keep short/fragmented runs on the byte path. Once an equal prefix
		// spans two bytes, skip full equal words, then finish its boundary once.
		if base[i] == target[i] {
			i += 1
			if i < len(base) && base[i] == target[i] {
				for len(base) - i >= 8 {
					changed := intrinsics.unaligned_load(cast(^u64)&base[i]) ~ intrinsics.unaligned_load(cast(^u64)&target[i])
					if changed != 0 {
						when ODIN_ENDIAN == .Little {
							i += int(intrinsics.count_trailing_zeros(changed) / 8)
						} else {
							i += int(intrinsics.count_leading_zeros(changed) / 8)
						}
						break
					}
					i += 8
				}
				for i < len(base) && base[i] == target[i] {i += 1}
			}
			if i == len(base) {break}
		}
		start := i
		for i < len(base) && base[i] != target[i] {i += 1}
		needed += 4 + i - start
		runs += 1
		when !Exact {if needed>budget {return}}
	}
	if needed > len(dst) || runs > 65535 {return needed, false}
	put16(dst[:2], u16(runs))
	cursor := 2
	for i := 0; i < len(base); {
		// Keep short/fragmented runs on the byte path. Once an equal prefix
		// spans two bytes, skip full equal words, then finish its boundary once.
		if base[i] == target[i] {
			i += 1
			if i < len(base) && base[i] == target[i] {
				for len(base) - i >= 8 {
					changed := intrinsics.unaligned_load(cast(^u64)&base[i]) ~ intrinsics.unaligned_load(cast(^u64)&target[i])
					if changed != 0 {
						when ODIN_ENDIAN == .Little {
							i += int(intrinsics.count_trailing_zeros(changed) / 8)
						} else {
							i += int(intrinsics.count_leading_zeros(changed) / 8)
						}
						break
					}
					i += 8
				}
				for i < len(base) && base[i] == target[i] {i += 1}
			}
			if i == len(base) {break}
		}
		start := i
		for i < len(base) && base[i] != target[i] {i += 1}
		put16(dst[cursor:cursor + 2], u16(start))
		put16(dst[cursor + 2:cursor + 4], u16(i - start))
		cursor += 4
		for j in start ..< i {dst[cursor] = base[j] ~ target[j]; cursor += 1}
	}
	return needed, true
}

apply :: proc(base, encoded, dst: []u8) -> bool {
	if len(dst) != len(base) || len(base) > 65535 || len(encoded) < 2 {return false}
	runs := int(get16(encoded[:2]))
	cursor, end := 2, 0
	for _ in 0 ..< runs {
		if len(encoded) - cursor < 4 {return false}
		offset, size := int(get16(encoded[cursor:cursor + 2])), int(get16(encoded[cursor + 2:cursor + 4]))
		cursor += 4
		if size == 0 || offset < end || offset > len(base) || size > len(base) - offset || size > len(encoded) - cursor {return false}
		for b in encoded[cursor:cursor + size] {if b == 0 {return false}}
		cursor += size
		end = offset + size
	}
	if cursor != len(encoded) {return false}
	copy(dst, base)
	cursor = 2
	for _ in 0 ..< runs {
		offset, size := int(get16(encoded[cursor:cursor + 2])), int(get16(encoded[cursor + 2:cursor + 4]))
		cursor += 4
		for i in 0 ..< size {dst[offset + i] ~= encoded[cursor + i]}
		cursor += size
	}
	return true
}

@(private)
put16 :: proc(dst: []u8, value: u16) {dst[0], dst[1] = u8(value), u8(value >> 8)}
@(private)
get16 :: proc(src: []u8) -> u16 {return u16(src[0]) | u16(src[1]) << 8}
