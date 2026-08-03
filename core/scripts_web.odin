#+build wasm32, wasm64p32
package core

import rt "godot:runtime"
import gd "godot:godot"
import "base:runtime"
import "core:fmt"

// ----------------------------------------------------------------------------
// WEB scripts wiring. The scripts package + the `runtime` registry are linked INTO
// this same wasm module, so there is no dlopen/boot handshake and no hot reload.
// (Native equivalents live in scripts_native.odin, excluded from the wasm build.)
// ----------------------------------------------------------------------------

// The Odin `context` every compiled-script trampoline (lifecycle wrappers + method
// trampolines) runs under on web. `runtime.default_context()` is unusable for scripts on
// freestanding_wasm32 — its temp_allocator is nil (so `core:fmt`/temp allocations silently
// yield "", e.g. the HUD's label text) and its main allocator is Odin's own wasm allocator,
// which is unsafe in a shared SIDE_MODULE (memory.grow collides with Emscripten's heap).
// We start from the default context (logger/assertion/random) but swap BOTH allocators to
// the engine-backed, alignment-correct allocator (see web.odin), AND repoint
// `random_generator` at a persistent, pre-seeded package-global state (see below). scriptgen
// routes the trampolines here via rt.script_context() + the hook installed in web_startup.
//
// Note: temp allocations made here are not freed until the engine heap reclaims them; the
// showcase HUD only formats on a score CHANGE (guarded), so this is negligible.
@(private)
web_script_context :: proc "contextless" () -> runtime.Context {
	c := runtime.default_context()
	a := web_aligned_allocator()
	c.allocator = a
	c.temp_allocator = a
	// Make `core:math/rand` work in the browser. The default chacha8 generator carried by
	// runtime.default_context() lazily self-seeds from the OS entropy source on first use —
	// but freestanding_wasm32 has none (runtime.HAS_RAND_BYTES == false), so that path hits
	// `panic_contextless("no runtime entropy source")` -> wasm `unreachable` trap on EVERY
	// rand call. Point the context at our own state (seeded below + in web_startup) so it is
	// already `_seeded` and never reaches the entropy path. One shared global state -> the
	// sequence ADVANCES across script calls instead of restarting each invocation. (Native is
	// unaffected: scripts_native.odin never touches random_generator, so native scripts keep
	// runtime.default_context()'s OS-seeded generator.)
	//
	// REAL ENTROPY: web_startup seeded `web_random_state` with a fixed fallback so rand never
	// traps even before the engine is up; here, on the FIRST script context (the engine is
	// fully booted by the time any script lifecycle runs), we RESEED once from Godot's own
	// global RNG, which the web platform seeds from the browser's entropy. So each page load
	// gets a different sequence — no extra JS/Emscripten glue.
	if !web_random_seeded {
		web_random_seeded = true
		web_reseed_random_from_engine()
	}
	c.random_generator = runtime.default_random_generator(&web_random_state)
	// Surface panics/asserts/logs in the browser console. The freestanding defaults are
	// silent (the assertion handler is literally `// Do nothing` then traps; the logger's
	// stderr write is a no-op), which is exactly why the rand entropy panic showed only a
	// bare `unreachable executed`. Route both through Godot's print path (reaches the JS
	// console) — see web_assertion_failure_proc / web_logger_proc below.
	c.assertion_failure_proc = web_assertion_failure_proc
	c.logger = runtime.Logger{web_logger_proc, nil, .Debug, nil}
	return c
}

// Persistent PRNG state backing `context.random_generator` for compiled scripts on web.
// web_startup seeds it with a fixed NON-ZERO fallback (so rand can never trap, even before
// the engine RNG is reachable); the first web_script_context call then reseeds it from
// Godot's web-entropy-seeded global RNG for genuine per-run variation. A zero state is
// avoided everywhere (some PRNGs are degenerate from an all-zero seed).
@(private)
WEB_RANDOM_FALLBACK_SEED :: 0x9E3779B97F4A7C15 // golden-ratio constant; non-zero

@(private)
web_random_state: runtime.Default_Random_State

@(private)
web_random_seeded: bool // false until reseeded from the engine on the first script context

