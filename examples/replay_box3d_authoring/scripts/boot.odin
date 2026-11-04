//gd:extends Node
//gd:class ReplayAuthoringBoot
package replay_authoring_scripts

import "godot:gdext"
import gd "godot:godot"

ReplayAuthoringBoot :: struct {owner:gd.Node}
@(export)
odin_scripts_boot :: proc "c"(get_proc_address:gdext.ExtensionInterfaceGetProcAddress,library:gdext.ExtensionClassLibraryPtr){gdext.init(library,get_proc_address);gd.init()}
