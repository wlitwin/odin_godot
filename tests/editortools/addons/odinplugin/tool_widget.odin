//gd:extends Node
//gd:class ToolWidget
//gd:tool
package odinplugin

// ToolWidget — a `//gd:tool` script. Because it is a tool, the engine builds a REAL
// instance in the EDITOR (not a placeholder), so its `_ready` runs at edit time. It uses
// the `gd.is_editor()` ergonomic helper to branch on editor-vs-game and records an
// observable side-effect (a ProjectSetting) the test driver reads back to PROVE the
// editor-side `_ready` actually ran AND that `gd.is_editor()` returned true in the editor.

import gd "godot:godot"

ToolWidget :: struct {
	owner: gd.Node,
}

// Sentinel the driver asserts. Written ONLY on the editor branch of gd.is_editor(), so the
// driver reading 4242 back proves both: (a) this _ready executed in edit mode, and (b)
// gd.is_editor() correctly reported true there.
TOOL_EDITOR_SENTINEL :: 4242

tool_widget_ready :: proc(self: ^ToolWidget) {
	if gd.is_editor() {
		gd.set_setting_int("odin/tool_widget_editor_ran", TOOL_EDITOR_SENTINEL)
		gd.print("EDITORTOOLS_TOOL_READY_IN_EDITOR")
	} else {
		// At game runtime this branch runs instead (is_editor() == false).
		gd.set_setting_int("odin/tool_widget_editor_ran", 1)
	}
}
