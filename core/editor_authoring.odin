#+build darwin, linux, windows
package core

import "godot:gdext"
import "godot:godot"
import "core:fmt"
import "core:strings"
import "core:os"
import decl "godot:decl"
import source "editor_source"

// Match the shipped binding spellings, including engine acronym names.
@(private = "file")
editor_binding_types: map[string]string

@(private = "file")
callback_source, callback_name: string

@(private)
editor_authoring_clear :: proc() {
    context.allocator = core_allocator()
    for key, value in editor_binding_types {delete(key); delete(value)}
    delete(editor_binding_types)
    editor_binding_types = nil
    delete(callback_source)
    delete(callback_name)
    callback_source, callback_name = "", ""
}

@(private = "file")
editor_bindings :: proc() -> map[string]string {
    if len(editor_binding_types) > 0 {return editor_binding_types}
    context.allocator = core_allocator()
    root := odin_collection_root(context.temp_allocator)
    if root == "" {return nil}
    editor_binding_types = make(map[string]string)
    for relative in ([]string{"/godot/godot.gen.odin", "/godot/Variant.odin"}) {
        path := strings.concatenate({root, relative}, context.temp_allocator)
        if bytes, err := os.read_entire_file(path, context.temp_allocator); err == nil {
            source.index_bindings(string(bytes), &editor_binding_types)
        }
    }
    return editor_binding_types
}

@(private)
make_odin_template :: proc(class_name, base: string) -> string {
    class_name := source.script_identifier(class_name, context.temp_allocator)
    snake := decl.snake_name(class_name, context.temp_allocator)
    handle := editor_bindings()[source.normalize(base)]
    if handle == "" {handle = "Object"}
    b := strings.builder_make()
    fmt.sbprintf(&b, "//gd:extends %s\npackage scripts\n\n", base)
    strings.write_string(&b, "import gd \"godot:godot\"\n\n")
    fmt.sbprintf(&b, "%s :: struct {{\n\towner: gd.%s, // Godot object; script state is self.\n}}\n", class_name, handle)
    base_name := godot.new_string_name_odin(base)
    defer godot.free_string_name(base_name)
    node_name := godot.new_string_name_cstring("Node", true)
    defer godot.free_string_name(node_name)
    if base == "Node" || bool(godot.class_db_is_parent_class(godot.singleton_class_db(), base_name, node_name)) {
        fmt.sbprintf(&b, "\n%s_ready :: proc(self: ^%s) {{\n}}\n\n", snake, class_name)
        fmt.sbprintf(&b, "%s_process :: proc(self: ^%s, delta: f64) {{\n}}\n", snake, class_name)
    }
    return strings.to_string(b)
}

@(private)
lv_find_function :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    name := string_to_odin((cast(^godot.String)args[0])^, context.temp_allocator)
    code := string_to_odin((cast(^godot.String)args[1])^, context.temp_allocator)
    info := source.inspect(code, context.temp_allocator)
    // Godot invokes this hook when deciding whether to create a signal method.
    // Plain helpers navigate through the validate/outline list; they must not
    // masquerade as callable methods and suppress callback generation.
    line := source.find_callback(info, name)
    // add_callback invokes find_function with its target's unsaved text, then
    // make_function synchronously. The target tab need not be the active one.
    delete(callback_source, core_allocator())
    delete(callback_name, core_allocator())
    callback_source, callback_name = "", ""
    if line < 0 {
        callback_source = strings.clone(code, core_allocator())
        callback_name = strings.clone(name, core_allocator())
    }
    ret_int(ret, i64(line))
}

@(private)
lv_make_function :: proc "c" (instance: gdext.ExtensionClassInstancePtr, args: [^]gdext.TypePtr, ret: gdext.TypePtr) {
    context = gdext.godot_context()
    // Godot passes an empty class name. The preceding find_function supplies
    // the exact target buffer; the active buffer is a fallback for direct calls.
    editor := godot.editor_interface_get_script_editor(godot.singleton_editor_interface())
    current := godot.script_editor_get_current_editor(editor)
    code := ""
    if current != nil {
        text := godot.script_editor_base_get_base_editor(current)
        if text != nil {
            value := godot.text_edit_get_text(cast(godot.Text_Edit)text)
            code = string_to_odin(value, context.temp_allocator)
            godot.free_string(value)
        }
    }
    name := string_to_odin((cast(^godot.String)args[1])^, context.temp_allocator)
    if callback_name == name {code = callback_source}
    info := source.inspect(code, context.temp_allocator)
    delete(callback_source, core_allocator())
    delete(callback_name, core_allocator())
    callback_source, callback_name = "", ""
    packed := cast(^godot.Packed_String_Array)args[2]
    parameters := make([]string, int(godot.packed_string_array_size(packed)), context.temp_allocator)
    for &parameter, i in parameters {
        value := godot.packed_string_array_get(packed, godot.Int(i))
        parameter = string_to_odin(value, context.temp_allocator)
        godot.free_string(value)
    }
    generated := source.make_function(info, name, parameters, editor_bindings(), context.temp_allocator)
    if generated == "" {
        godot.error(fmt.ctprintf("Cannot create Odin callback %s: %s.", name, source.callback_problem(info, name)))
    }
    ret_string(ret, godot.new_string_odin(generated))
}
