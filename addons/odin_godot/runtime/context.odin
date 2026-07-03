package script_runtime

import "base:runtime"

// ----------------------------------------------------------------------------
// Per-target Odin `context` for compiled-script entry points.
//
// scriptgen emits `context = rt.script_context()` at the top of every generated
// `proc "c"` trampoline (lifecycle wrappers + method trampolines). That context must
// carry a WORKING allocator AND temp_allocator, because user script procs allocate —
// e.g. a HUD building its Label text with `core:fmt`, which formats into
// `context.temp_allocator`.
//
//   * NATIVE: `script_context_hook` is left nil, so this returns
//     `runtime.default_context()` (heap allocator + a real default temp allocator) with
//     ONE addition: `assertion_failure_proc` is pointed at
//     `native_script_assertion_failure` (panic_native.odin), so a script panic/assert
//     prints a grep-able ODIN_SCRIPT_PANIC line to stderr AND — once the core has
//     installed the push_error hook post-boot — shows up red in the editor Output,
//     instead of dying visible only on a (possibly nowhere-routed) stderr.
//
//   * WEB (freestanding_wasm32): `runtime.default_context()` is UNUSABLE for scripts.
//     `ODIN_OS == .Freestanding` forces `NO_DEFAULT_TEMP_ALLOCATOR`, so its
//     temp_allocator is nil — every `core:fmt`/temp allocation silently fails and
//     yields "" — and its main allocator is Odin's own wasm allocator, which is unsafe
//     inside a shared Emscripten SIDE_MODULE (it grows linear memory via `memory.grow`,
//     colliding with Emscripten's malloc arena and detaching cached HEAP views). The
//     CORE, at web init, installs `script_context_hook` with an engine-backed,
//     alignment-correct context so allocating scripts work in the browser. See
//     core/scripts_web.odin (web_script_context) and core/web.odin.
// ----------------------------------------------------------------------------

// Installed by the core on WEB (see core/scripts_web.odin); nil on native.
script_context_hook: proc "contextless" () -> runtime.Context

@(require_results)
script_context :: proc "contextless" () -> runtime.Context {
	if script_context_hook != nil {
		return script_context_hook()
	}
	c := runtime.default_context()
	// NATIVE panic/assert surfacing (see panic_native.odin). Excluded on freestanding
	// wasm32, where the web hook above is always installed before any script runs (and
	// the freestanding fallthrough context must stay untouched).
	when ODIN_OS != .Freestanding {
		c.assertion_failure_proc = native_script_assertion_failure
	}
	return c
}
