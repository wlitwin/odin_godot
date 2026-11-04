package box3d_diagnostics

import "core:mem"
import "core:fmt"
import "core:strings"

TRACE_HEADER_BYTES :: 1040

Trace_Context :: struct {
	from_tick, to_tick, source, sequence: u64,
	depth: u32,
	accepted_inputs, predicted_inputs: []u8,
}
// One owner. Assignment aliases storage; destroy exactly once. The first
// mismatch survives source worlds, timelines and later mismatch attempts.
Trace :: struct {
	ready: bool,
	difference: Difference,
	first_byte: int,
	expected, actual: Signature,
	expected_frame, actual_frame: Frame_View,
	input_context: Trace_Context,
	storage: []u8,
	allocator: mem.Allocator,
}
trace_destroy :: proc(trace: ^Trace) {
	if trace == nil {return}
	delete(trace.storage, trace.allocator); trace^ = {}
}

// A failed preparation leaves trace unchanged. Byte buffers and context are
// copied only after every bound/identity/signature check has passed.
trace_capture :: proc(trace: ^Trace, expected, actual: Frame_View, info: Trace_Context,
                     limits := DEFAULT_LIMITS, allocator := context.allocator) -> Error {
	if trace == nil {return .Invalid}
	if trace.ready || len(trace.storage) != 0 {return .Already_Captured}
	a, ae := sign(expected, limits); if ae != .None {return ae}
	b, be := sign(actual, limits); if be != .None {return be}
	if info.from_tick > info.to_tick || info.to_tick < expected.tick || info.depth > 128 {return .Invalid}
	if len(info.accepted_inputs) > limits.max_input_bytes || len(info.predicted_inputs) > limits.max_input_bytes {return .Limit}
	difference := compare(a,b); offset := -1
	if difference == .Match {return .No_Mismatch}
	if difference >= .Solver {
		p := Part(int(difference)-int(Difference.Solver))
		left, right := expected.parts[p], actual.parts[p]
		offset = min(len(left),len(right))
		for i in 0..<offset {if left[i] != right[i] {offset=i;break}}
	}
	n := len(info.accepted_inputs) + len(info.predicted_inputs)
	for p in Part {n += len(expected.parts[p]) + len(actual.parts[p])}
	storage, allocation_error := mem.alloc_bytes(n, allocator=allocator)
	if allocation_error != .None || len(storage) != n {
		if len(storage) != 0 {delete(storage, allocator)}
		return .Out_Of_Memory
	}
	value := Trace{ready=true,difference=difference,first_byte=offset,expected=a,actual=b,
	               expected_frame=expected,actual_frame=actual,input_context=info,storage=storage,allocator=allocator}
	at := 0
	for p in Part {value.expected_frame.parts[p] = copy_owned(storage,&at,expected.parts[p])}
	for p in Part {value.actual_frame.parts[p] = copy_owned(storage,&at,actual.parts[p])}
	value.input_context.accepted_inputs = copy_owned(storage,&at,info.accepted_inputs)
	value.input_context.predicted_inputs = copy_owned(storage,&at,info.predicted_inputs)
	trace^ = value; return .None
}
@(private)
copy_owned :: proc(dst: []u8, at: ^int, src: []u8) -> []u8 {
	result := dst[at^:at^+len(src)]; copy(result,src); at^ += len(src); return result
}

