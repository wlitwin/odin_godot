package replay_schema_test

import "core:testing"
import "core:reflect"
import sc "godot:replay/schema"

Small :: struct {value:u8}
Large :: struct {first:u32be,second:i16,valid:bool}
Choice :: union {Small,Large}
Nested :: struct {choice:Choice,other:union #no_nil {Small,Large}}

@(test)
tagged_union_encodes_only_selected_variant_and_zeroes_unused_bytes :: proc(t:^testing.T) {
	codec:sc.Schema;testing.expect_value(t,sc.init(&codec,Choice).error,sc.Error.None);defer sc.destroy(&codec)
	testing.expect_value(t,codec.wire_size,11)
	value:Choice=Large{0x01020304,-2,true};value=Small{7}
	bytes:=(cast([^]u8)&value)[:size_of(Choice)]
	// Dirty inactive storage, including a byte which is a boolean only in Large.
	bytes[1],bytes[6]=0xee,0xff
	wire: [11]u8;testing.expect_value(t,sc.encode(&codec,value,wire[:]).error,sc.Error.None)
	testing.expect_value(t,wire,[11]u8{0=1,4=7})
	decoded:Choice=Large{9,9,true}
	testing.expect_value(t,sc.decode(&codec,&decoded,wire[:]).error,sc.Error.None)
	v,ok:=decoded.(Small);testing.expect(t,ok);testing.expect_value(t,v.value,u8(7))
	value=Large{0x01020304,-2,true};sc.encode(&codec,value,wire[:])
	testing.expect_value(t,wire,[11]u8{2,0,0,0,4,3,2,1,254,255,1})
	value=nil;sc.encode(&codec,value,wire[:]);testing.expect_value(t,wire,[11]u8{})
}
@(test)
union_decode_rejects_tags_padding_and_invalid_active_values_transactionally :: proc(t:^testing.T) {
	codec:sc.Schema;sc.init(&codec,Choice);defer sc.destroy(&codec)
	value:Choice=Small{3};wire:[11]u8;sc.encode(&codec,value,wire[:])
	for mode in 0..<3 {
		bad:=wire
		if mode==0 {bad[0]=3}
		if mode==1 {bad[10]=9}
		if mode==2 {bad[0]=2;bad[10]=2}
		output:Choice=Large{77,-9,true};before:=output
		testing.expect_value(t,sc.decode(&codec,&output,bad[:]).error,sc.Error.Invalid_Value)
		testing.expect(t,reflect.equal(before,output))
	}
	out:=[11]u8{0=99};before:=out
	reflect.set_union_variant_raw_tag(any{&value,typeid_of(Choice)},99)
	testing.expect_value(t,sc.encode(&codec,value,out[:]).error,sc.Error.Invalid_Value);testing.expect_value(t,out,before)
}
@(test)
nested_union_and_non_nil_variants_round_trip :: proc(t:^testing.T) {
	Inner :: union {Small,Large}
	Outer :: union {Inner,Large}
	State :: struct {nested:Outer,items:[2]Nested}
	codec:sc.Schema;testing.expect_value(t,sc.init(&codec,State).error,sc.Error.None);defer sc.destroy(&codec)
	value:State;value.nested=Inner(Large{100,-2,true});value.items[0]={Small{3},Large{9,-8,true}};value.items[1]={nil,Small{8}}
	bytes:=make([]u8,codec.wire_size);defer delete(bytes)
	testing.expect_value(t,sc.encode(&codec,value,bytes).error,sc.Error.None)
	decoded:State;testing.expect_value(t,sc.decode(&codec,&decoded,bytes).error,sc.Error.None);testing.expect(t,reflect.equal(decoded,value))
	for field in codec.fields {if field.path=="$.items[0].other.$tag" {bytes[field.wire_offset]=0;break}}
	before:=decoded;testing.expect_value(t,sc.decode(&codec,&decoded,bytes).error,sc.Error.Invalid_Value);testing.expect(t,reflect.equal(before,decoded))
}
@(test)
public_union_retains_private_fields_only_within_the_same_variant :: proc(t:^testing.T) {
	One :: struct {visible:u8,secret:u32 `replay:"authority"`}
	Two :: struct {visible:u16,secret:u64 `replay:"authority"`}
	State :: struct {choice:union{One,Two},hidden:Choice `replay:"authority"`}
	codec:sc.Schema;options:=sc.DEFAULT_OPTIONS;options.projection=.Public;sc.init(&codec,State,options);defer sc.destroy(&codec)
	wire:=make([]u8,codec.wire_size);defer delete(wire)
	source:=State{choice=One{2,999}};sc.encode(&codec,source,wire)
	target:=State{choice=One{1,55},hidden=Small{7}}
	testing.expect_value(t,sc.decode(&codec,&target,wire).error,sc.Error.None)
	one,ok:=target.choice.(One);testing.expect(t,ok && one.visible==2 && one.secret==55)
	source.choice=Two{8,9999};sc.encode(&codec,source,wire)
	testing.expect_value(t,sc.decode(&codec,&target,wire).error,sc.Error.None)
	two,selected:=target.choice.(Two);testing.expect(t,selected && two.visible==8 && two.secret==0)
	hidden,retained:=target.hidden.(Small);testing.expect(t,retained && hidden.value==7)
}
@(test)
union_field_diagnostics_mark_inactive_variants :: proc(t:^testing.T) {
	codec:sc.Schema;sc.init(&codec,Choice);defer sc.destroy(&codec)
	left:Choice=Small{0};right:Choice=Large{0,0,false};fields:[8]sc.Difference
	report:=sc.diff(&codec,left,right,fields[:]);testing.expect_value(t,report.report.error,sc.Error.None);testing.expect_value(t,report.total,5)
	testing.expect_value(t,fields[0].path,"$.$tag")
	testing.expect(t,fields[1].left_present && !fields[1].right_present)
	text:=sc.diff_value(&codec,fields[1],.Right);defer delete(text);testing.expect_value(t,text,"<inactive>")
}

@(test)
wide_native_tags_and_nonzero_variant_defaults_do_not_change_wire_rules :: proc(t:^testing.T) {
	Tall :: struct {value:u64be}
	Wide :: union #no_nil {Small,Tall}
	codec:sc.Schema;sc.init(&codec,Wide);defer sc.destroy(&codec)
	value:Wide=Tall{0x0102030405060708};wire:[12]u8
	testing.expect_value(t,sc.encode(&codec,value,wire[:]).error,sc.Error.None)
	testing.expect_value(t,wire,[12]u8{2,0,0,0,8,7,6,5,4,3,2,1})
	decoded:Wide;testing.expect_value(t,sc.decode(&codec,&decoded,wire[:]).error,sc.Error.None);testing.expect(t,reflect.equal(decoded,value))
	Required :: enum u8 {Ready=1}
	Must_Set :: struct {mode:Required}
	Optional :: union {Must_Set,Small}
	other:sc.Schema;sc.init(&other,Optional);defer sc.destroy(&other)
	bytes:[5]u8;empty:Optional
	testing.expect_value(t,sc.encode(&other,empty,bytes[:]).error,sc.Error.None)
	bad:Optional=Must_Set{};testing.expect_value(t,sc.encode(&other,bad,bytes[:]).error,sc.Error.Invalid_Value)
}
@(test)
reference_variants_are_rejected_even_when_hidden_or_never_selected :: proc(t:^testing.T) {
	Unsafe :: union {Small,struct{pointer:^u32}}
	State :: struct {hidden:Unsafe `replay:"authority"`}
	codec:sc.Schema;opts:=sc.DEFAULT_OPTIONS;opts.projection=.Public
	testing.expect_value(t,sc.init(&codec,State,opts).error,sc.Error.Unsupported_Type);sc.destroy(&codec)
	testing.expect_value(t,sc.init(&codec,[0]Unsafe).error,sc.Error.Unsupported_Type);sc.destroy(&codec)
}
