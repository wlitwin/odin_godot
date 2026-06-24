package survivors_scripts

// ----------------------------------------------------------------------------
// boot — cross-DLL gdext init for the survivors scripts dll.
//
// Every odin_godot project compiles its scripts into ONE shared dll. That dll has its
// own copy of the gdext/godot package globals (method-bind caches, the interface fn
// table, ...). The core calls `odin_scripts_boot` right after it dlopen's this dll, BEFORE
// any lifecycle / method / signal proc runs, so we initialize those globals here.
//
// This file is identical in every project — copy it verbatim. (See the authoring guide's
// "Building" section and tests/showcase/scripts/boot.odin for the rationale.)
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
