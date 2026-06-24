package phase5_scripts

// Cross-DLL gdext init for the Phase 5 scripts dll (same contract as
// showcase/boot.odin and tests/phase35/scripts/boot.odin): the core calls
// `odin_scripts_boot` right after dlopen so this dll initializes ITS OWN
// gdext/godot package globals before any lifecycle/method proc runs.

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