// Artifact retains full frame bytes, including both native logical dumps and
// the accepted/predicted input window. It is not a recovery/import format.
trace_encode :: proc(trace: ^Trace, dst: []u8, limits := DEFAULT_LIMITS) -> (int, Error) {
	if trace == nil || !trace.ready {return 0,.Invalid}
	a, ae := sign(trace.expected_frame,limits); if ae != .None {return 0,ae}
	b, be := sign(trace.actual_frame,limits); if be != .None {return 0,be}
	if a != trace.expected || b != trace.actual || compare(a,b) != trace.difference {return 0,.Checksum}
	info := trace.input_context
	if info.from_tick > info.to_tick || info.to_tick < a.tick || info.depth > 128 {return 0,.Invalid}
	if len(info.accepted_inputs)>limits.max_input_bytes || len(info.predicted_inputs)>limits.max_input_bytes {return 0,.Limit}
	n := TRACE_HEADER_BYTES + 32 + len(info.accepted_inputs) + len(info.predicted_inputs)
	for p in Part {n += len(trace.expected_frame.parts[p]) + len(trace.actual_frame.parts[p])}
	if len(dst)==0 {return n,.None}
	if len(dst)<n {return n,.Capacity}
	dst:=dst[:n]; copy(dst[:8],"OGB3TRC1"); at:=8
	write_u32(dst,&at,FORMAT_VERSION);write_u32(dst,&at,0)
	write_u64(dst,&at,info.from_tick);write_u64(dst,&at,info.to_tick)
	write_u64(dst,&at,info.source);write_u64(dst,&at,info.sequence)
	write_u32(dst,&at,info.depth);write_u32(dst,&at,0)
	write_u64(dst,&at,u64(len(info.accepted_inputs)));write_u64(dst,&at,u64(len(info.predicted_inputs)));write_u64(dst,&at,u64(n))
	write_signature(a,dst[at:at+SIGNATURE_BYTES]);at+=SIGNATURE_BYTES
	write_signature(b,dst[at:at+SIGNATURE_BYTES]);at+=SIGNATURE_BYTES
	for p in Part {copy_owned(dst,&at,trace.expected_frame.parts[p])}
	for p in Part {copy_owned(dst,&at,trace.actual_frame.parts[p])}
	copy_owned(dst,&at,info.accepted_inputs);copy_owned(dst,&at,info.predicted_inputs)
	checksum:=hash_bytes(dst[:at]);copy(dst[at:at+32],checksum[:]); return n,.None
}

// Decoding never imports solver bytes. The destination owner stays unchanged
// on malformed metadata, hashes, lengths, mismatches, or allocation failure.
trace_decode :: proc(out: ^Trace, src: []u8, limits := DEFAULT_LIMITS, allocator := context.allocator) -> Error {
	if out==nil {return .Invalid}
	if out.ready || len(out.storage)!=0 {return .Already_Captured}
	if !valid_limits(limits) || len(src)<TRACE_HEADER_BYTES+32 || string(src[:8])!="OGB3TRC1" {return .Invalid}
	if len(src)>TRACE_HEADER_BYTES+32+2*limits.max_frame_bytes+2*limits.max_input_bytes {return .Limit}
	at:=8
	if read_u32(src,&at)!=FORMAT_VERSION || read_u32(src,&at)!=0 {return .Incompatible}
	info:Trace_Context
	info.from_tick=read_u64(src,&at);info.to_tick=read_u64(src,&at)
	info.source=read_u64(src,&at);info.sequence=read_u64(src,&at);info.depth=read_u32(src,&at)
	if read_u32(src,&at)!=0 {return .Invalid}
	accepted,predicted:=read_u64(src,&at),read_u64(src,&at)
	if read_u64(src,&at)!=u64(len(src)) {return .Invalid}
	if accepted>u64(limits.max_input_bytes) || predicted>u64(limits.max_input_bytes) {return .Limit}
	a,ae:=signature_decode(src[at:at+SIGNATURE_BYTES],limits);if ae!=.None {return ae};at+=SIGNATURE_BYTES
	b,be:=signature_decode(src[at:at+SIGNATURE_BYTES],limits);if be!=.None {return be};at+=SIGNATURE_BYTES
	n:=u64(TRACE_HEADER_BYTES+32)+accepted+predicted
	for p in Part {n+=a.lengths[p]+b.lengths[p]}
	if n!=u64(len(src)) {return .Invalid}
	checksum:=hash_bytes(src[:len(src)-32]);if !same_bytes(checksum[:],src[len(src)-32:]) {return .Checksum}
	x:=Frame_View{identity=a.identity,epoch=a.epoch,tick=a.tick}
	y:=Frame_View{identity=b.identity,epoch=b.epoch,tick=b.tick}
	for p in Part {x.parts[p]=src[at:at+int(a.lengths[p])];at+=int(a.lengths[p])}
	for p in Part {y.parts[p]=src[at:at+int(b.lengths[p])];at+=int(b.lengths[p])}
	info.accepted_inputs=src[at:at+int(accepted)];at+=int(accepted)
	info.predicted_inputs=src[at:at+int(predicted)]
	actual_a,ea:=sign(x,limits);if ea!=.None {return ea}
	actual_b,eb:=sign(y,limits);if eb!=.None {return eb}
	if a!=actual_a || b!=actual_b {return .Checksum}
	return trace_capture(out,x,y,info,limits,allocator)
}
@(private)
same_bytes :: proc(a,b:[]u8)->bool {if len(a)!=len(b) {return false};for v,i in a {if v!=b[i] {return false}};return true}

