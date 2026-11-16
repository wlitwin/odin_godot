package schema_block_reference

// Compact validation instructions keep the hot loop out of the large diagnostic
// Field descriptors. Field paths and sparse enum tables are touched only when
// needed. The program preserves field order and therefore first-error reporting.
@(private)
Check_Kind :: enum u8 {Maximum,Finite,Mask,Small_Set,Range,Sparse_Enum}
@(private)
Check :: struct {offset:int,wire_offset,field:u32,width:u8,kind:Check_Kind,big_endian:bool,mask,limit:u64}

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
	for check in s.validation {
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
