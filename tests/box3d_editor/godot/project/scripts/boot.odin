//gd:extends Node
//gd:class EditorBoot
package editor_test_scripts
import "godot:gdext"
import gd "godot:godot"
EditorBoot :: struct {owner:gd.Node}
@(export)
odin_scripts_boot :: proc "c"(get_proc_address:gdext.ExtensionInterfaceGetProcAddress,library:gdext.ExtensionClassLibraryPtr){gdext.init(library,get_proc_address);gd.init()}