// Text is a small index into the complete binary artifact. Destroy returned
// text with the supplied allocator; no temporary allocator lifetime is hidden.
trace_text :: proc(trace:^Trace, allocator:=context.allocator)->string {
	builder:strings.Builder;strings.builder_init(&builder,allocator);defer strings.builder_destroy(&builder)
	if trace==nil || !trace.ready {fmt.sbprintf(&builder,"No captured complete-frame mismatch.\n");return strings.clone(strings.to_string(builder),allocator)}
	a,b,info:=trace.expected,trace.actual,trace.input_context
	fmt.sbprintf(&builder,"Complete physics mismatch: %v; first component byte %d\n",trace.difference,trace.first_byte)
	fmt.sbprintf(&builder,"Expected epoch/tick %d/%d; actual %d/%d; input window %d..%d; depth %d; source/sequence %d/%d\n",a.epoch,a.tick,b.epoch,b.tick,info.from_tick,info.to_tick,info.depth,info.source,info.sequence)
	for sig,i in ([2]Signature{a,b}) {
		sig := sig
		id:=sig.identity
		fmt.sbprintf(&builder,"%s formats solver/recovery/game/observations %d/%d/%d/%d; profile %d\n",i==0?"expected":"actual",id.solver_format,id.recovery_format,id.game_format,id.observation_format,id.profile)
		names := [6]string{"build_target","assets","solver_schema","game_schema","observation_schema","input_schema"}
		for h,j in ([6]Digest{id.build_target,id.assets,id.solver_schema,id.game_schema,id.observation_schema,id.input_schema}) {
			h := h; fmt.sbprintf(&builder,"  %s: ",names[j]);append_hex(&builder,h[:]);fmt.sbprintf(&builder,"\n")
		}
		for p in Part {fmt.sbprintf(&builder,"  %v bytes=%d sha256=",p,sig.lengths[p]);append_hex(&builder,sig.digests[p][:]);fmt.sbprintf(&builder,"\n")}
		fmt.sbprintf(&builder,"  complete: ");append_hex(&builder,sig.complete[:]);fmt.sbprintf(&builder,"\n")
	}
	for bytes,i in ([2][]u8{info.accepted_inputs,info.predicted_inputs}) {
		fmt.sbprintf(&builder,"%s input bytes=%d prefix=",i==0?"accepted":"predicted",len(bytes));append_hex(&builder,bytes[:min(len(bytes),64)]);fmt.sbprintf(&builder,"\n")
	}
	fmt.sbprintf(&builder,"Full bytes and inputs are retained in the versioned trace artifact. Checksums are not authentication; target compatibility is explicit.\n")
	return strings.clone(strings.to_string(builder),allocator)
}
@(private)
append_hex :: proc(builder:^strings.Builder, bytes:[]u8) {
	digits:="0123456789abcdef";for v in bytes {pair:=[2]u8{digits[v>>4],digits[v&15]};strings.write_bytes(builder,pair[:])}
}
