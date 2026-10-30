#+build darwin, linux
package core

import "godot:godot"

import "core:os"
import "core:strings"

// ----------------------------------------------------------------------------
// Native call-stack capture for `_debug_get_current_stack_info`.
//
// Odin scripts are AOT-compiled native code, so there is NO interpreter stack to walk
// the way GDScript does. Instead we capture the REAL native call stack and resolve each
// return address with `dladdr()` (already used in scripts_native.odin to locate the core
// dll). We keep only the frames that belong to the compiled scripts dll, so the engine
// sees the Odin script call chain rather than engine / libc / core noise.
//
// IMPORTANT: we use libunwind's `_Unwind_Backtrace`, NOT execinfo's `backtrace()`. Odin
// omits frame pointers (it has no flag to keep them), so the classic frame-pointer
// `backtrace()` returns only the innermost frame here. `_Unwind_Backtrace` walks the
// DWARF/compact-unwind tables (the same info lldb uses) and recovers the full chain even
// with frame pointers omitted. (Verified: backtrace()=1 frame vs _Unwind_Backtrace=full.)
//
// `dladdr`'s `dli_sname` for an Odin proc built with `-debug` is already readable, e.g.
// `showcase_scripts::coin_collect` (verified: `nm libodinscripts.dylib | grep coin_collect`
// lists `_showcase_scripts::coin_collect`; dladdr strips the leading underscore). That IS
// the "function" Godot wants. Source line numbers need DWARF resolution (out of scope) —
// we report line 0 and use the dll path as "source". (See docs/debugging.md.)
// ----------------------------------------------------------------------------

// libunwind lives in libSystem on Darwin and libc/libgcc_s on Linux — both already linked
// by the core dll. `Dl_info` / `dladdr` are declared package-wide in scripts_native.odin
// (darwin/linux), so we reuse them here.
when ODIN_OS == .Darwin {
	foreign import libunwind "system:System"
} else {
	foreign import libunwind "system:c"
}

// Opaque libunwind cursor; we only ever pass a pointer to it.
Unwind_Context :: struct {}
// _URC_NO_REASON (0) — returned from the trace callback to keep walking.
URC_NO_REASON :: 0

foreign libunwind {
	_Unwind_Backtrace :: proc "c" (fn: proc "c" (ctx: ^Unwind_Context, arg: rawptr) -> i32, arg: rawptr) -> i32 ---
	_Unwind_GetIP :: proc "c" (ctx: ^Unwind_Context) -> uintptr ---
}

// The substring that identifies a frame as belonging to the compiled scripts dll. Kept
// as a constant so the unit probe (tests/debug) can assert against the same value.
SCRIPTS_DLL_MARKER :: "libodinscripts"

@(private = "file")
MAX_FRAMES :: 256

@(private = "file")
Stack_Collector :: struct {
	addrs: [MAX_FRAMES]rawptr,
	n:     int,
}

// libunwind trace callback: record this frame's instruction pointer. `proc "c"` (no Odin
// context), so it threads its state through the `arg` pointer.
@(private = "file")
unwind_collect :: proc "c" (ctx: ^Unwind_Context, arg: rawptr) -> i32 {
	c := cast(^Stack_Collector)arg
	if c.n < MAX_FRAMES {
		c.addrs[c.n] = rawptr(_Unwind_GetIP(ctx))
		c.n += 1
	}
	return URC_NO_REASON
}

// debug_capture_odin_stack walks the native stack and returns a Godot `Array` of
// `Dictionary{ "function": String, "line": int(0), "source": String }`, one per frame
// that belongs to the scripts dll, OUTERMOST script frame first (call order). This is the
// exact shape Godot expects back from `_debug_get_current_stack_info`. The returned Array
// is owned by the caller (the engine copies it out of the `ret` slot).
//
// `skip` drops the innermost N frames (this proc + the unwind callback + the virtual
// trampoline) so the reported chain starts at real script code.
debug_capture_odin_stack :: proc(skip := 0) -> godot.Array {
	arr := godot.new_array_default()

	col: Stack_Collector
	_Unwind_Backtrace(unwind_collect, &col)
	if col.n <= 0 {
		return arr
	}

	// dladdr resolves each return address to its symbol + owning file. We collect the
	// scripts-dll frames innermost-first, then push them so the engine sees the natural
	// call order (outermost script frame at index 0).
	Frame :: struct {
		sym:   cstring,
		fname: cstring,
	}
	frames: [MAX_FRAMES]Frame
	count := 0
	for i in skip ..< col.n {
		info: Dl_info
		if dladdr(col.addrs[i], &info) == 0 {
			continue
		}
		if info.dli_sname == nil || info.dli_fname == nil {
			continue
		}
		fname := string(info.dli_fname)
		sym := string(info.dli_sname)
		// Keep ONLY frames that live in the scripts dll. Odin script procs additionally
		// carry a `pkg::proc` symbol (the `::` check), so engine / libc / core frames —
		// different dll, no `::` — fall away and the engine sees just the Odin chain.
		in_scripts_dll := strings.contains(fname, SCRIPTS_DLL_MARKER)
		looks_like_odin := strings.contains(sym, "::")
		if !in_scripts_dll || !looks_like_odin {
			continue
		}
		frames[count] = Frame{sym = info.dli_sname, fname = info.dli_fname}
		count += 1
		if count >= len(frames) {
			break
		}
	}

	// Honest integration probe: when ODIN_DEBUG_STACK_DUMP=1, echo the captured Odin
	// frames to stderr so a test can observe WHETHER (and when) the engine actually calls
	// `_debug_get_current_stack_info`. No-op in normal runs.
	if _, dump := os.lookup_env("ODIN_DEBUG_STACK_DUMP", context.allocator); dump {
		os.write_string(os.stderr, "ODIN_STACK_BEGIN\n")
		for i in 0 ..< count {
			os.write_string(os.stderr, "ODIN_STACK_FRAME ")
			os.write_string(os.stderr, string(frames[i].sym))
			os.write_string(os.stderr, "\n")
		}
		os.write_string(os.stderr, "ODIN_STACK_END\n")
	}

	// Push outermost-first (reverse of the innermost-first capture order).
	for i := count - 1; i >= 0; i -= 1 {
		d := debug_make_frame_dict(frames[i].sym, frames[i].fname)
		dv := godot.variant_from_dictionary(&d)
		godot.array_push_back(&arr, dv)
	}
	return arr
}

// Build one `{ "function", "line", "source" }` Dictionary for a stack frame.
@(private = "file")
debug_make_frame_dict :: proc(symbol: cstring, source: cstring) -> godot.Dictionary {
	d := godot.new_dictionary_default()

	set := proc(d: ^godot.Dictionary, key: cstring, val: godot.Variant) {
		ks := godot.new_string_cstring(key)
		kv := godot.variant_from_string(&ks)
		val := val
		godot.dictionary_set(d, kv, val)
	}

	fn_s := godot.new_string_cstring(symbol)
	set(&d, "function", godot.variant_from_string(&fn_s))

	line := godot.Int(0)
	set(&d, "line", godot.variant_from_int(&line))

	src_s := godot.new_string_cstring(source)
	set(&d, "source", godot.variant_from_string(&src_s))

	return d
}
