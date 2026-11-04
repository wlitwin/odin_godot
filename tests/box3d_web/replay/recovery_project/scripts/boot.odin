//gd:extends Node
//gd:class WebBoot
package web_boot
import gd "godot:godot"
import "godot:gdext"
WebBoot :: struct{owner:gd.Node}
@(export)
odin_scripts_boot :: proc "c"(get_proc_address:gdext.ExtensionInterfaceGetProcAddress,library:gdext.ExtensionClassLibraryPtr){gdext.init(library,get_proc_address);gd.init()}
