package replay_schema_reference

import "base:intrinsics"

// Compact validation instructions keep the hot loop out of the large diagnostic
// Field descriptors. Field paths and sparse enum tables are touched only when
// needed. The program preserves field order and therefore first-error reporting.
@(private)
Check_Kind :: enum u8 {Maximum,Finite,Mask,Small_Set,Range,Sparse_Enum}
@(private)
Check :: struct {offset:int,wire_offset,field:u32,width:u8,kind:Check_Kind,big_endian:bool,mask,limit:u64}

@(private)
Validation_Block :: struct {first,count:int,offset,wire_offset,size:int}

@(private)
compile_validation :: proc(s:^Schema) {
	if len(s.unions)>0 {return} // guarded unions retain the general validator
	s.validation=make([dynamic]Check,0,len(s.checks),s.allocator)
	for index in s.checks {
		field:=s.fields[index]
		check:=Check{offset=field.offset,wire_offset=u32(field.wire_offset),field=u32(index),width=u8(field.width),big_endian=field.big_endian}
		#partial switch field.kind {
		case .Boolean:check.kind=.Maximum;check.limit=1
		case .Float:check.kind=.Finite;check.mask=field.width==2 ? 0x7c00 : field.width==4 ? 0x7f800000 : 0x7ff0000000000000
		case .Bits:check.kind=.Mask;check.mask=field.bit_mask
		case .Enumeration:
			check.kind=.Sparse_Enum;small:=true;ascending:=len(field.enum_values)>0
			for value,i in field.enum_values {
				bits:=u64(i64(value)) & mask_for(field.width)
				if bits<64 {check.mask |= u64(1)<<uint(bits)} else {small=false}
				if i==0 {check.limit=bits} else if check.limit>max(u64)-u64(i) || bits!=check.limit+u64(i) {ascending=false}
			}
			if small {check.kind=.Small_Set} else if ascending {
				check.kind=.Range;check.mask=check.limit;check.limit+=u64(len(field.enum_values)-1)
			}
		case:continue
		}
		append(&s.validation,check)
	}
	compile_validation_blocks(s)
}
@(private)
check_bits :: proc(bytes:[]u8,offset:int,width:u8,big_endian:bool)->u64 {
	if big_endian {return read_bits(bytes[offset:offset+int(width)],true)}
	value:=u64(bytes[offset]);if width==1 {return value}
	value |= u64(bytes[offset+1])<<8;if width==2 {return value}
	value |= u64(bytes[offset+2])<<16 | u64(bytes[offset+3])<<24;if width==4 {return value}
	return value | u64(bytes[offset+4])<<32 | u64(bytes[offset+5])<<40 | u64(bytes[offset+6])<<48 | u64(bytes[offset+7])<<56
}
@(private)
validate_program :: proc(s:^Schema,bytes:[]u8,encoded:bool)->Report {
	if !use_validation_blocks(s,bytes,encoded) {return validate_checks(s,bytes,encoded,s.validation[:])}
	for block in s.validation_blocks {
		if block.count > 1 {
			offset := encoded ? block.wire_offset : block.offset
			if zero_bytes(bytes[offset:offset+block.size]) {continue}
		}
		if report:=validate_checks(s,bytes,encoded,s.validation[block.first:block.first+block.count]);report.error!=.None {return report}
	}
	return {}
}

// A bounded per-call probe avoids the grouped-loop overhead on dense data.
// Every probe is within a validated direct-copy span; nothing is cached between
// calls, so one schema can alternate dense and sparse values safely.
@(private)
use_validation_blocks :: proc(s:^Schema,bytes:[]u8,encoded:bool)->bool {
	if len(s.validation_blocks)<8 {return false}
	zero:=0
	for probe in 0..<8 {
		block:=s.validation_blocks[probe*(len(s.validation_blocks)-1)/7]
		if block.count<2 {continue}
		offset:=encoded ? block.wire_offset : block.offset
		if zero_bytes(bytes[offset:offset+block.size]) {zero+=1;if zero==2 {return true}}
	}
	return false
}

@(private)
validate_checks :: proc(s:^Schema,bytes:[]u8,encoded:bool,checks:[]Check)->Report {
	for check in checks {
		offset:=encoded ? int(check.wire_offset) : check.offset
		bits:=check_bits(bytes,offset,check.width,!encoded && check.big_endian)
		valid:=false
		switch check.kind {
		case .Maximum:valid=bits<=check.limit
		case .Finite:valid=bits & check.mask!=check.mask
		case .Mask:valid=bits & ~check.mask==0
		case .Small_Set:valid=bits<64 && check.mask & (u64(1)<<uint(bits))!=0
		case .Range:valid=bits>=check.mask && bits<=check.limit
		case .Sparse_Enum:
			for value in s.fields[check.field].enum_values {if u64(i64(value)) & mask_for(int(check.width))==bits {valid=true;break}}
		}
		if !valid {return {.Invalid_Value,s.fields[check.field].path}}
	}
	return {}
}

@(private)
zero_valid :: proc(s:^Schema,check:Check)->bool {
	switch check.kind {
	case .Maximum,.Finite,.Mask:return true
	case .Small_Set:return check.mask & 1 != 0
	case .Range:return check.mask == 0
	case .Sparse_Enum:
		for value in s.fields[check.field].enum_values {if u64(i64(value)) & mask_for(int(check.width)) == 0 {return true}}
	}
	return false
}

// A group lies wholly inside one existing direct-copy span. It therefore never
// reads compiler padding, hidden fields, reversed scalars or union storage.
@(private)
compile_validation_blocks :: proc(s:^Schema) {
	s.validation_blocks=make([dynamic]Validation_Block,0,0,s.allocator)
	span_index:=0
	for first:=0;first<len(s.validation); {
		check:=s.validation[first]
		for span_index<len(s.spans) && s.spans[span_index].wire_offset+s.spans[span_index].size<=int(check.wire_offset) {span_index+=1}
		block:=Validation_Block{first=first,count=1,offset=check.offset,wire_offset=int(check.wire_offset),size=int(check.width)}
		if span_index<len(s.spans) && !s.spans[span_index].reverse && zero_valid(s,check) {
			span:=s.spans[span_index]
			for next:=first+1;next<len(s.validation) && next-first<32;next+=1 {
				candidate:=s.validation[next];end:=int(candidate.wire_offset)+int(candidate.width)
				if end>span.wire_offset+span.size || end-block.wire_offset>128 || candidate.offset-block.offset!=int(candidate.wire_offset)-block.wire_offset || !zero_valid(s,candidate) {break}
				block.count+=1;block.size=end-block.wire_offset
			}
		}
		append(&s.validation_blocks,block);first+=block.count
	}
}

@(private)
zero_bytes :: proc(bytes:[]u8)->bool {
	i:=0
	for len(bytes)-i>=8 {
		if intrinsics.unaligned_load(cast(^u64)&bytes[i])!=0 {return false}
		i+=8
	}
	for byte in bytes[i:] {if byte!=0 {return false}}
	return true
}
