#+build darwin, linux, windows
package core

import "godot:gdext"
import "godot:godot"
import rt "godot:runtime"

import "base:runtime"
import "core:dynlib"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:sync"

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
//   4. indexes them by canonical source path plus optional global alias.
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
	odin_scripts_manifest: proc "c" (out_count: ^i32) -> [^]rt.Class_Desc,
	// Typed cross-script handoff (Option A): the core calls this right after boot to hand
	// the scripts dll its `obj -> Odin script struct` resolver (core's odin_script_struct),
	// which `rt.script_of` then uses. Exported by the runtime package (linked into the dll).
	odin_scripts_set_core_api: proc "c" (script_struct: rt.Script_Struct_Proc),
	// The any-class resolver handoff behind `rt.script_any` (per-type dispatch tables).
	// Same pattern; optional — nil on a scripts dll built before it existed.
	odin_scripts_set_core_api2: proc "c" (script_struct_any: rt.Script_Struct_Any_Proc),
	// Panic-surfacing handoff (same pattern): the core hands the scripts dll a push_error
	// reporter right after boot, so a script panic/assert shows RED in the editor Output
	// (the runtime's assertion proc is stderr-only until this is installed). Exported by
	// runtime/panic_native.odin (linked into the dll); optional — nil on an older dll.
	odin_scripts_set_panic_report: proc "c" (report: rt.Panic_Report_Proc),
	// ABI version of the shared core<->scripts data contract (see rt.ABI_VERSION). Checked
	// before reading the manifest to reject a scripts dll built against a different addon
	// version. Absent (nil) on a dll built before this handshake existed — also a mismatch.
	odin_scripts_abi_version: proc "c" () -> u32,
	// Complete size/alignment/named-offset fingerprint for every ABI-visible descriptor.
	// This is the compatibility decision that safely replaces exact compiler lockstep.
	odin_scripts_abi_fingerprint: proc "c" () -> u64,
	// ODIN_VERSION of the compiler that built the scripts dll. Retained as provenance and
	// diagnostics; a different release is accepted only when the full ABI contract matches.
	odin_scripts_odin_version: proc "c" () -> cstring,
	// Problems the dll's runtime reflection walk recorded while building its member tables
	// at `@(init)` (see runtime/register_class.odin). Pulled after the manifest and surfaced
	// via push_error from the frame pump — a bad export is dropped LOUDLY, never silently.
	odin_scripts_registration_errors: proc "c" (out_count: ^i32) -> [^]rt.Registration_Error,
}

// Pure-data half of the native handshake. These symbols are safe to call before boot;
// keeping the inspection in one place prevents initial load and hot reload from drifting
// into different compatibility rules.
@(private = "file")
Scripts_Dll_Contract :: struct {
	abi:         u32,
	fingerprint: u64,
	odin:        string,
}

@(private = "file")
scripts_dll_has_required_symbols :: proc "contextless" (dll: ^Scripts_Dll) -> bool {
	return dll != nil &&
	       dll.__handle != nil &&
	       dll.odin_scripts_boot != nil &&
	       dll.odin_scripts_manifest != nil
}

@(private = "file")
scripts_dll_contract :: proc "contextless" (dll: ^Scripts_Dll) -> Scripts_Dll_Contract {
	contract := Scripts_Dll_Contract{
		abi  = 0,
		odin = "unknown (older scripts dll)",
	}
	if dll == nil {
		return contract
	}
	if dll.odin_scripts_abi_version != nil {
		contract.abi = dll.odin_scripts_abi_version()
	}
	if dll.odin_scripts_abi_fingerprint != nil {
		contract.fingerprint = dll.odin_scripts_abi_fingerprint()
	}
	if dll.odin_scripts_odin_version != nil {
		if version := dll.odin_scripts_odin_version(); version != nil {
			contract.odin = string(version)
		}
	}
	return contract
}

// Rejected candidates have published no descriptors or proc pointers, so they are safe
// to unload immediately. Published generations go through Script_Generation retirement
// below so live instances, removed classes, and reload-safe callback state are respected.
@(private = "file")
scripts_dll_discard :: proc(dll: ^Scripts_Dll) {
	if dll == nil {
		return
	}
	if dll.__handle != nil {
		_ = dynlib.unload_library(dll.__handle)
	}
	dll^ = {}
}

// ----------------------------------------------------------------------------
// Multi-module spike: scripts can be split into SEVERAL dlls — the MAIN module
// (res://scripts -> libodinscripts.<ext>, always present, exactly the pre-spike single
// dll) plus optional extra modules (res://modules/<name> -> libodinscripts_<name>.<ext>).
// Each module is its own Odin package with its OWN dll, its own boot handshake, and its
// own runtime registry; the core merges every module's manifest into one path map plus
// an optional global-alias map (explicit alias collisions name both sources). A single-module project is simply a g_modules table
// of length one, so the pre-spike path is unchanged.
// ----------------------------------------------------------------------------

@(private)
Scripts_Module :: struct {
	name:       string, // "" == the MAIN module. Heap-owned clone otherwise.
	path:       string, // heap-owned dll base path (the published, non-unique-copy path)
	generation: ^Script_Generation,
	// Source identities this module currently provides. Each entry is ONE heap clone shared
	// with the path-identity map key (so reload can delete/free it exactly once).
	classes: [dynamic]string,
	// Explicit `//gd:class` aliases, separately owned because they are optional and
	// never serve as runtime identity.
	global_classes: [dynamic]string,
}

