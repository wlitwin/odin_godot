package box3d_protocol_test

import "core:testing"
import "core:mem"
import "core:strings"
import d "godot:box3d/diagnostics"

identity :: proc() -> d.Identity {
	return {solver_format=3,recovery_format=1,game_format=1,observation_format=1,profile=1,
	        build_target=d.hash_bytes(transmute([]u8)string("build:arm64:test")),
	        assets=d.hash_bytes(transmute([]u8)string("assets:test")),
	        solver_schema=d.hash_bytes(transmute([]u8)string("solver:v3")),
	        game_schema=d.hash_bytes(transmute([]u8)string("game:test")),
	        observation_schema=d.hash_bytes(transmute([]u8)string("observations:test")),
	        input_schema=d.hash_bytes(transmute([]u8)string("inputs:test"))}
}
frame :: proc() -> d.Frame_View {
	return {identity=identity(),epoch=7,tick=42,
	        parts={.Solver=transmute([]u8)string("full solver with pending end"),
	               .Game=transmute([]u8)string("rng counters mappings"),
	               .Side=transmute([]u8)string("side fields"),
	               .Observations=transmute([]u8)string("completed sensor events"),
	               .Occurrences=transmute([]u8)string("occurrences with stable keys")}}
}
ok :: proc(t:^testing.T,err:d.Error) {testing.expect_value(t,err,d.Error.None)}
bytes_equal :: proc(a,b:[]u8)->bool {if len(a)!=len(b) {return false};for v,i in a {if v!=b[i] {return false}};return true}
rechecksum :: proc(bytes:[]u8) {sum:=d.hash_bytes(bytes[:len(bytes)-32]);copy(bytes[len(bytes)-32:],sum[:])}

@(test)
descriptor_catalog_binds_domains_tags_lengths_and_event_schema :: proc(t:^testing.T) {
	fields:=[2]d.Descriptor{{"occurrences",transmute([]u8)string("event-schema")},{"state",transmute([]u8)string("state-schema")}}
	id,err:=d.hash_descriptors("game-profile",fields[:]);ok(t,err)
	testing.expect_value(t,id,d.Digest{0x34,0xaa,0x9f,0x61,0x2a,0xaa,0x44,0x91,0xbd,0x68,0x9c,0xde,0x6d,0x30,0x89,0x87,0x96,0x9c,0xec,0xda,0x0d,0x48,0xa7,0x18,0x4a,0xb4,0xb6,0xe0,0x1b,0x79,0xad,0xf7})
	changed:=fields;changed[0].bytes=transmute([]u8)string("event-schema-v2")
	other,oe:=d.hash_descriptors("game-profile",changed[:]);ok(t,oe);testing.expect(t,id!=other)
	other,oe=d.hash_descriptors("different-domain",fields[:]);ok(t,oe);testing.expect(t,id!=other)
	changed=fields;changed[1].tag="occurrences";_,oe=d.hash_descriptors("game-profile",changed[:]);testing.expect_value(t,oe,d.Error.Invalid)
	changed=fields;changed[0],changed[1]=changed[1],changed[0];_,oe=d.hash_descriptors("game-profile",changed[:]);testing.expect_value(t,oe,d.Error.Invalid)
	_,oe=d.hash_descriptors("",fields[:]);testing.expect_value(t,oe,d.Error.Invalid)
	_,oe=d.hash_descriptors("bad/domain",fields[:]);testing.expect_value(t,oe,d.Error.Invalid)
	_,oe=d.hash_descriptors("game-profile",nil);testing.expect_value(t,oe,d.Error.Invalid)
	a:=[1]d.Descriptor{{"a",transmute([]u8)string("bc")}};b:=[1]d.Descriptor{{"ab",transmute([]u8)string("c")}}
	left,le:=d.hash_descriptors("game-profile",a[:]);ok(t,le);right,re:=d.hash_descriptors("game-profile",b[:]);ok(t,re);testing.expect(t,left!=right)
}

