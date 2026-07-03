package core

import "base:runtime"
import "godot:gdext"
import "core:c"
import "core:mem"

// ----------------------------------------------------------------------------
// Web / WASM build switch.
//
// Set with `-define:ODIN_GODOT_WEB=true` when building the Emscripten SIDE_MODULE
// (see build/build_web.sh). On WEB the compiled scripts package + the `runtime`
// registry are linked INTO this same wasm module (there is no `dlopen` and no editor
// /export pipeline in the browser), so:
//   * the native dynlib hot-reload + manifest/boot handshake is excluded
//     (see scripts_native.odin) and replaced by a direct in-module manifest read
//     (see scripts_web.odin),
//   * the whole export pipeline is excluded (export_plugin.odin is native-tagged),
//   * `odin_godot_init` runs the Odin `@(init)` chain itself via `web_startup`
//     (a SIDE_MODULE has no CRT/entry-point to do it), which is what fires each
//     script's `@(init) rt.register(...)` self-registration.
//
// The NATIVE path is unchanged: WEB is false, every native-only file/branch builds
// exactly as before.
// ----------------------------------------------------------------------------
WEB :: #config(ODIN_GODOT_WEB, false)

// Allocator for core-owned bookkeeping (the class map, the live-instance registry,
// the per-class caches). These need real alignment — Odin maps assert cache-line
// (64-byte) alignment, which neither the Godot allocator nor a plain malloc guarantee.
//   * native: the Odin heap allocator (already cache-line aligned).
//   * wasm: an alignment-respecting wrapper over the ENGINE's allocator. We MUST use
//     the engine's heap (gdext `mem_alloc` -> Emscripten malloc): we are a SIDE_MODULE
//     sharing one linear memory with the engine, so Odin's own wasm allocator would
//     both collide with Emscripten's arena and detach Emscripten's cached HEAP views
//     when it grows memory via raw `memory.grow`.
core_allocator :: proc() -> runtime.Allocator {
	when WEB {
		return web_aligned_allocator()
	} else {
		return runtime.heap_allocator()
	}
}

// ----------------------------------------------------------------------------
// Alignment-respecting allocator over the engine allocator (web).
//
// gdext `mem_alloc` ignores the requested alignment, but Odin maps require 64-byte
// (cache-line) aligned backing with the low bits free for capacity tagging. We
// over-allocate and store the real base pointer in a header word just before the
// returned (aligned) pointer, recovering it on free/resize. Defined unconditionally
// (it only references symbols valid on all targets) but only used on web.
// ----------------------------------------------------------------------------

@(private = "file")
WEB_ALLOC_HEADER :: size_of(rawptr)

@(private = "file")
web_aligned_alloc :: proc "contextless" (size, alignment: int) -> rawptr {
	a := max(alignment, WEB_ALLOC_HEADER)
	total := size + a + WEB_ALLOC_HEADER
	base := gdext.mem_alloc(cast(c.size_t)total)
	if base == nil {
		return nil
	}
	addr := uintptr(base) + WEB_ALLOC_HEADER
	aligned := (addr + uintptr(a) - 1) & ~(uintptr(a) - 1)
	(cast(^rawptr)(aligned - WEB_ALLOC_HEADER))^ = base
	return rawptr(aligned)
}

@(private = "file")
web_aligned_free :: proc "contextless" (ptr: rawptr) {
	if ptr == nil {
		return
	}
	base := (cast(^rawptr)(uintptr(ptr) - WEB_ALLOC_HEADER))^
	gdext.mem_free(base)
}

@(private = "file")
web_aligned_allocator_proc :: proc(
	allocator_data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	loc := #caller_location,
) -> (
	[]byte,
	mem.Allocator_Error,
) {
	switch mode {
	case .Alloc, .Alloc_Non_Zeroed:
		p := web_aligned_alloc(size, alignment)
		if p == nil {
			return nil, .Out_Of_Memory
		}
		if mode == .Alloc {
			mem.zero(p, size)
		}
		return mem.byte_slice(p, size), nil
	case .Free:
		web_aligned_free(old_memory)
		return nil, nil
	case .Free_All:
		return nil, .Mode_Not_Implemented
	case .Resize, .Resize_Non_Zeroed:
		p := web_aligned_alloc(size, alignment)
		if p == nil {
			return nil, .Out_Of_Memory
		}
		if old_memory != nil {
			mem.copy(p, old_memory, min(size, old_size))
			web_aligned_free(old_memory)
		}
		if mode == .Resize && size > old_size {
			mem.zero(rawptr(uintptr(p) + uintptr(old_size)), size - old_size)
		}
		return mem.byte_slice(p, size), nil
	case .Query_Features:
		set := (^mem.Allocator_Mode_Set)(old_memory)
		if set != nil {
			set^ = {.Alloc, .Alloc_Non_Zeroed, .Free, .Resize, .Resize_Non_Zeroed, .Query_Features}
		}
		return nil, nil
	case .Query_Info:
		return nil, .Mode_Not_Implemented
	}
	return nil, nil
}

web_aligned_allocator :: proc "contextless" () -> runtime.Allocator {
	return mem.Allocator{procedure = web_aligned_allocator_proc, data = nil}
}
