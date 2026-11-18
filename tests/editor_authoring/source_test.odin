package editor_authoring_test

import "core:testing"
import "core:strings"
import editor "godot:core/editor_source"
import decl "godot:decl"

@(test)
unsaved_navigation :: proc(t: ^testing.T) {
    code := `package scripts
import g "godot:godot"
HUD_View :: struct {owner:g.Node}
// fake :: proc() {}
text :: "other :: proc() {}"
@(gd_method)
hud_view__on_pressed :: proc(self:^HUD_View) {
    local :: proc() {}
}
when ODIN_OS == .Darwin {
    platform_helper :: proc() {}
}
`
    info := editor.inspect(code, context.temp_allocator)
    testing.expect_value(t, info.script, "HUD_View")
    testing.expect_value(t, info.godot_alias, "g")
    testing.expect_value(t, len(info.functions), 2)
    testing.expect_value(t, editor.find_callback(info, "_on_pressed"), 7)
    testing.expect_value(t, info.functions[0].name, "hud_view__on_pressed")
    testing.expect_value(t, info.functions[1].name, "platform_helper")
    testing.expect_value(t, info.functions[1].line, 11)
    testing.expect_value(t, editor.find_callback(info, "platform_helper"), -1)
    testing.expect_value(t, editor.find_callback(info, "local"), -1)
    testing.expect_value(t, editor.find_callback(info, "fake"), -1)
    testing.expect_value(t, decl.snake_name("HUD_View", context.temp_allocator), "hud_view")
    testing.expect_value(t, decl.snake_name("XMLParser", context.temp_allocator), "xml_parser")
    testing.expect_value(t, editor.script_identifier("map", context.temp_allocator), "Map")
    testing.expect_value(t, editor.script_identifier("player-controller", context.temp_allocator), "Player_Controller")
    testing.expect_value(t, editor.script_identifier("123", context.temp_allocator), "_123")
}

@(test)
helpers_are_not_callbacks :: proc(t: ^testing.T) {
    info := editor.inspect(`package scripts
import gd "godot:godot"
Player :: struct {owner:gd.Node}
_on_pressed :: proc() {}
player__on_collision :: proc() {}
`, context.temp_allocator)
    bindings := make(map[string]string, context.temp_allocator)
    testing.expect_value(t, editor.find_callback(info, "_on_pressed"), -1)
    testing.expect(t, strings.contains(editor.make_function(info, "_on_pressed", nil, bindings, context.temp_allocator), "player__on_pressed :: proc"))
    testing.expect_value(t, editor.make_function(info, "_on_collision", nil, bindings, context.temp_allocator), "")
    testing.expect(t, strings.contains(editor.callback_problem(info, "_on_collision"), "rename the helper"))
    generated := editor.make_function(info, "_on_pressed", nil, bindings, context.temp_allocator)
    complete := editor.inspect(strings.concatenate({`package scripts
import gd "godot:godot"
Player :: struct {owner:gd.Node}
_on_pressed :: proc() {}
`, generated}, context.temp_allocator), context.temp_allocator)
    testing.expect_value(t, editor.outline_name(complete, complete.functions[0]), "_on_pressed (Odin helper)")
    testing.expect_value(t, editor.outline_name(complete, complete.functions[1]), "_on_pressed")
}

@(test)
callback_arguments :: proc(t: ^testing.T) {
    info := editor.inspect("package scripts\nimport g \"godot:godot\"\nHUD_View :: struct {owner:g.Node}\n", context.temp_allocator)
    bindings := make(map[string]string, context.temp_allocator)
    editor.index_bindings("Node2d :: Canvas_Item\nPacked_Byte_Array :: Packed_Array(u8)\n", &bindings, context.temp_allocator)
    text := editor.make_function(info, "_on_input", {"body:Node2D", "value:float", "map:int", "self:String", "self:String", "unknown", "bytes:PackedByteArray"}, bindings, context.temp_allocator)
    testing.expect(t, strings.contains(text, "hud_view__on_input :: proc(self: ^HUD_View"))
    for part in ([]string{"body: g.Node2d", "value: f64", "map_: i64", "self_2: string", "self_3: string", "unknown: g.Variant", "bytes: g.Packed_Byte_Array"}) {
        testing.expect(t, strings.contains(text, part), text)
    }
    testing.expect(t, strings.contains(text, "@(gd_method)"))
    testing.expect_value(t, editor.make_function({}, "_on_input", nil, bindings, context.temp_allocator), "")
}