@(test)
sha256_and_every_complete_component_are_covered :: proc(t:^testing.T) {
	abc:=d.hash_bytes(transmute([]u8)string("abc"))
	testing.expect_value(t,abc,d.Digest{0xba,0x78,0x16,0xbf,0x8f,0x01,0xcf,0xea,0x41,0x41,0x40,0xde,0x5d,0xae,0x22,0x23,0xb0,0x03,0x61,0xa3,0x96,0x17,0x7a,0x9c,0xb4,0x10,0xff,0x61,0xf2,0x00,0x15,0xad})
	f:=frame();sig,err:=d.sign(f);ok(t,err)
	for p in d.Part {
		changed:=f;changed.parts[p]=transmute([]u8)string("changed")
		other,oe:=d.sign(changed);ok(t,oe)
		testing.expect_value(t,d.compare(sig,other),d.Difference(int(d.Difference.Solver)+int(p)))
		testing.expect(t,sig.complete!=other.complete)
	}
	for i in 0..<10 {
		changed:=f
		switch i {
		case 0: changed.identity.build_target[0] ~= 1
		case 1: changed.identity.assets[0] ~= 1
		case 2: changed.identity.solver_schema[0] ~= 1
		case 3: changed.identity.game_schema[0] ~= 1
		case 4: changed.identity.observation_schema[0] ~= 1
		case 5: changed.identity.input_schema[0] ~= 1
		case 6: changed.identity.profile += 1
		case 7: changed.identity.solver_format += 1
		case 8: changed.identity.recovery_format += 1
		case 9: changed.identity.observation_format += 1
		}
		other,oe:=d.sign(changed);ok(t,oe);testing.expect_value(t,d.compare(sig,other),d.Difference.Identity);testing.expect(t,sig.complete!=other.complete)
	}
	for i in 0..<2 {changed:=f;if i==0 {changed.tick+=1}else {changed.epoch+=1};other,oe:=d.sign(changed);ok(t,oe);testing.expect_value(t,d.compare(sig,other),d.Difference.Frame)}
}

@(test)
signature_wire_rejects_truncation_corruption_and_semantic_forgery :: proc(t:^testing.T) {
	sig,err:=d.sign(frame());ok(t,err)
	packet:[d.SIGNATURE_BYTES]u8
	n:int;n,err=d.signature_encode(sig,nil);ok(t,err);testing.expect_value(t,n,d.SIGNATURE_BYTES)
	n,err=d.signature_encode(sig,packet[:]);ok(t,err)
	decoded,de:=d.signature_decode(packet[:]);ok(t,de);testing.expect_value(t,decoded,sig)
	// LE version/epoch/tick are independently asserted, not native struct copies.
	testing.expect(t,packet[8]==1 && packet[9]==0 && packet[232]==7 && packet[240]==42)
	for cut in 0..<len(packet) {_,e:=d.signature_decode(packet[:cut]);testing.expect(t,e!=.None)}
	for i in 0..<len(packet) {bad:=packet;bad[i]~=1;_,e:=d.signature_decode(bad[:]);testing.expect(t,e!=.None)}
	for which in 0..<5 {
		bad:=packet
		switch which {
		case 0: bad[8]=2
		case 1: bad[12]=1
		case 2: for i in 232..<240 {bad[i]=0} // epoch zero
		case 3: for i in 248..<256 {bad[i]=255} // unbounded solver length
		case 4: for i in 40..<72 {bad[i]=0} // absent build identity
		}
		rechecksum(bad[:]);_,e:=d.signature_decode(bad[:]);testing.expect(t,e!=.None)
	}
	short:=[4]u8{0xaa,0xbb,0xcc,0xdd};before:=short
	n,err=d.signature_encode(sig,short[:]);testing.expect_value(t,err,d.Error.Capacity);testing.expect_value(t,n,d.SIGNATURE_BYTES);testing.expect_value(t,short,before)
	long:=[d.SIGNATURE_BYTES+1]u8{};copy(long[:],packet[:]);_,le:=d.signature_decode(long[:]);testing.expect(t,le!=.None)
}

@(test)
invalid_frames_and_limits_do_not_produce_valid_signatures :: proc(t:^testing.T) {
	f:=frame();f.parts[.Solver]=nil;_,err:=d.sign(f);testing.expect_value(t,err,d.Error.Invalid)
	f=frame();f.identity.input_schema={};_,err=d.sign(f);testing.expect_value(t,err,d.Error.Invalid)
	_,err=d.sign(frame(),{8,16,8});testing.expect_value(t,err,d.Error.Limit)
	_,err=d.sign(frame(),{0,16,8});testing.expect_value(t,err,d.Error.Invalid)
	_,err=d.sign(frame(),{16,max(int),8});testing.expect_value(t,err,d.Error.Invalid)
	f=frame();f.parts[.Side]=nil;_,err=d.sign(f);ok(t,err)
}

