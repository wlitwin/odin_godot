#+build windows, wasm32, wasm64p32
package core

import "godot:godot"

// Stub of the native stack capture for targets without execinfo `backtrace()` (Windows
// and the web/wasm build). Returns a well-formed EMPTY Array so `_debug_get_current_stack_info`
// stays correctly typed. Windows would use `CaptureStackBackTrace` + `SymFromAddr`; web has
// no native stack to walk. See core/debug.odin for the darwin/linux implementation.
debug_capture_odin_stack :: proc(skip := 0) -> godot.Array {
	return godot.new_array_default()
}
