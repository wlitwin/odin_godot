#+build darwin, linux, windows
package core

import "godot:gdext"
import "godot:godot"
import rt "godot:runtime"

import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:strings"

// ----------------------------------------------------------------------------
// NATIVE scripts-dll loading + the manifest/boot handshake (and Phase 4 hot reload).
// Excluded from the WEB build, where the scripts are linked into the same module
// (see scripts_web.odin). On WEB there is no dlopen/editor/recompile.
//
// On load the core:
//   1. dlopens the scripts dll (`dynlib`),
//   2. calls `odin_scripts_boot(gpa, lib)` so the scripts dll initializes ITS OWN
//      copy of the gdext/godot globals (it cannot share ours — see scripts/boot.odin),
//   3. calls `odin_scripts_manifest()` to learn which classes it provides,
//   4. indexes them by class name (index_scripts_manifest).
// ----------------------------------------------------------------------------

// On WEB, the runtime startup is run explicitly (see scripts_web.odin); on native the
// dll's own load/boot handles it, so this is a no-op the shared entry point can call.
web_startup :: proc "contextless" () {}

// Field names MUST match the scripts dll's exported symbol names, since
// `dynlib.initialize_symbols` resolves each field by its name.
@(private)
Scripts_Dll :: struct {
	__handle:             dynlib.Library,
	odin_scripts_boot:    proc "c" (
		get_proc_address: gdext.ExtensionInterfaceGetProcAddress,
		library: gdext.ExtensionClassLibraryPtr,
	),
	odin_scripts_manifest: proc "c" () -> (descs: [^]rt.Class_Desc, count: int),
	// Typed cross-script handoff (Option A): the core calls this right after boot to hand
	// the scripts dll its `obj -> Odin script struct` resolver (core's odin_script_struct),
	// which `rt.script_of` then uses. Exported by the runtime package (linked into the dll).
	odin_scripts_set_core_api: proc "c" (script_struct: rt.Script_Struct_Proc),
}

@(private)
scripts_dll: Scripts_Dll

// dladdr — resolve the file path of the shared object containing a given address.
// Non-POSIX but present in libSystem (Darwin) / libc+libdl (Linux). Lets the core
// find its OWN on-disk path so it can load the scripts dll sitting beside it.
when ODIN_OS == .Darwin {
	foreign import libsys "system:System"
} else when ODIN_OS == .Linux {
	foreign import libsys {"system:c", "system:dl"}
}
when ODIN_OS == .Darwin || ODIN_OS == .Linux {
	Dl_info :: struct {
		dli_fname: cstring,
		dli_fbase: rawptr,
		dli_sname: cstring,
		dli_saddr: rawptr,
	}
	foreign libsys {
		dladdr :: proc "c" (addr: rawptr, info: ^Dl_info) -> i32 ---
	}
}

// Directory containing THIS (the core) dll, via dladdr on one of our own procs.
// In an exported game `res://` is packed and not `dlopen`able, so the scripts dll is
// found as a sibling of the core dll instead (both are placed beside the executable
// by the exporter: macOS Contents/Frameworks, next-to-exe elsewhere).
@(private)
core_dll_dir :: proc(allocator := context.allocator) -> (string, bool) {
	when ODIN_OS == .Darwin || ODIN_OS == .Linux {
		info: Dl_info
		if dladdr(cast(rawptr)odin_scripts_load, &info) != 0 && info.dli_fname != nil {
			path := string(info.dli_fname)
			if idx := strings.last_index_byte(path, '/'); idx >= 0 {
				return strings.clone(path[:idx], allocator), true
			}
		}
	}
	return "", false
}

// Resolve the scripts dll path. Order: explicit env override (test harness) ->
// sibling of the core dll (works in BOTH dev and exported builds) -> globalized
// `res://bin/libodinscripts.<ext>` (dev fallback).
@(private)
scripts_dll_path :: proc() -> string {
	if override, ok := os.lookup_env("ODIN_SCRIPTS_DLL", context.allocator); ok && override != "" {
		return override
	}
	ext := ".dylib"
	when ODIN_OS == .Windows {ext = ".dll"}
	when ODIN_OS == .Linux {ext = ".so"}

	if dir, ok := core_dll_dir(); ok {
		defer delete(dir)
		cand := strings.concatenate({dir, "/libodinscripts", ext})
		if os.is_file(cand) {
			return cand
		}
		delete(cand)
	}

	res := strings.concatenate({"res://bin/libodinscripts", ext})
	defer delete(res)
	gres := godot.new_string_odin(res)
	global := godot.project_settings_globalize_path(godot.singleton_project_settings(), gres)
	return string_to_odin(global)
}

