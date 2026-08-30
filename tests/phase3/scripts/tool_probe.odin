//gd:extends Node
//gd:class ToolProbe
//gd:tool
package showcase

// ----------------------------------------------------------------------------
// ToolProbe — a `//gd:tool` script. `desc.tool = true` makes OdinScript._is_tool
// report true, so the engine runs/instantiates it in the editor context.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

ToolProbe :: struct {
	owner: gd.Node,
}

@(init)
_register_tool_probe :: proc "contextless" () {
	rt.register(
		rt.Class_Desc {
			name = "ToolProbe",
			path = "res://scripts/tool_probe.odin",
			global_name = "ToolProbe",
			base = "Node",
			size = size_of(ToolProbe),
			align = align_of(ToolProbe),
			tool = true,
		},
	)
}
