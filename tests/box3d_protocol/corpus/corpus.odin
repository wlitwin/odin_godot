package box3d_protocol_corpus

import "base:runtime"
import "core:mem"
import d "godot:box3d/diagnostics"

backing: [2 * 1024 * 1024]u8
signature: [d.SIGNATURE_BYTES]u8
descriptor: d.Digest
artifact: [4096]u8
artifact_size: int

verify :: proc "c" () -> u32 {
	context=runtime.default_context()
	arena:mem.Arena;mem.arena_init(&arena,backing[:]);context.allocator=mem.arena_allocator(&arena);context.temp_allocator=context.allocator
	fields:=[2]d.Descriptor{{"occurrences",transmute([]u8)string("event-schema")},{"state",transmute([]u8)string("state-schema")}}
	de_error:d.Error;descriptor,de_error=d.hash_descriptors("game-profile",fields[:]);if de_error!=.None {return 8}
	id:=d.Identity{solver_format=3,recovery_format=1,game_format=1,observation_format=1,profile=1,
		build_target=d.hash_bytes(transmute([]u8)string("build:arm64:test")),assets=d.hash_bytes(transmute([]u8)string("assets:test")),
		solver_schema=d.hash_bytes(transmute([]u8)string("solver:v3")),game_schema=d.hash_bytes(transmute([]u8)string("game:test")),
		observation_schema=d.hash_bytes(transmute([]u8)string("observations:test")),input_schema=d.hash_bytes(transmute([]u8)string("inputs:test"))}
	a:=d.Frame_View{identity=id,epoch=7,tick=42,
		parts={.Solver=transmute([]u8)string("full solver with pending end"),.Game=transmute([]u8)string("rng counters mappings"),
			.Side=transmute([]u8)string("side fields"),.Observations=transmute([]u8)string("completed sensor events"),.Occurrences=transmute([]u8)string("occurrences with stable keys")}}
	b:=a;b.parts[.Game]=transmute([]u8)string("different game")
	sig,se:=d.sign(a);if se!=.None {return 1}
	n,we:=d.signature_encode(sig,signature[:]);if we!=.None || n!=d.SIGNATURE_BYTES {return 2}
	decoded,de:=d.signature_decode(signature[:]);if de!=.None || decoded!=sig {return 3}
	trace:d.Trace;defer d.trace_destroy(&trace)
	info:=d.Trace_Context{from_tick=35,to_tick=42,source=22,sequence=77,depth=8,
		accepted_inputs=transmute([]u8)string("accepted/input/window"),predicted_inputs=transmute([]u8)string("held/input/window")}
	if d.trace_capture(&trace,a,b,info)!=.None {return 4}
	if trace.difference!=.Game || trace.first_byte!=0 {return 5}
	count,error:=d.trace_encode(&trace,artifact[:]);if error!=.None {return 6};artifact_size=count
	copy_trace:d.Trace;defer d.trace_destroy(&copy_trace)
	if d.trace_decode(&copy_trace,artifact[:artifact_size])!=.None || copy_trace.actual!=trace.actual {return 7}
	return 0
}
signature_byte :: proc "c" (index:u32)->u32 {if index>=d.SIGNATURE_BYTES {return 0};return u32(signature[index])}
trace_byte :: proc "c" (index:u32)->u32 {if index>=u32(artifact_size) {return 0};return u32(artifact[index])}
trace_size :: proc "c" ()->u32 {return u32(artifact_size)}
descriptor_byte :: proc "c" (index:u32)->u32 {if index>=32 {return 0};return u32(descriptor[index])}
