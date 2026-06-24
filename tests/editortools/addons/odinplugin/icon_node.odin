//gd:extends Node
//gd:class IconNode
//gd:icon res://icon.svg
package odinplugin

// IconNode — a global Odin class that declares a CUSTOM CLASS ICON via the `//gd:icon`
// marker. The path threads into BOTH the script's `_get_class_icon_path` virtual AND the
// global class registry's `icon_path` (OdinLanguage._get_global_class_name), so the editor
// shows `IconNode` with `res://icon.svg` in the Scene dock + Create Node dialog.
//
// VERIFIED headless: `load(...).get_class_icon_path()` returns "res://icon.svg" (the exact
// virtual the editor reads). The icon PIXELS rendering in the dock is visual-only.

import gd "godot:godot"

IconNode :: struct {
	owner: gd.Node,
}
