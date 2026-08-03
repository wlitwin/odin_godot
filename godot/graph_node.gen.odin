package godot

import __bindgen_gde "godot:gdext"

Graph_Node_Constants :: enum {
}



graph_node_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

graph_node_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_graph_node :: proc "contextless" () -> Graph_Node {
    return cast(Graph_Node)__bindgen_gde.classdb_construct_object(graph_node_name_ref())
}

// methods
//
// Method binds are resolved LAZILY on first call (the `@(static) __ptr` guard),
// NOT eagerly in `_init`. Many engine classes (Node, Control, the *Server
// singletons, ...) are only registered with ClassDB at later initialization
// levels (Servers/Scene), while `godot.init()` runs at the extension entry
// (Core level). Eagerly fetching every bind there returned null for ~91% of
// methods (a 16k-line `mb is null` flood). Resolving on first call defers the
// fetch to a point where the owning class is registered, mirroring how the
// builtin/variant methods already work. A genuinely unresolvable bind stays
// nil and the following ptrcall surfaces it at the call site.
//
// VARARG methods (`is_vararg` in extension_api.json) cannot use ptrcall — Godot
// aborts with "ptrcall can't be used with vararg methods". They instead go
// through `object_method_bind_call`: the fixed declared args are marshalled to
// Variants, the variadic `extra: ..Variant` are appended, and the returned
// Variant is converted to the declared return type (Variant passed through,
// `Error`/ints via variant_to_int, void ignored).