@(private)
odin_scripts_load :: proc() {
	// Core-owned bookkeeping (the class map + cloned names) must use the alignment-
	// correct allocator: Godot's `mem_alloc` ignores alignment, but Odin maps assert
	// cache-line alignment. The godot context allocator is fine for transient Godot
	// values, so we only override `allocator`, not `temp_allocator`.
	context.allocator = core_allocator()

	path := scripts_dll_path()
	defer delete(path)

	_, ok := dynlib.initialize_symbols(&scripts_dll, path, "", "__handle")
	if !ok || scripts_dll.__handle == nil || scripts_dll.odin_scripts_boot == nil || scripts_dll.odin_scripts_manifest == nil {
		gdext_print("odin: failed to load scripts dll", path)
		return
	}

	// Boot FIRST so the scripts dll's gdext/godot globals are live, THEN read the manifest.
	scripts_dll.odin_scripts_boot(saved_get_proc_address, gdext.library)

	// Hand the scripts dll the typed cross-script resolver (Option A). Optional: an older
	// scripts dll without the runtime symbol simply leaves rt.script_of returning nil.
	if scripts_dll.odin_scripts_set_core_api != nil {
		scripts_dll.odin_scripts_set_core_api(odin_script_struct)
	}

	descs, n := scripts_dll.odin_scripts_manifest()
	index_scripts_manifest(descs, n)
}

// ----------------------------------------------------------------------------
// Phase 4 — hot reload: swap the scripts dll under a RUNNING game and re-bind all
// live instances to the new code, preserving their state.
//
// Triggered by `OdinScript._reload` (i.e. GDScript `script.reload(true)`), which the
// engine routes here. The on-disk `libodinscripts.<ext>` has already been rebuilt
// (v2) by the dev's save+compile (or, in the milestone test, an explicit rebuild).
//
// Sequence (no engine callback may run a stale proc mid-swap, so this is synchronous
// and finishes the re-bind before returning):
//   1. Copy the freshly-built dll to a UNIQUE path. macOS `dlopen` of a path it has
//      already loaded returns the CACHED image (the old code) even after dlclose, so
//      a unique path is required to guarantee the new code is mapped.
//   2. dlopen the unique path; `odin_scripts_boot` it so the NEW dll initializes its
//      OWN gdext/godot globals (same first-load handshake); pull its manifest.
//   3. Rebuild the class map; invalidate the per-class caches.
//   4. Re-bind every live instance to the new descriptors (same-layout keeps state in
//      place; changed-layout migrates exports — see rebind_all_instances).
// The OLD handle is deliberately kept mapped (not dlclose'd): lingering cstrings/proc
// ptrs stay valid, and after the re-bind no live instance dispatches into it.
// ----------------------------------------------------------------------------

@(private)
reload_counter: int

@(private)
odin_scripts_reload :: proc() -> bool {
	context.allocator = core_allocator()

	base := scripts_dll_path()
	defer delete(base)

	// 1. Snapshot the freshly-built dll to a unique path (force a fresh image).
	data, read_err := os.read_entire_file(base, context.allocator)
	if read_err != nil {
		gdext_print("odin reload: cannot read scripts dll", base)
		return false
	}
	defer delete(data)

	reload_counter += 1
	unique := fmt.aprintf("%s.r%d.dylib", base, reload_counter)
	defer delete(unique)
	if write_err := os.write_entire_file(unique, data); write_err != nil {
		gdext_print("odin reload: cannot write unique dll", unique)
		return false
	}

	// 2. Load + boot + manifest the NEW dll.
	new_dll: Scripts_Dll
	_, lok := dynlib.initialize_symbols(&new_dll, unique, "", "__handle")
	if !lok ||
	   new_dll.__handle == nil ||
	   new_dll.odin_scripts_boot == nil ||
	   new_dll.odin_scripts_manifest == nil {
		gdext_print("odin reload: failed to load new scripts dll", unique)
		return false
	}
	new_dll.odin_scripts_boot(saved_get_proc_address, gdext.library)
	// Re-hand the resolver to the freshly-swapped dll (it has its own runtime globals).
	if new_dll.odin_scripts_set_core_api != nil {
		new_dll.odin_scripts_set_core_api(odin_script_struct)
	}
	descs, n := new_dll.odin_scripts_manifest()

	// 3. Rebuild the class map; free the previous (heap-cloned) keys.
	new_classes := make(map[string]rt.Class_Desc)
	for i in 0 ..< n {
		d := descs[i]
		name := strings.clone(string(d.name))
		new_classes[name] = d
	}
	for k in scripts_classes {
		delete(k)
	}
	delete(scripts_classes)
	scripts_classes = new_classes

	// Invalidate the per-class caches (offsets/interned names rebuilt lazily by
	// ensure_class_cache during rebind). Old caches are leaked — a small, documented
	// per-reload cost acceptable for a dev loop.
	if class_caches != nil {
		clear(&class_caches)
	}

	// 4. Re-bind all live instances BEFORE returning (no stale proc may run after).
	rebind_all_instances()

	scripts_dll = new_dll
	return true
}

@(private)
gdext_print :: proc(msg: string, detail: string) {
	// Surface load failures on stderr; the engine logger is not guaranteed up here.
	os.write_string(os.stderr, msg)
	os.write_string(os.stderr, ": ")
	os.write_string(os.stderr, detail)
	os.write_string(os.stderr, "\n")
}
