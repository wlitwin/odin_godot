//gd:extends Node
//gd:class AuthoringBoot
package authoring_test_scripts
import "godot:gdext"
import gd "godot:godot"

AuthoringBoot :: struct {
    owner: gd.Node,
}

@(export)
odin_scripts_boot :: proc "c" (
    get_proc_address: gdext.ExtensionInterfaceGetProcAddress,
    library: gdext.ExtensionClassLibraryPtr,
) {
    gdext.init(library, get_proc_address)
    gd.init()
}
