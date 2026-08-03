package godot

import __bindgen_gde "godot:gdext"

Graph_Edit_Constants :: enum {
}
Graph_Edit_Panning_Scheme :: enum int {
    Scroll_Zooms = 0,
    Scroll_Pans = 1,
}
Graph_Edit_Grid_Pattern :: enum int {
    Grid_Pattern_Lines = 0,
    Grid_Pattern_Dots = 1,
}



graph_edit_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

graph_edit_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_graph_edit :: proc "contextless" () -> Graph_Edit {
    return cast(Graph_Edit)__bindgen_gde.classdb_construct_object(graph_edit_name_ref())
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

graph_edit__is_in_input_hotzone :: proc "contextless" (
    self: Graph_Edit,
    in_node_: Object,
    in_port_: Int,
    mouse_position_: Vector2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_in_input_hotzone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1779768129)
    }
    self := self
    in_node_ := in_node_
    in_port_ := in_port_
    mouse_position_ := mouse_position_
    args := []__bindgen_gde.TypePtr {
        &in_node_,
        &in_port_,
        &mouse_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit__is_in_output_hotzone :: proc "contextless" (
    self: Graph_Edit,
    in_node_: Object,
    in_port_: Int,
    mouse_position_: Vector2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_in_output_hotzone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1779768129)
    }
    self := self
    in_node_ := in_node_
    in_port_ := in_port_
    mouse_position_ := mouse_position_
    args := []__bindgen_gde.TypePtr {
        &in_node_,
        &in_port_,
        &mouse_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit__get_connection_line :: proc "contextless" (
    self: Graph_Edit,
    from_position_: Vector2,
    to_position_: Vector2,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_connection_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3932192302)
    }
    self := self
    from_position_ := from_position_
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &from_position_,
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit__is_node_hover_valid :: proc "contextless" (
    self: Graph_Edit,
    from_node_: String_Name,
    from_port_: Int,
    to_node_: String_Name,
    to_port_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_node_hover_valid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4216241294)
    }
    self := self
    from_node_ := from_node_
    from_port_ := from_port_
    to_node_ := to_node_
    to_port_ := to_port_
    args := []__bindgen_gde.TypePtr {
        &from_node_,
        &from_port_,
        &to_node_,
        &to_port_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_connect_node :: proc "contextless" (
    self: Graph_Edit,
    from_node_: String_Name,
    from_port_: Int,
    to_node_: String_Name,
    to_port_: Int,
    keep_alive_: Bool,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("connect_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1376144231)
    }
    self := self
    from_node_ := from_node_
    from_port_ := from_port_
    to_node_ := to_node_
    to_port_ := to_port_
    keep_alive_ := keep_alive_
    args := []__bindgen_gde.TypePtr {
        &from_node_,
        &from_port_,
        &to_node_,
        &to_port_,
        &keep_alive_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_is_node_connected :: proc "contextless" (
    self: Graph_Edit,
    from_node_: String_Name,
    from_port_: Int,
    to_node_: String_Name,
    to_port_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_node_connected", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4216241294)
    }
    self := self
    from_node_ := from_node_
    from_port_ := from_port_
    to_node_ := to_node_
    to_port_ := to_port_
    args := []__bindgen_gde.TypePtr {
        &from_node_,
        &from_port_,
        &to_node_,
        &to_port_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_disconnect_node :: proc "contextless" (
    self: Graph_Edit,
    from_node_: String_Name,
    from_port_: Int,
    to_node_: String_Name,
    to_port_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("disconnect_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1933654315)
    }
    self := self
    from_node_ := from_node_
    from_port_ := from_port_
    to_node_ := to_node_
    to_port_ := to_port_
    args := []__bindgen_gde.TypePtr {
        &from_node_,
        &from_port_,
        &to_node_,
        &to_port_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_set_connection_activity :: proc "contextless" (
    self: Graph_Edit,
    from_node_: String_Name,
    from_port_: Int,
    to_node_: String_Name,
    to_port_: Int,
    amount_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_connection_activity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1141899943)
    }
    self := self
    from_node_ := from_node_
    from_port_ := from_port_
    to_node_ := to_node_
    to_port_ := to_port_
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &from_node_,
        &from_port_,
        &to_node_,
        &to_port_,
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_set_connections :: proc "contextless" (
    self: Graph_Edit,
    connections_: Typed_Array(Dictionary),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_connections", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    connections_ := connections_
    args := []__bindgen_gde.TypePtr {
        &connections_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_connection_list :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_connection_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_get_connection_count :: proc "contextless" (
    self: Graph_Edit,
    from_node_: String_Name,
    from_port_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_connection_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 861718734)
    }
    self := self
    from_node_ := from_node_
    from_port_ := from_port_
    args := []__bindgen_gde.TypePtr {
        &from_node_,
        &from_port_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_get_closest_connection_at_point :: proc "contextless" (
    self: Graph_Edit,
    point_: Vector2,
    max_distance_: f64,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_closest_connection_at_point", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 453879819)
    }
    self := self
    point_ := point_
    max_distance_ := max_distance_
    args := []__bindgen_gde.TypePtr {
        &point_,
        &max_distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_get_connection_list_from_node :: proc "contextless" (
    self: Graph_Edit,
    node_: String_Name,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_connection_list_from_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3147814860)
    }
    self := self
    node_ := node_
    args := []__bindgen_gde.TypePtr {
        &node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_get_connections_intersecting_with_rect :: proc "contextless" (
    self: Graph_Edit,
    rect_: Rect2,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_connections_intersecting_with_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2709748719)
    }
    self := self
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_clear_connections :: proc "contextless" (
    self: Graph_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_connections", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_force_connection_drag_end :: proc "contextless" (
    self: Graph_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("force_connection_drag_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_scroll_offset :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scroll_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_scroll_offset :: proc "contextless" (
    self: Graph_Edit,
    offset_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scroll_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_add_valid_right_disconnect_type :: proc "contextless" (
    self: Graph_Edit,
    type_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_valid_right_disconnect_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_remove_valid_right_disconnect_type :: proc "contextless" (
    self: Graph_Edit,
    type_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_valid_right_disconnect_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_add_valid_left_disconnect_type :: proc "contextless" (
    self: Graph_Edit,
    type_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_valid_left_disconnect_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_remove_valid_left_disconnect_type :: proc "contextless" (
    self: Graph_Edit,
    type_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_valid_left_disconnect_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_add_valid_connection_type :: proc "contextless" (
    self: Graph_Edit,
    from_type_: Int,
    to_type_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_valid_connection_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    from_type_ := from_type_
    to_type_ := to_type_
    args := []__bindgen_gde.TypePtr {
        &from_type_,
        &to_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_remove_valid_connection_type :: proc "contextless" (
    self: Graph_Edit,
    from_type_: Int,
    to_type_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_valid_connection_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    from_type_ := from_type_
    to_type_ := to_type_
    args := []__bindgen_gde.TypePtr {
        &from_type_,
        &to_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_is_valid_connection_type :: proc "contextless" (
    self: Graph_Edit,
    from_type_: Int,
    to_type_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid_connection_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2522259332)
    }
    self := self
    from_type_ := from_type_
    to_type_ := to_type_
    args := []__bindgen_gde.TypePtr {
        &from_type_,
        &to_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_get_connection_line :: proc "contextless" (
    self: Graph_Edit,
    from_node_: Vector2,
    to_node_: Vector2,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_connection_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3932192302)
    }
    self := self
    from_node_ := from_node_
    to_node_ := to_node_
    args := []__bindgen_gde.TypePtr {
        &from_node_,
        &to_node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_attach_graph_element_to_frame :: proc "contextless" (
    self: Graph_Edit,
    element_: String_Name,
    frame_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("attach_graph_element_to_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    element_ := element_
    frame_ := frame_
    args := []__bindgen_gde.TypePtr {
        &element_,
        &frame_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_detach_graph_element_from_frame :: proc "contextless" (
    self: Graph_Edit,
    element_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("detach_graph_element_from_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    element_ := element_
    args := []__bindgen_gde.TypePtr {
        &element_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_element_frame :: proc "contextless" (
    self: Graph_Edit,
    element_: String_Name,
) -> (ret: Graph_Frame) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_element_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 988084372)
    }
    self := self
    element_ := element_
    args := []__bindgen_gde.TypePtr {
        &element_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_get_attached_nodes_of_frame :: proc "contextless" (
    self: Graph_Edit,
    frame_: String_Name,
) -> (ret: Typed_Array(String_Name)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_attached_nodes_of_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 689397652)
    }
    self := self
    frame_ := frame_
    args := []__bindgen_gde.TypePtr {
        &frame_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_panning_scheme :: proc "contextless" (
    self: Graph_Edit,
    scheme_: Graph_Edit_Panning_Scheme,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_panning_scheme", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 18893313)
    }
    self := self
    scheme_ := scheme_
    args := []__bindgen_gde.TypePtr {
        &scheme_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_panning_scheme :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Graph_Edit_Panning_Scheme) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_panning_scheme", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 549924446)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_zoom :: proc "contextless" (
    self: Graph_Edit,
    zoom_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_zoom", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    zoom_ := zoom_
    args := []__bindgen_gde.TypePtr {
        &zoom_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_zoom :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_zoom", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_zoom_min :: proc "contextless" (
    self: Graph_Edit,
    zoom_min_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_zoom_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    zoom_min_ := zoom_min_
    args := []__bindgen_gde.TypePtr {
        &zoom_min_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_zoom_min :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_zoom_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_zoom_max :: proc "contextless" (
    self: Graph_Edit,
    zoom_max_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_zoom_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    zoom_max_ := zoom_max_
    args := []__bindgen_gde.TypePtr {
        &zoom_max_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_zoom_max :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_zoom_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_zoom_step :: proc "contextless" (
    self: Graph_Edit,
    zoom_step_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_zoom_step", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    zoom_step_ := zoom_step_
    args := []__bindgen_gde.TypePtr {
        &zoom_step_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_zoom_step :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_zoom_step", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_show_grid :: proc "contextless" (
    self: Graph_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_show_grid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_is_showing_grid :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_showing_grid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_grid_pattern :: proc "contextless" (
    self: Graph_Edit,
    pattern_: Graph_Edit_Grid_Pattern,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_grid_pattern", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1074098205)
    }
    self := self
    pattern_ := pattern_
    args := []__bindgen_gde.TypePtr {
        &pattern_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_grid_pattern :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Graph_Edit_Grid_Pattern) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_grid_pattern", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286127528)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_snapping_enabled :: proc "contextless" (
    self: Graph_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_snapping_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_is_snapping_enabled :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_snapping_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_snapping_distance :: proc "contextless" (
    self: Graph_Edit,
    pixels_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_snapping_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    pixels_ := pixels_
    args := []__bindgen_gde.TypePtr {
        &pixels_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_snapping_distance :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_snapping_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_connection_lines_curvature :: proc "contextless" (
    self: Graph_Edit,
    curvature_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_connection_lines_curvature", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    curvature_ := curvature_
    args := []__bindgen_gde.TypePtr {
        &curvature_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_connection_lines_curvature :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_connection_lines_curvature", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_connection_lines_thickness :: proc "contextless" (
    self: Graph_Edit,
    pixels_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_connection_lines_thickness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    pixels_ := pixels_
    args := []__bindgen_gde.TypePtr {
        &pixels_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_connection_lines_thickness :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_connection_lines_thickness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_connection_lines_antialiased :: proc "contextless" (
    self: Graph_Edit,
    pixels_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_connection_lines_antialiased", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    pixels_ := pixels_
    args := []__bindgen_gde.TypePtr {
        &pixels_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_is_connection_lines_antialiased :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_connection_lines_antialiased", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_minimap_size :: proc "contextless" (
    self: Graph_Edit,
    size_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_minimap_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_minimap_size :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_minimap_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_minimap_opacity :: proc "contextless" (
    self: Graph_Edit,
    opacity_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_minimap_opacity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    opacity_ := opacity_
    args := []__bindgen_gde.TypePtr {
        &opacity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_minimap_opacity :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_minimap_opacity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_minimap_enabled :: proc "contextless" (
    self: Graph_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_minimap_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_is_minimap_enabled :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_minimap_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_show_menu :: proc "contextless" (
    self: Graph_Edit,
    hidden_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_show_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    hidden_ := hidden_
    args := []__bindgen_gde.TypePtr {
        &hidden_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_is_showing_menu :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_showing_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_show_zoom_label :: proc "contextless" (
    self: Graph_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_show_zoom_label", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_is_showing_zoom_label :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_showing_zoom_label", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_show_grid_buttons :: proc "contextless" (
    self: Graph_Edit,
    hidden_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_show_grid_buttons", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    hidden_ := hidden_
    args := []__bindgen_gde.TypePtr {
        &hidden_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_is_showing_grid_buttons :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_showing_grid_buttons", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_show_zoom_buttons :: proc "contextless" (
    self: Graph_Edit,
    hidden_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_show_zoom_buttons", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    hidden_ := hidden_
    args := []__bindgen_gde.TypePtr {
        &hidden_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_is_showing_zoom_buttons :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_showing_zoom_buttons", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_show_minimap_button :: proc "contextless" (
    self: Graph_Edit,
    hidden_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_show_minimap_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    hidden_ := hidden_
    args := []__bindgen_gde.TypePtr {
        &hidden_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_is_showing_minimap_button :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_showing_minimap_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_show_arrange_button :: proc "contextless" (
    self: Graph_Edit,
    hidden_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_show_arrange_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    hidden_ := hidden_
    args := []__bindgen_gde.TypePtr {
        &hidden_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_is_showing_arrange_button :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_showing_arrange_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_right_disconnects :: proc "contextless" (
    self: Graph_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_right_disconnects", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_is_right_disconnects_enabled :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_right_disconnects_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_set_type_names :: proc "contextless" (
    self: Graph_Edit,
    type_names_: Dictionary,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_type_names", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155329257)
    }
    self := self
    type_names_ := type_names_
    args := []__bindgen_gde.TypePtr {
        &type_names_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_get_type_names :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_type_names", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_get_menu_hbox :: proc "contextless" (
    self: Graph_Edit,
) -> (ret: H_Box_Container) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_menu_hbox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3590609951)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

graph_edit_arrange_nodes :: proc "contextless" (
    self: Graph_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("arrange_nodes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

graph_edit_set_selected :: proc "contextless" (
    self: Graph_Edit,
    node_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_selected", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    node_ := node_
    args := []__bindgen_gde.TypePtr {
        &node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
graph_edit_get_show_grid :: proc "contextless" (self: Graph_Edit) -> Bool {
    return graph_edit_is_showing_grid(self)
}
graph_edit_get_snapping_enabled :: proc "contextless" (self: Graph_Edit) -> Bool {
    return graph_edit_is_snapping_enabled(self)
}
graph_edit_get_right_disconnects :: proc "contextless" (self: Graph_Edit) -> Bool {
    return graph_edit_is_right_disconnects_enabled(self)
}
graph_edit_get_connection_lines_antialiased :: proc "contextless" (self: Graph_Edit) -> Bool {
    return graph_edit_is_connection_lines_antialiased(self)
}
graph_edit_get_connections :: proc "contextless" (self: Graph_Edit) -> Typed_Array(Dictionary) {
    return graph_edit_get_connection_list(self)
}
graph_edit_get_minimap_enabled :: proc "contextless" (self: Graph_Edit) -> Bool {
    return graph_edit_is_minimap_enabled(self)
}
graph_edit_get_show_menu :: proc "contextless" (self: Graph_Edit) -> Bool {
    return graph_edit_is_showing_menu(self)
}
graph_edit_get_show_zoom_label :: proc "contextless" (self: Graph_Edit) -> Bool {
    return graph_edit_is_showing_zoom_label(self)
}
graph_edit_get_show_zoom_buttons :: proc "contextless" (self: Graph_Edit) -> Bool {
    return graph_edit_is_showing_zoom_buttons(self)
}
graph_edit_get_show_grid_buttons :: proc "contextless" (self: Graph_Edit) -> Bool {
    return graph_edit_is_showing_grid_buttons(self)
}
graph_edit_get_show_minimap_button :: proc "contextless" (self: Graph_Edit) -> Bool {
    return graph_edit_is_showing_minimap_button(self)
}
graph_edit_get_show_arrange_button :: proc "contextless" (self: Graph_Edit) -> Bool {
    return graph_edit_is_showing_arrange_button(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
graph_edit_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GraphEdit", true)
}

@(private = "file")
__class_name: String_Name