// Pull 64 bits of per-run entropy from Godot's global RNG (which the web platform seeds from
// the browser) and reseed our script PRNG with it. Contextless + allocation-free: safe to
// call from the contextless web_script_context. `randomize()` reseeds Godot's global RNG
// first; two `randi()` draws (each a random 32-bit value in an Int) compose a 64-bit seed.
@(private)
web_reseed_random_from_engine :: proc "contextless" () {
	// reset_u64 is a context-ful runtime proc (though it doesn't allocate); give it a throwaway
	// context so it's callable from here. The .Reset path only writes into web_random_state.
	context = runtime.default_context()
	gd.gd_randomize()
	hi := u64(u32(gd.gd_randi()))
	lo := u64(u32(gd.gd_randi()))
	seed := (hi << 32) | lo
	if seed == 0 {seed = WEB_RANDOM_FALLBACK_SEED} // never reseed to a degenerate zero state
	runtime.random_generator_reset_u64(runtime.default_random_generator(&web_random_state), seed)
}

// context.assertion_failure_proc for compiled scripts on web. A script `panic`, failed
// `assert`, or failed type assertion calls this (Odin bounds-checks take a separate runtime
// path that still traps silently — they don't route here). The freestanding default prints
// nothing then traps, so we format a readable message (allocation-free, into a stack buffer)
// and route it through Godot's print path BEFORE trapping. `ODIN_SCRIPT_PANIC` is a grep-able
// sentinel. Returns `!` (never returns) — terminate with runtime.trap() like the default.
@(private)
web_assertion_failure_proc :: proc(prefix, message: string, loc: runtime.Source_Code_Location) -> ! {
	buf: [1024]byte
	msg := fmt.bprintf(
		buf[:],
		"ODIN_SCRIPT_PANIC %s: %s (%s:%d:%d)",
		prefix,
		message,
		loc.file_path,
		loc.line,
		loc.column,
	)
	gd.error_str(msg) // -> push_error -> console.error
	gd.print_str(msg) // -> print     -> console.log (guarantees the message is captured)
	runtime.trap()
}

// context.logger for compiled scripts on web. The freestanding default logger writes to a
// no-op stderr, so a script using `core:log` would be silently dropped. Route it through
// Godot's print path instead: Error/Fatal -> push_error (console.error), else -> print.
@(private)
web_logger_proc :: proc(
	data: rawptr,
	level: runtime.Logger_Level,
	text: string,
	options: runtime.Logger_Options,
	location := #caller_location,
) {
	if level >= .Error {
		gd.error_str(text)
	} else {
		gd.print_str(text)
	}
}

// A SIDE_MODULE has no CRT / entry point, so the Odin `@(init)` chain is not run
// automatically. `odin_godot_init` calls this to run it explicitly — which fires each
// script's `@(init) rt.register(...)` self-registration into the shared registry.
// (`__$startup_runtime` is generated by the compiler from all `@(init)` procs.) We also
// install the web script context hook so allocating scripts work in the browser.
web_startup :: proc "contextless" () {
	rt.script_context_hook = web_script_context
	context = runtime.default_context()
	// Seed the script PRNG with a fixed NON-ZERO fallback up front, so core:math/rand can
	// never hit the (absent) OS entropy source and trap — even if something draws before the
	// first script context reseeds it from the engine (see web_script_context above).
	// reset_u64 drives the generator's .Reset mode, marking the state `_seeded`.
	runtime.random_generator_reset_u64(runtime.default_random_generator(&web_random_state), WEB_RANDOM_FALLBACK_SEED)
	runtime._startup_runtime()
}

// Read the manifest directly (same module — no dlsym). The registrations have already
// run via web_startup, so the registry is populated.
@(private)
odin_scripts_load :: proc() {
	// Single module on web: wire the typed cross-script resolver directly (no dlsym).
	rt.odin_scripts_set_core_api(odin_script_struct)
	rt.odin_scripts_set_core_api2(odin_script_struct_any)
	n: i32
	descs := rt.odin_scripts_manifest(&n)
	index_scripts_manifest(descs, int(n))
	// Registration errors from the reflection walk (run in web_startup's @(init) chain).
	// Same module — read the table directly and surface immediately: this runs at .Scene
	// init, where push_error already reaches the JS console (no frame pump on web).
	en: i32
	errs := rt.odin_scripts_registration_errors(&en)
	scripts_note_registration_errors(errs, int(en))
	scripts_surface_registration_errors()
}

// No hot reload in the browser (no compiler, no dlopen). Always reports failure.
// (`module` mirrors the native per-module signature so shared callers compile.)
@(private)
odin_scripts_reload :: proc(module := "") -> bool {
	return false
}

// No editor / compiler / filesystem in the browser, so the rebuild-on-save coordinator
// (native core/reload.odin) does not exist here. `OdinScript._reload` references this on
// all platforms; on web it is a no-op (the editor-hint branch is never taken anyway).
@(private)
reload_request :: proc() {
}
