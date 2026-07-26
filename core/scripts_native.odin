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
	odin_scripts_manifest: proc "c" (out_count: ^i32) -> [^]rt.Class_Desc,
	// Typed cross-script handoff (Option A): the core calls this right after boot to hand
	// the scripts dll its `obj -> Odin script struct` resolver (core's odin_script_struct),
	// which `rt.script_of` then uses. Exported by the runtime package (linked into the dll).
	odin_scripts_set_core_api: proc "c" (script_struct: rt.Script_Struct_Proc),
	// Panic-surfacing handoff (same pattern): the core hands the scripts dll a push_error
	// reporter right after boot, so a script panic/assert shows RED in the editor Output
	// (the runtime's assertion proc is stderr-only until this is installed). Exported by
	// runtime/panic_native.odin (linked into the dll); optional — nil on an older dll.
	odin_scripts_set_panic_report: proc "c" (report: rt.Panic_Report_Proc),
	// ABI version of the shared core<->scripts data contract (see rt.ABI_VERSION). Checked
	// before reading the manifest to reject a scripts dll built against a different addon
	// version. Absent (nil) on a dll built before this handshake existed — also a mismatch.
	odin_scripts_abi_version: proc "c" () -> u32,
	// ODIN_VERSION of the compiler that built the scripts dll (see rt.odin_scripts_odin_version).
	// Same struct sizes across Odin releases do not guarantee the same layout/calling
	// conventions, so a compiler mismatch is rejected like an ABI mismatch. Absent (nil) on an
	// older dll — also treated as a mismatch, never a crash.
	odin_scripts_odin_version: proc "c" () -> cstring,
	// Problems the dll's runtime reflection walk recorded while building its member tables
	// at `@(init)` (see runtime/register_class.odin). Pulled after the manifest and surfaced
	// via push_error from the frame pump — a bad export is dropped LOUDLY, never silently.
	odin_scripts_registration_errors: proc "c" (out_count: ^i32) -> [^]rt.Registration_Error,
}

// ----------------------------------------------------------------------------
// Multi-module spike: scripts can be split into SEVERAL dlls — the MAIN module
// (res://scripts -> libodinscripts.<ext>, always present, exactly the pre-spike single
// dll) plus optional extra modules (res://modules/<name> -> libodinscripts_<name>.<ext>).
// Each module is its own Odin package with its OWN dll, its own boot handshake, and its
// own runtime registry; the core merges every module's manifest into the ONE shared
// `scripts_classes` map (class names must be unique across modules — a collision is a
// load error naming both modules). A single-module project is simply a g_modules table
// of length one, so the pre-spike path is unchanged.
// ----------------------------------------------------------------------------

@(private)
Scripts_Module :: struct {
	name:    string, // "" == the MAIN module. Heap-owned clone otherwise.
	path:    string, // heap-owned dll base path (the published, non-unique-copy path)
	dll:     Scripts_Dll,
	// Class names this module currently provides. Each entry is ONE heap clone shared
	// with the `scripts_classes` map key (so a per-module reload can delete the key and
	// free the clone exactly once).
	classes: [dynamic]string,
}

@(private)
g_modules: [dynamic]Scripts_Module

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