@(test)
first_trace_owns_all_state_inputs_and_survives_source_mutation :: proc(t:^testing.T) {
	left:=frame();right:=left
	actual:=[5]u8{1,2,9,4,5};expected:=[5]u8{1,2,3,4,5}
	left.parts[.Observations]=expected[:];right.parts[.Observations]=actual[:]
	accepted:=[4]u8{4,3,2,1};predicted:=[4]u8{1,2,3,4}
	info:=d.Trace_Context{from_tick=35,to_tick=42,source=22,sequence=77,depth=8,accepted_inputs=accepted[:],predicted_inputs=predicted[:]}
	trace:d.Trace;defer d.trace_destroy(&trace)
	ok(t,d.trace_capture(&trace,left,right,info))
	testing.expect_value(t,trace.difference,d.Difference.Observations);testing.expect_value(t,trace.first_byte,2)
	actual[2]=3;expected[2]=9;accepted[0]=0;predicted[0]=0
	testing.expect(t,trace.expected_frame.parts[.Observations][2]==3 && trace.actual_frame.parts[.Observations][2]==9)
	testing.expect(t,trace.input_context.accepted_inputs[0]==4 && trace.input_context.predicted_inputs[0]==1)
	testing.expect_value(t,d.trace_capture(&trace,left,right,info),d.Error.Already_Captured)
	text:=d.trace_text(&trace);defer delete(text)
	testing.expect(t,strings.contains(text,"Observations") && strings.contains(text,"input window 35..42") && strings.contains(text,"depth 8") && strings.contains(text,"build_target"))
	n,err:=d.trace_encode(&trace,nil);ok(t,err)
	packet:=make([]u8,n);defer delete(packet)
	_,err=d.trace_encode(&trace,packet);ok(t,err)
	decoded:d.Trace;defer d.trace_destroy(&decoded);ok(t,d.trace_decode(&decoded,packet))
	testing.expect_value(t,decoded.expected,trace.expected);testing.expect_value(t,decoded.actual,trace.actual)
	testing.expect(t,bytes_equal(decoded.actual_frame.parts[.Observations],trace.actual_frame.parts[.Observations]))
	for &v in packet {v=0}
	testing.expect(t,decoded.actual_frame.parts[.Observations][2]==9)
}

@(test)
malformed_trace_never_publishes_and_reports_capacity_without_writes :: proc(t:^testing.T) {
	a:=frame();b:=a;b.parts[.Solver]=transmute([]u8)string("changed native future state")
	trace:d.Trace;defer d.trace_destroy(&trace)
	info:=d.Trace_Context{from_tick=42,to_tick=42,depth=1}
	ok(t,d.trace_capture(&trace,a,b,info));n,ne:=d.trace_encode(&trace,nil);ok(t,ne)
	packet:=make([]u8,n);defer delete(packet);_,ne=d.trace_encode(&trace,packet);ok(t,ne)
	short:=[3]u8{4,5,6};before:=short;_,se:=d.trace_encode(&trace,short[:]);testing.expect_value(t,se,d.Error.Capacity);testing.expect_value(t,short,before)
	for cut in 0..<n {
		out:d.Trace;err:=d.trace_decode(&out,packet[:cut]);testing.expect(t,err!=.None && !out.ready && len(out.storage)==0);d.trace_destroy(&out)
	}
	for i in 0..<n {
		packet[i]~=1;out:d.Trace;err:=d.trace_decode(&out,packet);testing.expect(t,err!=.None && !out.ready);d.trace_destroy(&out);packet[i]~=1
	}
	// A sender can recompute checksums; structural and component checks still apply.
	for i in 0..<4 {
		bad:=make([]u8,n);copy(bad,packet)
		switch i {case 0:bad[12]=1;case 1:bad[48]=129;case 2:bad[56]=255;case 3:bad[d.TRACE_HEADER_BYTES]~=1}
		rechecksum(bad);out:d.Trace;err:=d.trace_decode(&out,bad);testing.expect(t,err!=.None && !out.ready);d.trace_destroy(&out);delete(bad)
	}
}

@(test)
allocation_and_input_budget_failures_leave_trace_retryable :: proc(t:^testing.T) {
	a:=frame();b:=a;b.parts[.Game]=transmute([]u8)string("different")
	trace:d.Trace;defer d.trace_destroy(&trace)
	info:=d.Trace_Context{from_tick=42,to_tick=42}
	testing.expect_value(t,d.trace_capture(&trace,a,a,info),d.Error.No_Mismatch)
	testing.expect_value(t,d.trace_capture(&trace,a,b,info,allocator=mem.nil_allocator()),d.Error.Out_Of_Memory)
	testing.expect(t,!trace.ready && len(trace.storage)==0)
	bad:=info;bad.from_tick=43;testing.expect_value(t,d.trace_capture(&trace,a,b,bad),d.Error.Invalid)
	input:=[9]u8{};bad=info;bad.accepted_inputs=input[:]
	testing.expect_value(t,d.trace_capture(&trace,a,b,bad,{1024,2048,8}),d.Error.Limit)
	ok(t,d.trace_capture(&trace,a,b,info));d.trace_destroy(&trace);testing.expect(t,!trace.ready && len(trace.storage)==0)
	ok(t,d.trace_capture(&trace,a,b,info))
}
