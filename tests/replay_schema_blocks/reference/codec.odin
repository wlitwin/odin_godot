package schema_block_reference

// All field reads/writes use bytes so packed/unaligned fields work on every
// target. The wire is little-endian regardless of target or endian-qualified type.

encode :: proc(s: ^Schema, value: $T, dst: []u8) -> Report {
	if !s.ready {return {error = .Not_Ready}}
	if s.type != T {return {error = .Wrong_Type}}
	if len(dst) < s.wire_size {return {error = .Wrong_Size}}
	local := value
	bytes := (cast([^]u8)&local)[:size_of(T)]
	if report:=validate_fields(s,bytes,false);report.error!=.None {return report}
	if len(s.unions)>0 {encode_union_fields(s,bytes,dst);return {}}
	for span in s.spans {
		source:=bytes[span.offset:span.offset+span.size];target:=dst[span.wire_offset:span.wire_offset+span.size]
		if span.reverse {for &byte,i in target {byte=source[len(source)-1-i]}} else {copy(target,source)}
	}
	return {}
}

// Exact-size, transactional decode. Public projections preserve excluded local
// fields; authority projections cover the complete logical value. A caller may
// additionally validate game invariants before committing its own candidate.
decode :: proc(s: ^Schema, dst: ^$T, src: []u8) -> Report {
	if !s.ready {return {error = .Not_Ready}}
	if s.type != T {return {error = .Wrong_Type}}
	if len(src) != s.wire_size {return {error = .Wrong_Size}}
	if report:=validate_fields(s,src,true);report.error!=.None {return report}
	candidate := dst^
	bytes := (cast([^]u8)&candidate)[:size_of(T)]
	if len(s.unions)>0 {decode_union_fields(s,bytes,src);dst^=candidate;return {}}
	for span in s.spans {
		source:=src[span.wire_offset:span.wire_offset+span.size];target:=bytes[span.offset:span.offset+span.size]
		if span.reverse {for &byte,i in target {byte=source[len(source)-1-i]}} else {copy(target,source)}
	}
	dst^ = candidate
	return {}
}

@(private)
valid_bits :: proc(s: ^Schema, field: Field, bits: u64) -> bool {
	switch field.kind {
	case .Unsigned, .Signed: return true
	case .Union_Tag:
		layout:=s.unions[field.union_index]
		return bits<=u64(len(layout.variant_sizes)) && (!layout.no_nil || bits>0)
	case .Boolean: return bits <= 1
	case .Enumeration:
		for val in field.enum_values {if u64(i64(val)) & mask_for(field.width) == bits {return true}}
		return false
	case .Bits: return bits & ~field.bit_mask == 0
	case .Float:
		if !s.options.finite_floats {return true}
		mask := field.width == 2 ? u64(0x7c00) : field.width == 4 ? u64(0x7f800000) : u64(0x7ff0000000000000)
		return bits & mask != mask // rejects both infinities and every NaN payload
	}
	return false
}

@(private)
read_bits :: proc(bytes: []u8, big_endian: bool) -> u64 {
	value := u64(0)
	for b, i in bytes {
		shift := big_endian ? len(bytes) - i - 1 : i
		value |= u64(b) << uint(shift * 8)
	}
	return value
}

@(private)
write_bits :: proc(bytes: []u8, value: u64, big_endian: bool) {
	for &b, i in bytes {
		shift := big_endian ? len(bytes) - i - 1 : i
		b = u8(value >> uint(shift * 8))
	}
}
