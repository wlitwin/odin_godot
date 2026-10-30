package replay_schema_test

import "core:testing"
import "core:reflect"
import sc "godot:replay/schema"

@(test)
field_diff_ignores_padding_and_reports_truncation_without_hiding_total :: proc(t:^testing.T) {
	s:sc.Schema;sc.init(&s,Value);defer sc.destroy(&s)
	left:=value();right:=left
	bytes:=(cast([^]u8)&right)[:size_of(Value)];bytes[1]=0xa5 // padding after flag
	out:[8]sc.Difference
	testing.expect_value(t,sc.diff(&s,left,right,out[:]).total,0)
	right.number+=1;right.mode=.Idle;right.signed=-7;right.bytes[1]=11
	report:=sc.diff(&s,left,right,out[:2])
	testing.expect_value(t,report.report.error,sc.Error.None);testing.expect_value(t,report.count,2);testing.expect_value(t,report.total,4)
	testing.expect_value(t,out[0].path,"$.number");testing.expect_value(t,out[1].path,"$.mode")
	a:=sc.diff_value(&s,out[1],.Left);b:=sc.diff_value(&s,out[1],.Right);defer delete(a);defer delete(b)
	testing.expect_value(t,a,"Attack");testing.expect_value(t,b,"Idle")
	sc.diff(&s,left,right,out[:]);signed:=sc.diff_value(&s,out[2],.Right);defer delete(signed);testing.expect_value(t,signed,"-7")
}
@(test)
field_diff_validates_both_complete_values_before_touching_output :: proc(t:^testing.T) {
	s:sc.Schema;sc.init(&s,Value);defer sc.destroy(&s)
	left:=value();right:=left;right.number=99;right.mode=Mode(6)
	out:=[1]sc.Difference{{path="canary",left=999}};before:=out
	report:=sc.diff(&s,left,right,out[:]);testing.expect_value(t,report.side,sc.Diff_Side.Right)
	testing.expect_value(t,report.report.error,sc.Error.Invalid_Value);testing.expect(t,reflect.equal(out,before))
	a:=make([]u8,s.wire_size);b:=make([]u8,s.wire_size);defer delete(a);defer delete(b)
	sc.encode(&s,left,a);copy(b,a)
	for field in s.fields {if field.path=="$.mode" {b[field.wire_offset]=6}}
	report=sc.diff_encoded(&s,a,b,out[:]);testing.expect_value(t,report.report.error,sc.Error.Invalid_Value);testing.expect(t,reflect.equal(out,before))
	report=sc.diff_encoded(&s,a,b[:len(b)-1],out[:]);testing.expect_value(t,report.report.error,sc.Error.Wrong_Size);testing.expect(t,reflect.equal(out,before))
}
@(test)
field_diff_respects_projection_endian_and_canonical_float_bits :: proc(t:^testing.T) {
	State :: struct {secret:u64 `replay:"authority"`,be:i16be,number:f32}
	s:sc.Schema;opts:=sc.DEFAULT_OPTIONS;opts.projection=.Public;sc.init(&s,State,opts);defer sc.destroy(&s)
	left:=State{1,i16be(-2),0};right:=left;right.secret=9;right.be=i16be(-3);zero:=u32(0x80000000);right.number=transmute(f32)zero
	out:[4]sc.Difference;result:=sc.diff(&s,left,right,out[:]);testing.expect_value(t,result.total,2)
	testing.expect_value(t,out[0].path,"$.be");testing.expect_value(t,out[1].right,u64(0x80000000))
	a:=make([]u8,s.wire_size);b:=make([]u8,s.wire_size);defer delete(a);defer delete(b);sc.encode(&s,left,a);sc.encode(&s,right,b)
	encoded:[4]sc.Difference;wire:=sc.diff_encoded(&s,a,b,encoded[:]);testing.expect_value(t,wire.total,result.total)
	for entry,i in out[:result.count] {testing.expect_value(t,entry,encoded[i])}
}