@(private)
g_modules: [dynamic]Scripts_Module

// One mapped scripts-DLL image. The module owns the current generation; once replaced,
// live Odin_Instance leases are the only reason an old generation remains mapped.
// `reload_path` is a unique `.rN` copy and is deleted immediately after the handle unloads.
@(private)
Script_Generation :: struct {
	dll:          Scripts_Dll,
	module_name:  string,
	reload_path:  string,
	bytes:        int,
	serial:       int,
	instance_refs: int,
	retired:      bool,
	desc_tokens:  [dynamic]uintptr,
}

@(private)
g_script_generations: [dynamic]^Script_Generation
@(private)
g_desc_generations: map[uintptr]^Script_Generation
@(private)
g_script_generation_lock: sync.Mutex
@(private)
g_script_generation_collection_pending: bool

@(private = "file")
scripts_dll_file_size :: proc(path: string) -> int {
	info, err := os.stat(path, context.temp_allocator)
	if err != nil || info.size <= 0 {
		return 0
	}
	return int(info.size)
}

@(private = "file")
script_generation_token :: proc "contextless" (desc: rt.Class_Desc) -> uintptr {
	identity := rt.desc_identity(desc)
	if identity == nil {return 0}
	return uintptr(cast(rawptr)identity)
}

@(private = "file")
script_generation_create :: proc(dll: Scripts_Dll, module_name: string, bytes: int, reload_path := "") -> ^Script_Generation {
	context.allocator = core_allocator()
	gen := new(Script_Generation)
	gen.dll = dll
	gen.module_name = strings.clone(module_name)
	gen.reload_path = strings.clone(reload_path)
	gen.bytes = bytes
	gen.serial = reload_counter
	append(&g_script_generations, gen)
	return gen
}

@(private = "file")
script_generation_register_manifest :: proc(gen: ^Script_Generation, descs: [^]rt.Class_Desc, n: int) {
	if gen == nil {return}
	context.allocator = core_allocator()
	if g_desc_generations == nil {
		g_desc_generations = make(map[uintptr]^Script_Generation)
	}
	for i in 0 ..< n {
		token := script_generation_token(descs[i])
		if token == 0 {continue}
		g_desc_generations[token] = gen
		append(&gen.desc_tokens, token)
	}
}

// Shared instance.odin hook. The descriptor's identity cstring lives in exactly one
// mapped image, making its address a stable generation token even when path bytes match.
@(private)
script_generation_for_desc :: proc "contextless" (desc: rt.Class_Desc) -> rawptr {
	token := script_generation_token(desc)
	if token == 0 || g_desc_generations == nil {return nil}
	return g_desc_generations[token]
}

@(private)
script_generation_retain :: proc "contextless" (opaque: rawptr) {
	gen := cast(^Script_Generation)opaque
	if gen == nil {return}
	sync.lock(&g_script_generation_lock)
	gen.instance_refs += 1
	sync.unlock(&g_script_generation_lock)
}

@(private)
script_generation_release :: proc "contextless" (opaque: rawptr) {
	gen := cast(^Script_Generation)opaque
	if gen == nil {return}
	sync.lock(&g_script_generation_lock)
	if gen.instance_refs > 0 {
		gen.instance_refs -= 1
	}
	if gen.retired && gen.instance_refs == 0 {
		g_script_generation_collection_pending = true
	}
	sync.unlock(&g_script_generation_lock)
}

@(private = "file")
script_generation_retire :: proc(gen: ^Script_Generation) {
	if gen == nil {return}
	sync.lock(&g_script_generation_lock)
	gen.retired = true
	g_script_generation_collection_pending = true
	sync.unlock(&g_script_generation_lock)
}

// Writer-gate-only collector. A zero-ref retired image has no executing trampoline
// (the gate drained those), no live descriptor/cache/user tuple, and no unacknowledged
// proc-bearing state. Property lists point only into separately-owned core caches.
@(private = "file")
script_generations_collect_at_gate :: proc() {
	context.allocator = core_allocator()
	sync.lock(&g_script_generation_lock)
	g_script_generation_collection_pending = false
	for i := len(g_script_generations) - 1; i >= 0; i -= 1 {
		gen := g_script_generations[i]
		if gen == nil || !gen.retired || gen.instance_refs != 0 {continue}
		reload_path := strings.clone(gen.reload_path, context.temp_allocator)
		module_name := strings.clone(gen.module_name, context.temp_allocator)
		serial := gen.serial
		bytes := gen.bytes

		// Keep the ownership lock from spanning platform loader/finalizer code. The
		// execution writer gate prevents a descriptor lookup while the lock is open.
		dll := gen.dll
		sync.unlock(&g_script_generation_lock)
		unloaded := dll.__handle == nil || dynlib.unload_library(dll.__handle)
		if !unloaded {
			gdext_print(
				"ODIN_RELOAD_GENERATION_UNLOAD_FAILED",
				fmt.tprintf(
					"module=%s generation=%d; will retry: %s",
					module_display(module_name),
					serial,
					dynlib.last_error(),
				),
			)
		}
		sync.lock(&g_script_generation_lock)
		if !unloaded {
			g_script_generation_collection_pending = true
			continue
		}

		for token in gen.desc_tokens {
			if current, ok := g_desc_generations[token]; ok && current == gen {
				delete_key(&g_desc_generations, token)
			}
		}
		delete(gen.desc_tokens)
		delete(gen.module_name)
		delete(gen.reload_path)
		free(gen)
		unordered_remove(&g_script_generations, i)

		// Filesystem work and logging likewise need no ownership lock.
		sync.unlock(&g_script_generation_lock)
		if reload_path != "" {os.remove(reload_path)}
		gdext_print(
			"ODIN_RELOAD_GENERATION_UNLOADED",
			fmt.tprintf("module=%s generation=%d bytes=%d", module_display(module_name), serial, bytes),
		)
		sync.lock(&g_script_generation_lock)
	}
	sync.unlock(&g_script_generation_lock)
}

