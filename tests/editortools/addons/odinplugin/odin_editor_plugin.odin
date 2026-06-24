//gd:extends EditorPlugin
//gd:class OdinEditorPlugin
//gd:tool
package odinplugin

// OdinEditorPlugin — an EDITOR PLUGIN written in Odin. Registered via
// `addons/odinplugin/plugin.cfg` and enabled in project.godot's `[editor_plugins]`. When
// the project opens in the editor, Godot loads this script, instantiates it as an
// EditorPlugin (because it is `//gd:tool`, _can_instantiate is true in the editor), adds it
// to the editor tree, and dispatches `_enter_tree` / `_exit_tree`.
//
// `enter_tree` runs an OBSERVABLE side-effect: it prints a sentinel line AND writes a
// ProjectSetting. The test (`run.sh`) greps the `--editor --headless` log for the sentinel,
// PROVING the Odin EditorPlugin loaded + its _enter_tree executed in the editor.
//
// EditorPlugin._enter_tree / _exit_tree arrive as Node ENTER_TREE / EXIT_TREE notifications,
// which the core dispatches to these lifecycle procs (see core/instance.odin).

import gd "godot:godot"

OdinEditorPlugin :: struct {
	owner: gd.Node,
}

odin_editor_plugin_enter_tree :: proc(self: ^OdinEditorPlugin) {
	// Observable sentinel #1: a log line the headless-editor run greps for.
	gd.print("EDITORTOOLS_PLUGIN_ENTER_TREE")
	// Observable sentinel #2: a ProjectSetting a driver could read back.
	gd.set_setting_int("odin/editor_plugin_entered", 1)
}

odin_editor_plugin_exit_tree :: proc(self: ^OdinEditorPlugin) {
	gd.print("EDITORTOOLS_PLUGIN_EXIT_TREE")
}
