//gd:extends Node
//gd:class ToolProbe
//gd:tool
package phase35_scripts

// ToolProbe — a `//gd:tool` script. Codegen sets `tool = true` in the Class_Desc,
// so OdinScript._is_tool reports true.

import gd "godot:godot"

ToolProbe :: struct {
	owner: gd.Node,
}
