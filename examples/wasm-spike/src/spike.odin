package wasm_spike

// Spike W — minimal proof that Odin can emit a wasm object that emcc links
// into an Emscripten SIDE_MODULE exporting a callable symbol.
//
// Target: freestanding_wasm32, build-mode:obj. No OS layer, no _start.
// We export plain "c" procs so the symbol name is unmangled and emcc keeps
// them as wasm exports of the side module.

// Trivial pure proc — the ABI smoke test. GDScript-equivalent: add(2,3) == 5.
@(export, link_name = "add")
add :: proc "c" (a, b: i32) -> i32 {
	return a + b
}

// Slightly less trivial: touches memory + a loop, to confirm Odin codegen
// beyond a single add instruction links cleanly as a side module.
@(export, link_name = "sum_to")
sum_to :: proc "c" (n: i32) -> i32 {
	total: i32 = 0
	for i: i32 = 1; i <= n; i += 1 {
		total += i
	}
	return total
}
