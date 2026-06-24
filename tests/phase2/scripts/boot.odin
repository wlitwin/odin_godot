package showcase

// ----------------------------------------------------------------------------
// Cross-DLL gdext init — THE subtle trap.
//
// The scripts dll has its OWN COPY of the `gdext`/`godot` package globals (the
// interface function pointers and per-class method binds). They are nil in this
// dll until initialized, so a script calling `godot.node2d_set_position(...)`
// would crash. The core calls `odin_scripts_boot` immediately after dlopen,
// passing through the GDExtension interface it received at its own entry point, so
// this dll initializes ITS OWN globals — exactly as the core entry point does.
//
// ORDER (driven by the core): dlopen -> odin_scripts_boot -> odin_scripts_manifest.
// The `@(init)` self-registration already ran on dlopen, but it only touched the
// pure-data runtime registry, so it is safe to have run before boot.
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
