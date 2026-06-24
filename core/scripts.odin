package core

import "godot:gdext"
import rt "godot:runtime"
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
// Either way the result is the same: a `scripts_classes` map the rest of the core uses
// to bind a `.odin` file to a registered Class_Desc.
// ----------------------------------------------------------------------------

// Saved at the core's entry point. NATIVE forwards it to the scripts dll's boot (that
// dll has its own gdext/godot globals). On WEB it is unused (one module, shared globals).
@(private)
saved_get_proc_address: gdext.ExtensionInterfaceGetProcAddress

// class name -> its registered descriptor. The `name`/`base` cstrings are static for
// the module's lifetime (native: in the scripts dll; web: in this module). The map
// keys are heap-cloned by index_scripts_manifest.
@(private)
scripts_classes: map[string]rt.Class_Desc

@(private)
scripts_find_class :: proc(name: string) -> (rt.Class_Desc, bool) {
	desc, ok := scripts_classes[name]
	return desc, ok
}

// Build the class-name -> Class_Desc map from a manifest (descs/count). Uses the core
// allocator (alignment-correct for maps). Shared by both the native and web loaders.
@(private)
index_scripts_manifest :: proc(descs: [^]rt.Class_Desc, n: int) {
	context.allocator = core_allocator()
	scripts_classes = make(map[string]rt.Class_Desc)
	for i in 0 ..< n {
		d := descs[i]
		name := strings.clone(string(d.name))
		scripts_classes[name] = d
	}
}
