package scripts

// REQUIRED boilerplate — keep this file in your scripts package and you never need to
// edit it. The odin_godot CORE dll calls `odin_scripts_boot` immediately after it
// dlopens your compiled scripts dll, so this dll can initialize its OWN gdext/godot
// package globals before any of your script procs (lifecycle hooks, methods, signals)
// run. Without it, your scripts dll loads but its godot bindings are uninitialized.

import "godot:gdext"
import "godot:godot"

@(export)
odin_scripts_boot :: proc "c" (
	get_proc_address: gdext.ExtensionInterfaceGetProcAddress,
	library: gdext.ExtensionClassLibraryPtr,
) {
	gdext.init(library, get_proc_address)
	godot.init()
}
