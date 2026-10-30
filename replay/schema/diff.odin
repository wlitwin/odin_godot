package replay_schema

import "core:fmt"

Diff_Side :: enum {Neither, Left, Right}
// Paths and enum metadata are borrowed from the schema. Bits are normalized
// scalar values in canonical order, independent of native padding/endianness.
Difference :: struct {field:int,path:string,kind:Kind,width:int,left,right:u64,left_present,right_present:bool}
Diff_Report :: struct {report:Report,side:Diff_Side,count,total:int}

// Both complete values are validated before writing any output entry. A short
// destination truncates the displayed list, not the total difference count.
// Comparisons allocate nothing and do not mutate either value.
diff :: proc(s:^Schema,left,right:$T,out:[]Difference)->Diff_Report {
	if !s.ready {return {report={error=.Not_Ready}}}
	if s.type!=T {return {report={error=.Wrong_Type}}}
	a,b:=left,right
	return diff_fields(s,(cast([^]u8)&a)[:size_of(T)],(cast([^]u8)&b)[:size_of(T)],out,false)
}

// Input is the exact canonical payload, without an envelope. Validate/authenticate
// envelopes and application metadata separately before treating input as trusted.
diff_encoded :: proc(s:^Schema,left,right:[]u8,out:[]Difference)->Diff_Report {
	if !s.ready {return {report={error=.Not_Ready}}}
	if len(left)!=s.wire_size {return {report={error=.Wrong_Size},side=.Left}}
	if len(right)!=s.wire_size {return {report={error=.Wrong_Size},side=.Right}}
	return diff_fields(s,left,right,out,true)
}

@(private)
diff_fields :: proc(s:^Schema,left,right:[]u8,out:[]Difference,encoded:bool)->Diff_Report {
	if report:=validate_fields(s,left,encoded);report.error!=.None {return {report=report,side=.Left}}
	if report:=validate_fields(s,right,encoded);report.error!=.None {return {report=report,side=.Right}}
	report:Diff_Report
	for field,index in s.fields {
		left_present:=field_active(s,field.guard,left,encoded);right_present:=field_active(s,field.guard,right,encoded)
		if !left_present && !right_present {continue}
		a:=left_present ? field_bits(s,field,left,encoded) : 0
		b:=right_present ? field_bits(s,field,right,encoded) : 0
		if left_present==right_present && a==b {continue}
		report.total+=1
		if report.count<len(out) {out[report.count]={index,field.path,field.kind,field.width,a,b,left_present,right_present};report.count+=1}
	}
	return report
}

// Owned text for a validated diagnostic value. Integer strings preserve every
// bit through JSON/JavaScript tooling; floats include their canonical bit pattern
// so signed zero and distinct NaN payloads remain distinguishable.
diff_value :: proc(s:^Schema,entry:Difference,side:Diff_Side,allocator:=context.allocator)->string {
	if !s.ready || entry.field<0 || entry.field>=len(s.fields) || (side!=.Left && side!=.Right) {return fmt.aprintf("<invalid>",allocator=allocator)}
	field:=s.fields[entry.field]
	if field.kind!=entry.kind || field.width!=entry.width {return fmt.aprintf("<invalid>",allocator=allocator)}
	if side==.Left && !entry.left_present || side==.Right && !entry.right_present {return fmt.aprintf("<inactive>",allocator=allocator)}
	bits:=side==.Left ? entry.left : entry.right
	switch field.kind {
	case .Unsigned:return fmt.aprintf("%d",bits,allocator=allocator)
	case .Signed:
		if field.width<8 && bits&(u64(1)<<uint(field.width*8-1))!=0 {bits|=~mask_for(field.width)}
		return fmt.aprintf("%d",i64(bits),allocator=allocator)
	case .Boolean:return fmt.aprintf("%s",bits==0 ? "false" : "true",allocator=allocator)
	case .Enumeration:
		for value,i in field.enum_values {if u64(i64(value))&mask_for(field.width)==bits {return fmt.aprintf("%s",field.enum_names[i],allocator=allocator)}}
		return fmt.aprintf("<invalid enum 0x%x>",bits,allocator=allocator)
	case .Union_Tag:
		if bits==0 {return fmt.aprintf("nil",allocator=allocator)}
		layout:=s.unions[field.union_index]
		if bits>u64(len(layout.variant_names)) {return fmt.aprintf("<invalid tag>",allocator=allocator)}
		return fmt.aprintf("%s",layout.variant_names[bits-1],allocator=allocator)
	case .Bits:return fmt.aprintf("0x%x",bits,allocator=allocator)
	case .Float:
		value:f64
		switch field.width {
		case 2:n:=u16(bits);value=f64(transmute(f16)n)
		case 4:n:=u32(bits);value=f64(transmute(f32)n)
		case 8:value=transmute(f64)bits
		}
		return fmt.aprintf("%.17g (0x%x)",value,bits,allocator=allocator)
	}
	return fmt.aprintf("<invalid>",allocator=allocator)
}
