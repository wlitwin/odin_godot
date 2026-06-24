package odinplugin

// Cross-DLL gdext init for the editortools scripts dll. The core calls
// `odin_scripts_boot` right after dlopen so this dll initializes ITS OWN gdext/godot
// package globals before any lifecycle / method / virtual proc runs. (Same handshake
// as every other scripts dll in tests/.)

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
