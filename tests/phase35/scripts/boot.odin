package phase35_scripts

// Cross-DLL gdext init for the Phase 3.5 scripts dll. Same contract as
// showcase/boot.odin: the core calls `odin_scripts_boot` right after dlopen so this
// dll initializes ITS OWN gdext/godot package globals before any lifecycle/method
// (or signal-emit) proc runs. The `@(init)` self-registration ran on dlopen but only
// touched the pure-data runtime registry, so it is safe to have run pre-boot.

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
