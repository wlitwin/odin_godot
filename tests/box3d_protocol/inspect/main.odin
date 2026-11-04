// Offline diagnostic artifact inspection. No native physics linkage or import.
package main

import "core:os"
import "core:fmt"
import "core:mem"
import d "godot:box3d/diagnostics"

main :: proc() {
	if len(os.args)!=2 {fmt.eprintln("usage: inspect-trace TRACE_FILE");os.exit(2)}
	info,error:=os.stat(os.args[1],context.allocator)
	if error!=nil || info.size<d.TRACE_HEADER_BYTES+32 || info.size>9*1024*1024 {
		fmt.eprintln("Invalid or over-limit diagnostic artifact.");os.exit(1)
	}
	data,read_error:=os.read_entire_file(os.args[1],context.allocator)
	if read_error!=nil {fmt.eprintln("Cannot read diagnostic artifact.");os.exit(1)}
	defer delete(data)
	trace:d.Trace;defer d.trace_destroy(&trace)
	limits:=d.Limits{2*1024*1024,4*1024*1024,256*1024}
	if err:=d.trace_decode(&trace,data,limits);err!=.None {fmt.eprintf("Diagnostic decode failed: %v\n",err);os.exit(1)}
	// Re-encoding independently checks every retained component and canonical
	// header before displaying the artifact's first mismatch.
	n,encode_error:=d.trace_encode(&trace,nil,limits)
	if encode_error!=.None || n!=len(data) {fmt.eprintln("Diagnostic roundtrip sizing failed.");os.exit(1)}
	encoded:=make([]u8,n);defer delete(encoded)
	_,encode_error=d.trace_encode(&trace,encoded,limits)
	if encode_error!=.None || mem.compare(encoded,data)!=0 {fmt.eprintln("Diagnostic roundtrip differs.");os.exit(1)}
	text:=d.trace_text(&trace);defer delete(text);fmt.print(text)
	fmt.printf("BOX3D_TRACE_INSPECT_OK bytes=%d expected_solver_bytes=%d actual_solver_bytes=%d accepted_input_bytes=%d predicted_input_bytes=%d\n",
		len(data),len(trace.expected_frame.parts[.Solver]),len(trace.actual_frame.parts[.Solver]),len(trace.input_context.accepted_inputs),len(trace.input_context.predicted_inputs))
}
