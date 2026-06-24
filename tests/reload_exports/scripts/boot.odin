package reload_exports_scripts

// Cross-DLL gdext init for the reload_exports scripts dll. The core calls
// `odin_scripts_boot` right after dlopen (on first load AND every hot reload / save-rebuild
// swap) so this dll initializes ITS OWN gdext/godot package globals before any lifecycle or
// property proc runs. Identical contract to the phase4 / survivors boot.

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