// Called after an ordinary instance free. It takes the writer gate itself so the last
// removed/blocked instance can retire its image without waiting for another reload.
@(private)
script_generations_collect_pending :: proc() {
	sync.lock(&g_script_generation_lock)
	pending := g_script_generation_collection_pending
	sync.unlock(&g_script_generation_lock)
	if !pending || !script_reload_can_begin() {return}
	script_reload_begin()
	script_generations_collect_at_gate()
	script_reload_end()
}

// Human-readable module name for error messages.
@(private = "file")
module_display :: proc(name: string) -> string {
	return name == "" ? "main (res://scripts)" : name
}

@(private = "file")
module_index :: proc(name: string) -> int {
	for m, i in g_modules {
		if m.name == name {
			return i
		}
	}
	return -1
}

// Index of the module currently providing an explicit global alias, or -1.
@(private = "file")
module_owning_class :: proc(class: string) -> int {
	for m, i in g_modules {
		for c in m.global_classes {
			if c == class {
				return i
			}
		}
	}
	return -1
}

@(private = "file")
module_owning_identity :: proc(identity: string) -> int {
	for m, i in g_modules {
		for p in m.classes {
			if p == identity {return i}
		}
	}
	return -1
}

// Set by odin_scripts_load when no scripts dll could be loaded (the expected state of a
// fresh install: the prebuilt core is here, but the user's .odin scripts aren't compiled
// yet). The main-thread frame pump reads these to surface ONE actionable editor warning.
@(private)
g_scripts_missing: bool
@(private)
g_scripts_missing_warned: bool

// Set when the scripts dll's semantic ABI version or full layout fingerprint didn't match.
@(private)
g_scripts_abi_skew: bool
@(private)
g_abi_core: u32
@(private)
g_abi_scripts: u32
@(private)
g_abi_core_fingerprint: u64
@(private)
g_abi_scripts_fingerprint: u64

// surface_load_failure_runtime — in a SHIPPED GAME (NOT the editor), a missing or incompatible
// scripts dll means the game runs with zero Odin scripts. Push a visible error to the game log
// instead of dying silently. No-op in the editor (it instead defers a friendly one-shot
// warning from the frame pump — scripts_surface_missing_warning / the ABI-skew branch).
@(private)
surface_load_failure_runtime :: proc(detail: string) {
	if bool(godot.engine_is_editor_hint(godot.singleton_engine())) {
		return
	}
	// Distinguish a game launched from the EDITOR (you pressed Play but never built your
	// scripts) from a real EXPORTED build (shipped without its dll). The "editor" OS feature is
	// set for any non-exported run, including editor Play — so the fix advice can be accurate.
	feat := godot.new_string_cstring("editor")
	editor_run := bool(godot.os_has_feature(godot.singleton_os(), feat))
	fix :=
		"An exported game must ship libodinscripts beside the executable; rebuild/re-export."
	if editor_run {
		fix =
			"Build your Odin scripts first: in the editor use Project > Tools > Build Odin Scripts " +
			"(or run addons/odin_godot/build/build_scripts.sh / save a script), then press Play again."
	}
	msg := godot.new_string_odin(
		fmt.tprintf(
			"odin_godot: Odin scripts failed to load (%s) — they will NOT run. %s",
			detail,
			fix,
		),
	)
	godot.gd_push_error(godot.variant_from_string(&msg))
}

// Surface a ONE-TIME, actionable warning in the editor console when no scripts dll was
// loaded. Called from the main-thread frame pump (lv_frame) where the engine + editor are
// up. Editor-only: a shipped game with no scripts dll already printed to stderr at load and
// must never nag a player. Tells the user this is the normal first-run state and how to fix.
@(private)
scripts_surface_missing_warning :: proc() {
	if !g_scripts_missing && !g_scripts_abi_skew {
		return
	}
	if g_scripts_missing_warned {
		return
	}
	if !bool(godot.engine_is_editor_hint(godot.singleton_engine())) {
		g_scripts_missing_warned = true // never warn outside the editor
		return
	}
	g_scripts_missing_warned = true
	if g_scripts_abi_skew {
		// Loaded, but built against a different odin_godot version — a clear "rebuild" message,
		// not the fresh-install one.
		msg := godot.new_string_odin(
			fmt.tprintf(
				"odin_godot: your scripts dll has an incompatible native contract " +
					"(core ABI v%d/fp=%016x, scripts v%d/fp=%016x). Rebuild it: addons/odin_godot/build/build_scripts.sh " +
					"(your scripts won't load until you do).",
				g_abi_core,
				g_abi_core_fingerprint,
				g_abi_scripts,
				g_abi_scripts_fingerprint,
			),
		)
		godot.gd_push_error(godot.variant_from_string(&msg))
		return
	}
	msg := godot.new_string_cstring(
		"odin_godot: no compiled Odin scripts found (res://bin/libodinscripts.*). This is normal " +
		"for a fresh install — your .odin gameplay code compiles into that dll. Quick start: " +
		"Project > Tools > Set Up Odin Scripts (creates res://scripts from the template), then " +
		"Project > Tools > Build Odin Scripts. See addons/odin_godot/README.md.",
	)
	godot.gd_push_warning(godot.variant_from_string(&msg))
}

