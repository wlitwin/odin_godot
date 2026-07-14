package speedball

// ----------------------------------------------------------------------------
// boot — cross-DLL gdext init for the quickdraw scripts dll.
//
// Every odin_godot project compiles its scripts into ONE shared dll with its own copy of the
// gdext/godot package globals (method-bind caches, the interface fn table, ...). The core calls
// `odin_scripts_boot` right after it dlopen's this dll, BEFORE any lifecycle/method/signal proc
// runs, so we initialize those globals here. This file is identical in every project.
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