graph_node__draw_port :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
    position_: Vector2i,
    left_: Bool,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_draw_port", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 93366828)
    }
    self := self
    slot_index_ := slot_index_
    position_ := position_
    left_ := left_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
        &position_,
        &left_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_set_title :: proc "contextless" (
    self: Graph_Node,
    title_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_title", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    title_ := title_
    args := []__bindgen_gde.TypePtr {
        &title_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_get_title :: proc "contextless" (
    self: Graph_Node,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_title", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_get_titlebar_hbox :: proc "contextless" (
    self: Graph_Node,
) -> (ret: H_Box_Container) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_titlebar_hbox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3590609951)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_set_slot :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
    enable_left_port_: Bool,
    type_left_: Int,
    color_left_: Color,
    enable_right_port_: Bool,
    type_right_: Int,
    color_right_: Color,
    custom_icon_left_: Texture2d,
    custom_icon_right_: Texture2d,
    draw_stylebox_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_slot", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2873310869)
    }
    self := self
    slot_index_ := slot_index_
    enable_left_port_ := enable_left_port_
    type_left_ := type_left_
    color_left_ := color_left_
    enable_right_port_ := enable_right_port_
    type_right_ := type_right_
    color_right_ := color_right_
    custom_icon_left_ := custom_icon_left_
    custom_icon_right_ := custom_icon_right_
    draw_stylebox_ := draw_stylebox_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
        &enable_left_port_,
        &type_left_,
        &color_left_,
        &enable_right_port_,
        &type_right_,
        &color_right_,
        &custom_icon_left_,
        &custom_icon_right_,
        &draw_stylebox_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_clear_slot :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_slot", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    slot_index_ := slot_index_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_clear_all_slots :: proc "contextless" (
    self: Graph_Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_all_slots", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_is_slot_enabled_left :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_slot_enabled_left", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    slot_index_ := slot_index_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_set_slot_enabled_left :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_slot_enabled_left", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    slot_index_ := slot_index_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_set_slot_type_left :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
    type_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_slot_type_left", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    slot_index_ := slot_index_
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_get_slot_type_left :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_slot_type_left", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    slot_index_ := slot_index_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_set_slot_color_left :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_slot_color_left", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878471219)
    }
    self := self
    slot_index_ := slot_index_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_get_slot_color_left :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_slot_color_left", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3457211756)
    }
    self := self
    slot_index_ := slot_index_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_set_slot_custom_icon_left :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
    custom_icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_slot_custom_icon_left", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 666127730)
    }
    self := self
    slot_index_ := slot_index_
    custom_icon_ := custom_icon_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
        &custom_icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_get_slot_custom_icon_left :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_slot_custom_icon_left", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3536238170)
    }
    self := self
    slot_index_ := slot_index_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_set_slot_metadata_left :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_slot_metadata_left", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2152698145)
    }
    self := self
    slot_index_ := slot_index_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_get_slot_metadata_left :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_slot_metadata_left", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4227898402)
    }
    self := self
    slot_index_ := slot_index_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_is_slot_enabled_right :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_slot_enabled_right", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    slot_index_ := slot_index_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_set_slot_enabled_right :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_slot_enabled_right", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    slot_index_ := slot_index_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_set_slot_type_right :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
    type_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_slot_type_right", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    slot_index_ := slot_index_
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_get_slot_type_right :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_slot_type_right", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    slot_index_ := slot_index_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_set_slot_color_right :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_slot_color_right", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878471219)
    }
    self := self
    slot_index_ := slot_index_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_get_slot_color_right :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_slot_color_right", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3457211756)
    }
    self := self
    slot_index_ := slot_index_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_set_slot_custom_icon_right :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
    custom_icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_slot_custom_icon_right", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 666127730)
    }
    self := self
    slot_index_ := slot_index_
    custom_icon_ := custom_icon_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
        &custom_icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_get_slot_custom_icon_right :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_slot_custom_icon_right", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3536238170)
    }
    self := self
    slot_index_ := slot_index_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_set_slot_metadata_right :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_slot_metadata_right", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2152698145)
    }
    self := self
    slot_index_ := slot_index_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_get_slot_metadata_right :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_slot_metadata_right", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4227898402)
    }
    self := self
    slot_index_ := slot_index_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_is_slot_draw_stylebox :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_slot_draw_stylebox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    slot_index_ := slot_index_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_set_slot_draw_stylebox :: proc "contextless" (
    self: Graph_Node,
    slot_index_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_slot_draw_stylebox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    slot_index_ := slot_index_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &slot_index_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_set_ignore_invalid_connection_type :: proc "contextless" (
    self: Graph_Node,
    ignore_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_ignore_invalid_connection_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    ignore_ := ignore_
    args := []__bindgen_gde.TypePtr {
        &ignore_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_is_ignoring_valid_connection_type :: proc "contextless" (
    self: Graph_Node,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_ignoring_valid_connection_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_set_slots_focus_mode :: proc "contextless" (
    self: Graph_Node,
    focus_mode_: Control_Focus_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_slots_focus_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3232914922)
    }
    self := self
    focus_mode_ := focus_mode_
    args := []__bindgen_gde.TypePtr {
        &focus_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_node_get_slots_focus_mode :: proc "contextless" (
    self: Graph_Node,
) -> (ret: Control_Focus_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_slots_focus_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2132829277)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_get_input_port_count :: proc "contextless" (
    self: Graph_Node,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_port_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_get_input_port_position :: proc "contextless" (
    self: Graph_Node,
    port_idx_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_port_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3114997196)
    }
    self := self
    port_idx_ := port_idx_
    args := []__bindgen_gde.TypePtr {
        &port_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_get_input_port_type :: proc "contextless" (
    self: Graph_Node,
    port_idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_port_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    port_idx_ := port_idx_
    args := []__bindgen_gde.TypePtr {
        &port_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_get_input_port_color :: proc "contextless" (
    self: Graph_Node,
    port_idx_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_port_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2624840992)
    }
    self := self
    port_idx_ := port_idx_
    args := []__bindgen_gde.TypePtr {
        &port_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_get_input_port_slot :: proc "contextless" (
    self: Graph_Node,
    port_idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_port_slot", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    port_idx_ := port_idx_
    args := []__bindgen_gde.TypePtr {
        &port_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_get_output_port_count :: proc "contextless" (
    self: Graph_Node,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_output_port_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_get_output_port_position :: proc "contextless" (
    self: Graph_Node,
    port_idx_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_output_port_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3114997196)
    }
    self := self
    port_idx_ := port_idx_
    args := []__bindgen_gde.TypePtr {
        &port_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_get_output_port_type :: proc "contextless" (
    self: Graph_Node,
    port_idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_output_port_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    port_idx_ := port_idx_
    args := []__bindgen_gde.TypePtr {
        &port_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_get_output_port_color :: proc "contextless" (
    self: Graph_Node,
    port_idx_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_output_port_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2624840992)
    }
    self := self
    port_idx_ := port_idx_
    args := []__bindgen_gde.TypePtr {
        &port_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_node_get_output_port_slot :: proc "contextless" (
    self: Graph_Node,
    port_idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_output_port_slot", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    port_idx_ := port_idx_
    args := []__bindgen_gde.TypePtr {
        &port_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
graph_node_get_ignore_invalid_connection_type :: proc "contextless" (self: Graph_Node) -> Bool {
    return graph_node_is_ignoring_valid_connection_type(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
graph_node_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GraphNode", true)
}

@(private = "file")
__class_name: String_Name