@(private)
g_version_checked: bool

// One-shot engine-version sanity check. The required-virtual table (core/language.odin) is
// pinned to the tested Godot (4.6); a different minor may have changed the ScriptLanguage
// virtual contract, which can range from "features misbehave" to a hard crash. We WARN rather
// than block (a hard `compatibility_maximum` in the manifest is fragile — it would also reject
// valid 4.6.x patch releases). Editor-only, surfaced from the frame pump.
@(private)
check_engine_version_once :: proc() {
	if g_version_checked {
		return
	}
	g_version_checked = true
	eng := godot.singleton_engine()
	if !bool(godot.engine_is_editor_hint(eng)) {
		return
	}
	info := godot.engine_get_version_info(eng)
	major := version_field(&info, "major")
	minor := version_field(&info, "minor")
	if major == 4 && minor == 7 {
		return // the tested range
	}
	msg := godot.new_string_odin(
		fmt.tprintf(
			"odin_godot is built and tested for Godot 4.7.x — you are on %d.%d. It may not work " +
			"correctly; if the script-language ABI changed, expect editor issues or crashes.",
			major,
			minor,
		),
	)
	godot.gd_push_warning(godot.variant_from_string(&msg))
}

@(private = "file")
version_field :: proc(d: ^godot.Dictionary, key: cstring) -> int {
	k := godot.new_string_cstring(key)
	kv := godot.variant_from_string(&k)
	v := godot.dictionary_get(d, kv, godot.Variant{})
	return int(godot.variant_to_int(&v))
}

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
	} else when ODIN_OS == .Windows {
		// GetModuleHandleExW needs the core:sys/windows import, which can't live behind a
		// `when` — the implementation is in scripts_native_windows.odin (#+build windows).
		return core_dll_dir_windows(cast(rawptr)odin_scripts_load, allocator)
	}
	return "", false
}

// Shared-library extension of the scripts dll on THIS platform (also the suffix of the
// hot-reload unique copies, `<base>.rN<ext>`).
when ODIN_OS == .Windows {
	SCRIPTS_DLL_EXT :: ".dll"
} else when ODIN_OS == .Linux {
	SCRIPTS_DLL_EXT :: ".so"
} else {
	SCRIPTS_DLL_EXT :: ".dylib"
}

