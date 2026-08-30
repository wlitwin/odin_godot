package core

import "godot:gdext"
import "godot:godot"
import rt "godot:runtime"
import "core:fmt"
import "core:strings"

// ----------------------------------------------------------------------------
// Scripts indexing — the part shared by the NATIVE dll-load path and the WEB
// in-module path.
//
//   * NATIVE (scripts_native.odin): the compiled `.odin` scripts live in a SEPARATE
//     dll. The core dlopens it, calls `odin_scripts_boot` so it inits its OWN gdext/
//     godot globals, then `odin_scripts_manifest` to learn its classes. Hot reload
//     swaps that dll under a running game.
//   * WEB (scripts_web.odin): the scripts package + the `runtime` registry are linked
//     INTO this same wasm module. There is no dlopen/boot; the manifest is read by
//     calling `rt.odin_scripts_manifest()` directly after `web_startup` has run the
//     scripts' `@(init)` self-registration.
//
// Either way the result is the same: a path-keyed descriptor map plus a separate map
// for optional explicit Godot global-class aliases.
// ----------------------------------------------------------------------------

// Saved at the core's entry point. NATIVE forwards it to the scripts dll's boot (that
// dll has its own gdext/godot globals). On WEB it is unused (one module, shared globals).
@(private)
saved_get_proc_address: gdext.ExtensionInterfaceGetProcAddress

// Canonical `res://` source identity -> descriptor. This is the primary binding and
// hot-reload index; struct names and engine base types never participate.
@(private)
scripts_classes: map[string]rt.Class_Desc

@(private)
scripts_find_path :: proc(path: string) -> (rt.Class_Desc, bool) {
	desc, ok := scripts_classes[path]
	return desc, ok
}

// Optional explicit `//gd:class` alias -> descriptor. Kept separate so marker-less
// scripts with identical struct/base names remain unambiguous by path.
@(private)
scripts_global_classes: map[string]rt.Class_Desc

@(private)
scripts_find_global_class :: proc(name: string) -> (rt.Class_Desc, bool) {
	desc, ok := scripts_global_classes[name]
	return desc, ok
}

// Module name for a `res://` script path under the multi-module layout (Phase 5 spike):
// `res://modules/<name>/...` -> "<name>"; anything else (res://scripts/..., addons, etc.)
// -> "" (the MAIN module). Pure string logic, shared by native (per-module reload routing)
// and web (where it is unused but must compile). Returns a VIEW into `path`.
@(private)
scripts_module_for_res_path :: proc(path: string) -> string {
	prefix :: "res://modules/"
	if strings.has_prefix(path, prefix) {
		rest := path[len(prefix):]
		if idx := strings.index_byte(rest, '/'); idx > 0 {
			return rest[:idx]
		}
	}
	return ""
}

// Build the source-path and optional global-alias indexes from a manifest. Uses the
// core allocator (alignment-correct for maps). On web every script module contributes
// to one manifest, so alias conflicts are diagnosed here with both source paths while
// both path identities remain usable.
@(private)
index_scripts_manifest :: proc(descs: [^]rt.Class_Desc, n: int) {
	context.allocator = core_allocator()
	scripts_classes = make(map[string]rt.Class_Desc)
	scripts_global_classes = make(map[string]rt.Class_Desc)
	for i in 0 ..< n {
		d := descs[i]
		identity_ptr := rt.desc_identity(d)
		if identity_ptr == nil {continue}
		identity := string(identity_ptr)
		if prev, dup := scripts_classes[identity]; dup {
			msg := fmt.aprintf(
				"odin_godot: duplicate script source identity '%s' (%s and %s); the later descriptor was ignored.",
				identity,
				prev.path != nil ? string(prev.path) : string(prev.name),
				d.path != nil ? string(d.path) : string(d.name),
			)
			scripts_note_error(msg)
			delete(msg)
			continue
		}
		path_key := strings.clone(identity)
		scripts_classes[path_key] = d
		if d.global_name == nil || string(d.global_name) == "" {continue}
		alias := string(d.global_name)
		if prev, dup := scripts_global_classes[alias]; dup {
			msg := fmt.aprintf(
				"odin_godot: duplicate explicit //gd:class '%s' in '%s' and '%s'; both scripts remain path-addressable, but the global alias is ambiguous.",
				alias,
				prev.path != nil ? string(prev.path) : string(prev.name),
				d.path != nil ? string(d.path) : string(d.name),
			)
			scripts_note_error(msg)
			delete(msg)
			continue
		}
		alias_key := strings.clone(alias)
		scripts_global_classes[alias_key] = d
	}
}

// ----------------------------------------------------------------------------
// Registration errors — problems the scripts dll's runtime reflection walk recorded
// while building its Export/Onready tables at `@(init)` (bad export type, bad hint
// spec, pool exhaustion, ...). The walk runs pre-boot where nothing can print, so
// the loaders pull the table afterwards (native: dlsym'd odin_scripts_registration_
// errors; web: the rt proc directly), note them here, and the main-thread frame pump
// surfaces each as ONE push_error once the engine is up. A bad export is dropped
// from the class but must never be dropped silently.
// ----------------------------------------------------------------------------

// Formatted messages, core-allocator-owned. Drained (freed) by the surface proc.
@(private)
g_registration_errors: [dynamic]string

@(private)
scripts_note_registration_errors :: proc(errs: [^]rt.Registration_Error, n: int) {
	context.allocator = core_allocator()
	for i in 0 ..< n {
		e := errs[i]
		class := e.class != nil ? string(e.class) : "?"
		msg := e.msg != nil ? string(e.msg) : "registration error"
		formatted: string
		if e.field != nil {
			formatted = fmt.aprintf("odin_godot: %s.%s: %s", class, string(e.field), msg)
		} else {
			formatted = fmt.aprintf("odin_godot: %s: %s", class, msg)
		}
		append(&g_registration_errors, formatted)
	}
}

// Note a single pre-formatted load-time error (multi-module class collisions, module dll
// load failures) for the frame pump's push_error pass. Same surfacing channel as the
// registration errors: loud in the editor console, never silent.
@(private)
scripts_note_error :: proc(msg: string) {
	context.allocator = core_allocator()
	append(&g_registration_errors, strings.clone(msg))
}

// Push every noted registration error to the engine log (JS console on web), then
// drain. Safe to call every frame — a no-op when the list is empty.
@(private)
scripts_surface_registration_errors :: proc() {
	if len(g_registration_errors) == 0 {
		return
	}
	context.allocator = core_allocator()
	for m in g_registration_errors {
		s := godot.new_string_odin(m)
		godot.gd_push_error(godot.variant_from_string(&s))
		delete(m)
	}
	clear(&g_registration_errors)
}