// Index of the module currently providing `class`, or -1. Linear over a tiny table.
@(private = "file")
module_owning_class :: proc(class: string) -> int {
	for m, i in g_modules {
		for c in m.classes {
			if c == class {
				return i
			}
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

// Set when the scripts dll loaded but its ABI version didn't match the core's (a version skew).
@(private)
g_scripts_abi_skew: bool
@(private)
g_abi_core: u32
@(private)
g_abi_scripts: u32

// Set when the scripts dll was built by a different Odin compiler than the core (compiler skew:
// same struct sizes do not guarantee the same layout/ABI across compiler releases).
@(private)
g_scripts_odin_skew: bool
@(private)
g_odin_scripts: string // compiler version reported by the rejected dll (heap-owned clone)

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
	if !g_scripts_missing && !g_scripts_abi_skew && !g_scripts_odin_skew {
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
	if g_scripts_odin_skew {
		// Loaded, but compiled by a different Odin than the core. Rebuilding is only half
		// the fix: the core is usually PREBUILT, so the user must build with the exact
		// Odin release it pins — name it.
		msg := godot.new_string_odin(
			fmt.tprintf(
				"odin_godot: your scripts dll was built with Odin %s, but this core requires " +
				"Odin %s — install that exact release (odin-lang.org), then rebuild scripts " +
				"(Project > Tools > Build Odin Scripts). Your scripts won't load until the " +
				"versions match.",
				g_odin_scripts,
				ODIN_VERSION,
			),
		)
		godot.gd_push_error(godot.variant_from_string(&msg))
		return
	}
	if g_scripts_abi_skew {
		// Loaded, but built against a different odin_godot version — a clear "rebuild" message,
		// not the fresh-install one.
		msg := godot.new_string_odin(
			fmt.tprintf(
				"odin_godot: your scripts dll was built against a different addon version " +
				"(core ABI v%d, scripts v%d). Rebuild it: addons/odin_godot/build/build_scripts.sh " +
				"(your scripts won't load until you do).",
				g_abi_core,
				g_abi_scripts,
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
// version, compiler version, boot, typed-cross-script core-api handoff. `main` selects
// the main-module failure surfacing (the fresh-install warning flags + shipped-game
// errors — exactly the pre-spike behavior); an extra module's failure is surfaced via
// scripts_note_error (frame-pump push_error) instead, and never flips the main flags.
@(private = "file")
load_scripts_dll :: proc(path: string, main: bool) -> (dll: Scripts_Dll, ok: bool) {
	_, lok := dynlib.initialize_symbols(&dll, path, "", "__handle")
	if !lok || dll.__handle == nil || dll.odin_scripts_boot == nil || dll.odin_scripts_manifest == nil {
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
		return {}, false
	}

	// ABI handshake FIRST, before boot: refuse a scripts dll built against a different
	// odin_godot version (its Class_Desc layout would differ -> reading at wrong offsets ->
	// heap corruption / garbage proc ptrs). The version procs are PURE DATA (they return
	// constants), so they are safe to call pre-boot — and booting a mismatched dll (letting
	// it initialize its gdext/godot globals against this core) is exactly what must not
	// happen. nil symbol = built before this handshake existed = also a mismatch. The fix is
	// always "rebuild your scripts dll".
	scripts_abi := u32(0)
	if dll.odin_scripts_abi_version != nil {
		scripts_abi = dll.odin_scripts_abi_version()
	}
	if scripts_abi != rt.ABI_VERSION {
		gdext_print(
			"odin: scripts dll ABI mismatch (rebuild your scripts: build/build_scripts.sh) — core wants",
			fmt.tprintf("v%d, scripts dll is v%d (%s)", rt.ABI_VERSION, scripts_abi, path),
		)
		if main {
			g_scripts_abi_skew = true
			g_abi_core = rt.ABI_VERSION
			g_abi_scripts = scripts_abi
		} else {
			scripts_note_error(
				fmt.tprintf(
					"odin_godot: script module dll %s has ABI v%d, core wants v%d — rebuild it (build/build_scripts.sh)",
					path,
					scripts_abi,
					rt.ABI_VERSION,
				),
			)
		}
		surface_load_failure_runtime(fmt.tprintf("ABI mismatch: core v%d, scripts v%d", rt.ABI_VERSION, scripts_abi))
		return {}, false
	}

	// Compiler-skew handshake (also pre-boot, also pure data): matching struct SIZES across
	// different Odin compiler releases do not guarantee the same layout/calling conventions.
	// A missing symbol (a dll built before this handshake) is a mismatch too — never a crash.
	scripts_odin := "unknown (older scripts dll)"
	if dll.odin_scripts_odin_version != nil {
		if cs := dll.odin_scripts_odin_version(); cs != nil {
			scripts_odin = string(cs)
		}
	}
	if scripts_odin != ODIN_VERSION {
		// The fix depends on which side is "wrong", and for an ADDON consumer it is
		// almost always their compiler: the core ships PREBUILT, so "rebuild scripts"
		// with their (different) Odin can never converge on a match. Name the exact
		// release the core requires — installing it is the actionable step.
		gdext_print(
			"odin: scripts dll compiler mismatch",
			fmt.tprintf(
				"scripts dll built with Odin %s, but this odin_godot core requires Odin %s — " +
				"install that exact release (odin-lang.org), then rebuild scripts " +
				"(Project > Tools > Build Odin Scripts). A prebuilt core pins the Odin " +
				"version; building the core from source with your Odin also works.",
				scripts_odin,
				ODIN_VERSION,
			),
		)
		if main {
			g_scripts_odin_skew = true
			g_odin_scripts = strings.clone(scripts_odin)
		} else {
			scripts_note_error(
				fmt.tprintf(
					"odin_godot: script module dll %s was built with Odin %s, but the core requires %s — install that Odin release and rebuild",
					path,
					scripts_odin,
					ODIN_VERSION,
				),
			)
		}
		surface_load_failure_runtime(
			fmt.tprintf(
				"scripts dll built with Odin %s, but this core requires Odin %s — install that release, then rebuild scripts",
				scripts_odin,
				ODIN_VERSION,
			),
		)
		return {}, false
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

// Merge a booted module's manifest into the shared class map. A class-name collision with
// ANOTHER module is a LOAD ERROR naming both modules, and rejects this module's WHOLE
// class set (no partial indexing): duplicated names would make scripts_classes lookups —
// and name-based cross-module access — silently ambiguous.
@(private = "file")
index_module_manifest :: proc(mod: ^Scripts_Module, descs: [^]rt.Class_Desc, n: int) -> bool {
	context.allocator = core_allocator()
	for i in 0 ..< n {
		name := string(descs[i].name)
		if other := module_owning_class(name); other >= 0 {
			msg := fmt.aprintf(
				"odin_godot: script class '%s' is defined in BOTH script module '%s' and script module '%s' — " +
				"class names must be unique across modules; module '%s' was NOT loaded.",
				name,
				module_display(g_modules[other].name),
				module_display(mod.name),
				module_display(mod.name),
			)
			gdext_print("odin: script module class collision", msg)
			scripts_note_error(msg)
			delete(msg)
			return false
		}
	}
	for i in 0 ..< n {
		d := descs[i]
		name := strings.clone(string(d.name))
		scripts_classes[name] = d
		append(&mod.classes, name)
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
			Scripts_Module{name = strings.clone(f.name), path = strings.clone(f.path), dll = dll},
		)
		mod := &g_modules[len(g_modules) - 1]
		n: i32
		descs := dll.odin_scripts_manifest(&n)
		_ = index_module_manifest(mod, descs, int(n)) // collision already surfaced; dll stays mapped, classless
		note_dll_registration_errors(dll.odin_scripts_registration_errors)
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

	path := scripts_dll_path()
	defer delete(path)

	// Sweep `<base>.rN.<ext>` unique-copy artifacts left by PREVIOUS sessions' hot reloads:
	// the reload counter restarts with the process, and the old copies are no longer mapped
	// by anyone — without this they accumulate in bin/ forever.
	cleanup_stale_reload_copies(path)

	if dll, ok := load_scripts_dll(path, true); ok {
		append(&g_modules, Scripts_Module{name = "", path = strings.clone(path), dll = dll})
		mod := &g_modules[len(g_modules) - 1]
		n: i32
		descs := dll.odin_scripts_manifest(&n)
		_ = index_module_manifest(mod, descs, int(n)) // main loads first — cannot collide
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
//   3. Rebuild the class map; invalidate the per-class caches.
//   4. Re-bind every live instance to the new descriptors (same-layout keeps state in
//      place; changed-layout migrates exports — see rebind_all_instances).
// The OLD handle is deliberately kept mapped (not dlclose'd): lingering cstrings/proc
// ptrs stay valid, and after the re-bind no live instance dispatches into it.
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
	// ABI handshake on the swapped-in dll too (same reasoning as the initial load): never read
	// a manifest whose Class_Desc layout might differ from this core's.
	new_abi := u32(0)
	if new_dll.odin_scripts_abi_version != nil {
		new_abi = new_dll.odin_scripts_abi_version()
	}
	if new_abi != rt.ABI_VERSION {
		gdext_print(
			"odin reload: new scripts dll ABI mismatch — keeping old code",
			fmt.tprintf("(core v%d, new dll v%d)", rt.ABI_VERSION, new_abi),
		)
		return false
	}
	// Re-hand the resolver to the freshly-swapped dll (it has its own runtime globals).
	if new_dll.odin_scripts_set_core_api != nil {
		new_dll.odin_scripts_set_core_api(odin_script_struct)
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

	// 3. Collision pre-pass against the OTHER modules: a class name the new manifest
	//    shares with a different module would fork name-based lookups — refuse the whole
	//    swap and keep the old code (nothing was mutated yet).
	for i in 0 ..< int(n) {
		name := string(descs[i].name)
		if other := module_owning_class(name); other >= 0 && other != mi {
			msg := fmt.aprintf(
				"odin_godot: reload rejected — class '%s' in script module '%s' collides with script module '%s' (old code kept).",
				name,
				module_display(module),
				module_display(g_modules[other].name),
			)
			gdext_print("odin reload: module class collision", msg)
			scripts_note_error(msg)
			delete(msg)
			return false
		}
	}

	// 4. Re-index THIS module's class set (other modules' entries untouched). The
	//    `affected` set (old ∪ new names) scopes the cache invalidation + rebind below.
	mod := &g_modules[mi]
	affected := make(map[string]bool, context.temp_allocator)
	for old in mod.classes {
		affected[strings.clone(old, context.temp_allocator)] = true
		delete_key(&scripts_classes, old)
		// Invalidate the per-class cache (rebuilt lazily by ensure_class_cache during
		// rebind). The old cache struct is leaked — a small, documented per-reload cost
		// acceptable for a dev loop (same policy as the pre-spike full clear).
		if class_caches != nil {
			delete_key(&class_caches, old)
		}
		delete(old) // the ONE shared clone backing both mod.classes and the map key
	}
	clear(&mod.classes)
	for i in 0 ..< int(n) {
		d := descs[i]
		name := strings.clone(string(d.name))
		scripts_classes[name] = d
		append(&mod.classes, name)
		if !(name in affected) {
			affected[strings.clone(name, context.temp_allocator)] = true
		}
	}

	// 5. Re-bind live instances of THIS module's classes BEFORE returning (no stale proc
	//    may run after). Instances of other modules are skipped — untouched by design.
	rebind_all_instances(affected)

	mod.dll = new_dll
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