// Resolve the scripts dll path. Order: explicit env override (test harness) ->
// sibling of the core dll (works in BOTH dev and exported builds) -> globalized
// `res://bin/libodinscripts.<ext>` (dev fallback).
@(private)
scripts_dll_path :: proc() -> string {
	if override, ok := os.lookup_env("ODIN_SCRIPTS_DLL", context.allocator); ok && override != "" {
		return override
	}
	ext := SCRIPTS_DLL_EXT

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

// Load ONE scripts dll at `path` and run the FULL handshake: symbol resolution, ABI
// semantic version, layout fingerprint, compiler provenance, boot, and typed-cross-script
// core-api handoff. `main` selects
// the main-module failure surfacing (the fresh-install warning flags + shipped-game
// errors — exactly the pre-spike behavior); an extra module's failure is surfaced via
// scripts_note_error (frame-pump push_error) instead, and never flips the main flags.
@(private = "file")
load_scripts_dll :: proc(path: string, main: bool) -> (dll: Scripts_Dll, ok: bool) {
	_, lok := dynlib.initialize_symbols(&dll, path, "", "__handle")
	if !lok || !scripts_dll_has_required_symbols(&dll) {
		// Include the loader's own reason (dlerror / GetLastError text) — "failed to
		// load" alone has sent people chasing phantom linkage theories before.
		gdext_print("odin: failed to load scripts dll", path)
		gdext_print("odin: loader error:", dynlib.last_error())
		if main {
			// Flag for the editor frame pump to surface ONE actionable warning in the editor
			// console (this load runs at extension init, before the engine logger/editor UI are
			// guaranteed up, so a push_warning here can be lost — defer it). The common cause is
			// not an error at all: a fresh install hasn't compiled its scripts dll yet.
			g_scripts_missing = true
			// In a SHIPPED GAME (not the editor) this is a hard error, not a fresh-install state —
			// surface it now so the game doesn't silently run with no Odin scripts.
			surface_load_failure_runtime("scripts library not found")
		} else {
			scripts_note_error(fmt.tprintf("odin_godot: failed to load script module dll %s", path))
		}
		scripts_dll_discard(&dll)
		return {}, false
	}

	// ABI handshake FIRST, before boot: refuse a scripts dll with a different semantic
	// generation OR complete layout fingerprint (reading the wrong Class_Desc offsets ->
	// heap corruption / garbage proc ptrs). The version procs are PURE DATA (they return
	// constants), so they are safe to call pre-boot — and booting a mismatched dll (letting
	// it initialize its gdext/godot globals against this core) is exactly what must not
	// happen. nil symbol = built before this handshake existed = also a mismatch. The fix is
	// always "rebuild your scripts dll".
	contract := scripts_dll_contract(&dll)
	core_fingerprint := rt.abi_layout_fingerprint()
	if contract.abi != rt.ABI_VERSION || contract.fingerprint != core_fingerprint {
		gdext_print(
			"odin: scripts dll ABI mismatch (rebuild your scripts: build/build_scripts.sh) — core wants",
			fmt.tprintf(
				"v%d/fp=%016x, scripts dll is v%d/fp=%016x (%s)",
				rt.ABI_VERSION,
				core_fingerprint,
				contract.abi,
				contract.fingerprint,
				path,
			),
		)
		if main {
			g_scripts_abi_skew = true
			g_abi_core = rt.ABI_VERSION
			g_abi_scripts = contract.abi
			g_abi_core_fingerprint = core_fingerprint
			g_abi_scripts_fingerprint = contract.fingerprint
		} else {
			scripts_note_error(
				fmt.tprintf(
					"odin_godot: script module dll %s has ABI v%d, core wants v%d — rebuild it (build/build_scripts.sh)",
					path,
					contract.abi,
					rt.ABI_VERSION,
				),
			)
		}
		surface_load_failure_runtime(
			fmt.tprintf(
				"ABI mismatch: core v%d/fp=%016x, scripts v%d/fp=%016x",
				rt.ABI_VERSION,
				core_fingerprint,
				contract.abi,
				contract.fingerprint,
			),
		)
		scripts_dll_discard(&dll)
		return {}, false
	}

	// Compiler identity is provenance, not a blanket lock. Every cross-DLL callback uses the C
	// convention and the complete metadata layout matched above; allocators never cross. Keep
	// this line grep-able so a compatibility report still names both toolchains.
	if contract.odin != ODIN_VERSION {
		gdext_print(
			"ODIN_COMPILER_SKEW_ABI_COMPATIBLE",
			fmt.tprintf(
				"scripts Odin %s differs from core Odin %s; ABI v%d/fp=%016x matches, loading safely",
				contract.odin,
				ODIN_VERSION,
				rt.ABI_VERSION,
				core_fingerprint,
			),
		)
	}

	// Handshakes passed: boot so the scripts dll's gdext/godot globals are live, THEN the
	// caller may read the manifest.
	dll.odin_scripts_boot(saved_get_proc_address, gdext.library)

	// Hand the scripts dll the typed cross-script resolver (Option A). Optional: an older
	// scripts dll without the runtime symbol simply leaves rt.script_of returning nil.
	// Per-dll: every module has its own runtime globals, so every module gets the handoff.
	if dll.odin_scripts_set_core_api != nil {
		dll.odin_scripts_set_core_api(odin_script_struct)
	}
	if dll.odin_scripts_set_core_api2 != nil {
		dll.odin_scripts_set_core_api2(odin_script_struct_any)
	}
	// Hand over the panic reporter so ODIN_SCRIPT_PANIC lines also reach the editor
	// Output via push_error (stderr is written by the runtime side regardless).
	if dll.odin_scripts_set_panic_report != nil {
		dll.odin_scripts_set_panic_report(script_panic_report)
	}
	return dll, true
}

// The push_error half of the scripts dll's assertion proc (runtime/panic_native.odin):
// routes the already-formatted ODIN_SCRIPT_PANIC line through Godot's error channel,
// which the editor shows red in the Output/Debugger docks — including for a game child
// process (push_error travels over the debugger TCP link, unlike stderr). `proc "c"`:
// called from the scripts dll mid-panic; gd.error is contextless and allocation-light.
@(private)
script_panic_report :: proc "c" (msg: cstring) {
	// Crash-report FILE first (core/crash.odin; no-op stub on Windows): for an
	// editor-launched child neither stderr nor this push_error survives the dying
	// debugger connection — the file is what the editor-side watcher surfaces. Also
	// ordered before godot.error in case the engine call faults in the dying process.
	crash_file_note_panic(msg)
	godot.error(msg)
}

// Merge a booted module's manifest into the path-identity and optional-global-alias maps.
// Source paths are primary and unique. An explicit alias collision with another module
// rejects the later module as an authoring error, naming both source files.
@(private = "file")
index_module_manifest :: proc(mod: ^Scripts_Module, descs: [^]rt.Class_Desc, n: int) -> bool {
	context.allocator = core_allocator()
	for i in 0 ..< n {
		d := descs[i]
		identity_ptr := rt.desc_identity(d)
		if identity_ptr == nil {continue}
		identity := string(identity_ptr)
		if prev, dup := scripts_classes[identity]; dup {
			msg := fmt.aprintf(
				"odin_godot: script source path '%s' is present in both '%s' and '%s'; module '%s' was NOT loaded.",
				identity,
				prev.path != nil ? string(prev.path) : string(prev.name),
				d.path != nil ? string(d.path) : string(d.name),
				module_display(mod.name),
			)
			gdext_print("odin: script module path collision", msg)
			scripts_note_error(msg)
			delete(msg)
			return false
		}
		if d.global_name == nil || string(d.global_name) == "" {continue}
		alias := string(d.global_name)
		if other := module_owning_class(alias); other >= 0 {
			prev := scripts_global_classes[alias]
			msg := fmt.aprintf(
				"odin_godot: duplicate explicit //gd:class '%s' in '%s' and '%s' (script modules '%s' and '%s'); module '%s' was NOT loaded.",
				alias,
				prev.path != nil ? string(prev.path) : string(prev.name),
				d.path != nil ? string(d.path) : string(d.name),
				module_display(g_modules[other].name),
				module_display(mod.name),
				module_display(mod.name),
			)
			gdext_print("odin: script module global-class collision", msg)
			scripts_note_error(msg)
			delete(msg)
			return false
		}
	}
	for i in 0 ..< n {
		d := descs[i]
		identity_ptr := rt.desc_identity(d)
		if identity_ptr == nil {continue}
		identity := strings.clone(string(identity_ptr))
		scripts_classes[identity] = d
		append(&mod.classes, identity)
		if d.global_name != nil && string(d.global_name) != "" {
			alias := strings.clone(string(d.global_name))
			scripts_global_classes[alias] = d
			append(&mod.global_classes, alias)
		}
	}
	return true
}

// Discover + load the OPTIONAL extra script-module dlls sitting beside the main dll:
// `libodinscripts_<name>.<ext>` where <name> contains no dot (which excludes the
// `.rN.<ext>` unique reload copies). Loaded in sorted-name order, each with the full
// handshake. A module that fails its handshake or collides is skipped LOUDLY; the rest
// still load.
@(private = "file")
load_extra_modules :: proc(main_dll_path: string) {
	context.allocator = core_allocator()

	slash := strings.last_index_byte(main_dll_path, '/')
	when ODIN_OS == .Windows {
		if bidx := strings.last_index_byte(main_dll_path, '\\'); bidx > slash {
			slash = bidx
		}
	}
	if slash < 0 {return}
	dir_path := main_dll_path[:slash]

	fd, oerr := os.open(dir_path)
	if oerr != nil {return}
	defer os.close(fd)
	files, rerr := os.read_dir(fd, -1, context.temp_allocator)
	if rerr != nil {return}

	Found :: struct {
		name: string,
		path: string,
	}
	found := make([dynamic]Found, context.temp_allocator)
	prefix :: "libodinscripts_"
	for fi in files {
		if !strings.has_prefix(fi.name, prefix) || !strings.has_suffix(fi.name, SCRIPTS_DLL_EXT) {
			continue
		}
		name := fi.name[len(prefix):len(fi.name) - len(SCRIPTS_DLL_EXT)]
		if name == "" || strings.contains_rune(name, '.') {
			continue // reload copies (<base>.rN.<ext>) and other artifacts
		}
		append(
			&found,
			Found{
				name = strings.clone(name, context.temp_allocator),
				path = strings.clone(fi.fullpath, context.temp_allocator),
			},
		)
	}
	// Deterministic load order (the spec'd "modules/* sorted").
	slice.sort_by(found[:], proc(a, b: Found) -> bool {return a.name < b.name})

	for f in found {
		cleanup_stale_reload_copies(f.path)
		dll, ok := load_scripts_dll(f.path, false)
		if !ok {
			continue
		}
		append(
			&g_modules,
			Scripts_Module{
				name = strings.clone(f.name),
				path = strings.clone(f.path),
			},
		)
		mod := &g_modules[len(g_modules) - 1]
		n: i32
		descs := dll.odin_scripts_manifest(&n)
		note_dll_registration_errors(dll.odin_scripts_registration_errors)
		if index_module_manifest(mod, descs, int(n)) {
			gen := script_generation_create(dll, f.name, scripts_dll_file_size(f.path))
			script_generation_register_manifest(gen, descs, int(n))
			mod.generation = gen
		} else {
			// The pre-pass publishes nothing on failure, so this rejected module has no
			// generation owners and can be unloaded immediately.
			delete(mod.name)
			delete(mod.path)
			unordered_remove(&g_modules, len(g_modules) - 1)
			scripts_dll_discard(&dll)
		}
	}
}

@(private)
odin_scripts_load :: proc() {
	// Core-owned bookkeeping (the class map + cloned names) must use the alignment-
	// correct allocator: Godot's `mem_alloc` ignores alignment, but Odin maps assert
	// cache-line alignment. The godot context allocator is fine for transient Godot
	// values, so we only override `allocator`, not `temp_allocator`.
	context.allocator = core_allocator()
	scripts_classes = make(map[string]rt.Class_Desc)
	scripts_global_classes = make(map[string]rt.Class_Desc)

	path := scripts_dll_path()
	defer delete(path)

	// Sweep `<base>.rN.<ext>` unique-copy artifacts left by PREVIOUS sessions' hot reloads:
	// the reload counter restarts with the process, and the old copies are no longer mapped
	// by anyone — without this they accumulate in bin/ forever.
	cleanup_stale_reload_copies(path)

	if dll, ok := load_scripts_dll(path, true); ok {
		append(
			&g_modules,
			Scripts_Module{
				name = "",
				path = strings.clone(path),
			},
		)
		mod := &g_modules[len(g_modules) - 1]
		n: i32
		descs := dll.odin_scripts_manifest(&n)
		_ = index_module_manifest(mod, descs, int(n)) // main loads first — cannot collide
		gen := script_generation_create(dll, "", scripts_dll_file_size(path))
		script_generation_register_manifest(gen, descs, int(n))
		mod.generation = gen
		note_dll_registration_errors(dll.odin_scripts_registration_errors)
	}

	// Optional extra modules (multi-module spike) — scanned independently of the main
	// module, so one broken dll never takes the others down.
	load_extra_modules(path)
}

// Pull the dll's registration-error table (recorded during its `@(init)` reflection
// walk), note it for the frame pump's push_error pass, and mirror each line to stderr
// NOW — this runs at extension init / mid-reload, where the engine logger may not be
// up, and a dropped export must be visible in headless logs regardless.
@(private = "file")
note_dll_registration_errors :: proc(errors_proc: proc "c" (out_count: ^i32) -> [^]rt.Registration_Error) {
	if errors_proc == nil {
		return
	}
	en: i32
	errs := errors_proc(&en)
	if en <= 0 {
		return
	}
	scripts_note_registration_errors(errs, int(en))
	for i in 0 ..< int(en) {
		e := errs[i]
		gdext_print(
			"odin: script registration error",
			fmt.tprintf(
				"%s.%s: %s",
				e.class != nil ? string(e.class) : "?",
				e.field != nil ? string(e.field) : "-",
				e.msg != nil ? string(e.msg) : "?",
			),
		)
	}
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
//   3. Rebuild the identity map; invalidate the per-script caches.
//   4. Re-bind every live instance to the new descriptors (same-layout keeps state in
//      place; changed-layout migrates exports — see rebind_all_instances).
//   5. Retire the old image. Instance leases keep removed or callback-bearing state safe;
//      once its last lease is released, the image unloads at the closed execution gate.
// ----------------------------------------------------------------------------

@(private)
reload_counter: int

// Best-effort sweep of `<base>.rN<ext>` unique-copy artifacts (see odin_scripts_reload)
// left by PREVIOUS sessions: the counter restarts with the process and nothing maps the
// old copies anymore. Runs once at initial load, BEFORE the first reload of this session.
@(private = "file")
cleanup_stale_reload_copies :: proc(base: string) {
	slash := strings.last_index_byte(base, '/')
	when ODIN_OS == .Windows {
		if bidx := strings.last_index_byte(base, '\\'); bidx > slash {
			slash = bidx
		}
	}
	if slash < 0 {return}
	dir_path := base[:slash]
	prefix := fmt.tprintf("%s.r", base[slash + 1:])

	fd, oerr := os.open(dir_path)
	if oerr != nil {return}
	defer os.close(fd)
	files, rerr := os.read_dir(fd, -1, context.temp_allocator)
	if rerr != nil {return}
	for fi in files {
		if strings.has_prefix(fi.name, prefix) {
			os.remove(fi.fullpath)
		}
	}
}

// Per-module hot swap. `module` == "" swaps the MAIN module (the pre-spike behavior);
// any other name swaps ONLY that module's dll. The key correctness property: instances
// of OTHER modules' classes are never touched — their descs, caches, and struct bytes
// stay exactly as they were.
@(private)
odin_scripts_reload :: proc(module := "") -> bool {
	context.allocator = core_allocator()
	// A reload nested inside an Odin ScriptInstance callback would eventually return
	// into old code with a possibly-migrated self. It cannot be made safe by waiting
	// (this thread owns the reader lease), so require the caller to defer it.
	if !script_reload_can_begin() {
		gdext_print(
			"odin reload: rejected inside an active Odin script call",
			"defer Script.reload until the current method/lifecycle callback returns",
		)
		return false
	}

	mi := module_index(module)
	if mi < 0 {
		gdext_print("odin reload: unknown script module", module_display(module))
		return false
	}
	base := g_modules[mi].path

	// 1. Snapshot the freshly-built dll to a unique path (force a fresh image).
	data, read_err := os.read_entire_file(base, context.allocator)
	if read_err != nil {
		gdext_print("odin reload: cannot read scripts dll", base)
		return false
	}
	defer delete(data)

	reload_counter += 1
	unique := fmt.aprintf("%s.r%d%s", base, reload_counter, SCRIPTS_DLL_EXT)
	defer delete(unique)
	if write_err := os.write_entire_file(unique, data); write_err != nil {
		gdext_print("odin reload: cannot write unique dll", unique)
		return false
	}

	// 2. Load and validate the NEW dll before executing any of its boot code.
	new_dll: Scripts_Dll
	_, lok := dynlib.initialize_symbols(&new_dll, unique, "", "__handle")
	if !lok || !scripts_dll_has_required_symbols(&new_dll) {
		gdext_print("odin reload: failed to load new scripts dll", unique)
		scripts_dll_discard(&new_dll)
		os.remove(unique)
		return false
	}
	contract := scripts_dll_contract(&new_dll)
	core_fingerprint := rt.abi_layout_fingerprint()
	if contract.abi != rt.ABI_VERSION || contract.fingerprint != core_fingerprint {
		gdext_print(
			"odin reload: new scripts dll ABI mismatch — keeping old code",
			fmt.tprintf(
				"(core v%d/fp=%016x, new dll v%d/fp=%016x)",
				rt.ABI_VERSION,
				core_fingerprint,
				contract.abi,
				contract.fingerprint,
			),
		)
		// Say it WHERE THE USER LOOKS, with the RIGHT fix. This runs on the main
		// thread with the engine fully up (deferred swap / Script.reload), so
		// push_error is safe — unlike the boot-path handshake, which is stderr-only.
		// At swap time the scripts dll was JUST rebuilt from the addon's current
		// sources, so a mismatch here almost always means the addon was updated
		// while this editor kept the core dll it mapped at startup (a GDExtension
		// cannot hot-swap itself) — "rebuild scripts" advice would be a treadmill.
		// stderr alone let an editor session silently run days-old scripts while
		// fresh Play runs loaded the new dlls and worked, which reads as anything
		// but the real cause.
		msg := godot.new_string_odin(
			fmt.tprintf(
				"odin_godot: reload REJECTED — your freshly-built scripts (ABI v%d/fp=%016x) don't match " +
					"the odin_godot core this session loaded at startup (v%d/fp=%016x). The addon was " +
					"updated while the editor was running: RESTART THE EDITOR to load the new " +
					"core. Until then the previously-loaded scripts stay active in the editor " +
					"(Play runs are unaffected — they load fresh).",
				contract.abi,
				contract.fingerprint,
				rt.ABI_VERSION,
				core_fingerprint,
			),
		)
		godot.gd_push_error(godot.variant_from_string(&msg))
		scripts_dll_discard(&new_dll)
		os.remove(unique)
		return false
	}
	if contract.odin != ODIN_VERSION {
		gdext_print(
			"ODIN_COMPILER_SKEW_ABI_COMPATIBLE",
			fmt.tprintf(
				"reload scripts Odin %s differs from core Odin %s; ABI v%d/fp=%016x matches, accepting",
				contract.odin,
				ODIN_VERSION,
				rt.ABI_VERSION,
				core_fingerprint,
			),
		)
	}

	// The candidate is valid and no user code has run from it yet. Close the execution
	// gate before booting/publishing it: this drains every old trampoline and keeps
	// instance creation, property access, and descriptor reads out of the mutation.
	script_reload_begin()
	defer script_reload_end()

	// Compatibility passed: boot, hand off core APIs, then read the manifest.
	new_dll.odin_scripts_boot(saved_get_proc_address, gdext.library)
	// Re-hand the resolver to the freshly-swapped dll (it has its own runtime globals).
	if new_dll.odin_scripts_set_core_api != nil {
		new_dll.odin_scripts_set_core_api(odin_script_struct)
	}
	if new_dll.odin_scripts_set_core_api2 != nil {
		new_dll.odin_scripts_set_core_api2(odin_script_struct_any)
	}
	// ... and the panic reporter (same per-dll globals reasoning).
	if new_dll.odin_scripts_set_panic_report != nil {
		new_dll.odin_scripts_set_panic_report(script_panic_report)
	}
	n: i32
	descs := new_dll.odin_scripts_manifest(&n)
	// Surface the NEW dll's registration errors too (the frame pump pushes them next
	// frame — the engine is fully up during a reload).
	note_dll_registration_errors(new_dll.odin_scripts_registration_errors)

	// 3. Collision pre-pass against the OTHER modules. Paths are primary identities;
	//    explicit global aliases are optional but must still be project-unique.
	for i in 0 ..< int(n) {
		d := descs[i]
		identity_ptr := rt.desc_identity(d)
		if identity_ptr != nil {
			identity := string(identity_ptr)
			if other := module_owning_identity(identity); other >= 0 && other != mi {
				msg := fmt.aprintf(
					"odin_godot: reload rejected — source path '%s' is already provided by script module '%s' (old code kept).",
					identity,
					module_display(g_modules[other].name),
				)
				gdext_print("odin reload: module path collision", msg)
				scripts_note_error(msg)
				delete(msg)
				scripts_dll_discard(&new_dll)
				os.remove(unique)
				return false
			}
		}
		if d.global_name == nil || string(d.global_name) == "" {continue}
		alias := string(d.global_name)
		if other := module_owning_class(alias); other >= 0 && other != mi {
			prev := scripts_global_classes[alias]
			msg := fmt.aprintf(
				"odin_godot: reload rejected — explicit //gd:class '%s' in '%s' collides with '%s' from script module '%s' (old code kept).",
				alias,
				d.path != nil ? string(d.path) : string(d.name),
				prev.path != nil ? string(prev.path) : string(prev.name),
				module_display(g_modules[other].name),
			)
			gdext_print("odin reload: module global-class collision", msg)
			scripts_note_error(msg)
			delete(msg)
			scripts_dll_discard(&new_dll)
			os.remove(unique)
			return false
		}
	}

	// 4. Re-index THIS module's script set (other modules' entries untouched). The
	//    `affected` set (old ∪ new identities) scopes cache invalidation + rebind below.
	mod := &g_modules[mi]
	new_generation := script_generation_create(new_dll, module, len(data), unique)
	script_generation_register_manifest(new_generation, descs, int(n))
	affected := make(map[string]bool, context.temp_allocator)
	for old in mod.classes {
		affected[strings.clone(old, context.temp_allocator)] = true
		delete_key(&scripts_classes, old)
		// Retire the old core-owned cache. Instance and returned-metadata leases keep it
		// alive exactly as long as needed. Only live instances can execute its copied
		// callback slots; a metadata-only cache is inert and does not pin the DLL image.
		retire_class_cache(old)
		delete(old) // the ONE shared clone backing both mod.classes and the map key
	}
	clear(&mod.classes)
	for alias in mod.global_classes {
		delete_key(&scripts_global_classes, alias)
		delete(alias)
	}
	clear(&mod.global_classes)
	for i in 0 ..< int(n) {
		d := descs[i]
		identity_ptr := rt.desc_identity(d)
		if identity_ptr == nil {continue}
		identity := strings.clone(string(identity_ptr))
		scripts_classes[identity] = d
		append(&mod.classes, identity)
		if !(identity in affected) {
			affected[strings.clone(identity, context.temp_allocator)] = true
		}
		if d.global_name != nil && string(d.global_name) != "" {
			alias := strings.clone(string(d.global_name))
			scripts_global_classes[alias] = d
			append(&mod.global_classes, alias)
		}
	}

	// 5. Re-bind live instances of THIS module's classes BEFORE returning (no stale proc
	//    may run after). Instances of other modules are skipped — untouched by design.
	rebind_all_instances(affected)

	old_generation := mod.generation
	mod.generation = new_generation
	script_generation_retire(old_generation)
	script_generations_collect_at_gate()
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
