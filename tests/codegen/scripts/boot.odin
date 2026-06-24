package codegen_scripts

// Cross-DLL gdext init for the codegen scripts dll. The core calls `odin_scripts_boot`
// right after dlopen so this dll initializes ITS OWN gdext/godot package globals before
// any lifecycle / method / set / get proc runs.

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
