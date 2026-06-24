//gd:extends EditorInspectorPlugin
//gd:class OdinInspectorPlugin
//gd:tool
package odinplugin

// OdinInspectorPlugin (STRETCH) — an EditorInspectorPlugin written in Odin. It customizes
// the Inspector: `_can_handle(object)` decides whether to customize a given object, and
// `_parse_begin(object)` runs at the top of that object's Inspector to add custom controls.
//
// HONEST STATUS:
//   * The virtuals are exposed as engine-named methods (`_can_handle` / `_parse_begin`) via
//     the codegen's prefix-strip (the double underscore yields the leading `_`). The test
//     driver DIRECTLY invokes them on an instance (`insp.call("_can_handle", obj)` etc.) and
//     asserts the Odin code runs — so virtual DISPATCH into Odin is proven headless.
//   * Whether the EDITOR auto-invokes them during a live Inspector rebuild (after the plugin
//     is registered via add_inspector_plugin and an object is selected in the dock) is a
//     VISUAL, UI-driven path that cannot be exercised headless — documented as visual-only.
//
// `_parse_begin` takes an Object; `_can_handle` takes an Object and returns bool. The codegen
// marshals `^gd.Object` <-> Variant Object for both.

import gd "godot:godot"

OdinInspectorPlugin :: struct {
	owner: gd.Object,
}

// `_can_handle(object: Object) -> bool` — customize every object (true). The gd_name is
// exactly `_can_handle` (struct-prefix `odin_inspector_plugin_` stripped from the double
// underscore), which is the engine virtual name the Inspector dispatches.
@(gd_method)
odin_inspector_plugin__can_handle :: proc(self: ^OdinInspectorPlugin, object: ^gd.Object) -> bool {
	return true
}

// `_parse_begin(object: Object)` — runs at the top of the object's Inspector. Here it just
// emits an observable sentinel (a real plugin would `add_custom_control(...)` a label/button).
@(gd_method)
odin_inspector_plugin__parse_begin :: proc(self: ^OdinInspectorPlugin, object: ^gd.Object) {
	gd.print("EDITORTOOLS_INSPECTOR_PARSE_BEGIN")
}
