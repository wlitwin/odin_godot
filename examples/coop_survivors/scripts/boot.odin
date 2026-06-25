package coop_scripts

// ----------------------------------------------------------------------------
// boot — cross-DLL gdext init for the co-op survivors scripts dll. The core dlopens this dll
// and calls `odin_scripts_boot` so it initializes ITS OWN gdext/godot package globals before
// any lifecycle / method / RPC proc runs. Identical in every project — copy verbatim.
// ----------------------------------------------------------------------------

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
