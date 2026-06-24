package godot

import __bindgen_gde "godot:gdext"

Visual_Shader_Constants :: enum {
    NODE_ID_INVALID = -1,
    NODE_ID_OUTPUT = 0,
}
Visual_Shader_Type :: enum int {
    Type_Vertex = 0,
    Type_Fragment = 1,
    Type_Light = 2,
    Type_Start = 3,
    Type_Process = 4,
    Type_Collide = 5,
    Type_Start_Custom = 6,
    Type_Process_Custom = 7,
    Type_Sky = 8,
    Type_Fog = 9,
    Type_Max = 10,
}
Visual_Shader_Varying_Mode :: enum int {
    Varying_Mode_Vertex_To_Frag_Light = 0,
    Varying_Mode_Frag_To_Light = 1,
    Varying_Mode_Max = 2,
}
Visual_Shader_Varying_Type :: enum int {
    Varying_Type_Float = 0,
    Varying_Type_Int = 1,
    Varying_Type_Uint = 2,
    Varying_Type_Vector_2d = 3,
    Varying_Type_Vector_3d = 4,
    Varying_Type_Vector_4d = 5,
    Varying_Type_Boolean = 6,
    Varying_Type_Transform = 7,
    Varying_Type_Max = 8,
}



visual_shader_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

visual_shader_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_visual_shader :: proc "contextless" () -> Visual_Shader {
    return cast(Visual_Shader)__bindgen_gde.classdb_construct_object(visual_shader_name_ref())
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

visual_shader_set_mode :: proc "contextless" (
    self: Visual_Shader,
    mode_: Shader_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3978014962)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_add_node :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
    node_: Visual_Shader_Node,
    position_: Vector2,
    id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1560769431)
    }
    self := self
    type_ := type_
    node_ := node_
    position_ := position_
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &node_,
        &position_,
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_get_node :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
    id_: Int,
) -> (ret: Visual_Shader_Node) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3784670312)
    }
    self := self
    type_ := type_
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_set_node_position :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
    id_: Int,
    position_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_node_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726660721)
    }
    self := self
    type_ := type_
    id_ := id_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &id_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_get_node_position :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
    id_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2175036082)
    }
    self := self
    type_ := type_
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_get_node_list :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2370592410)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_get_valid_node_id :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_valid_node_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 629467342)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_remove_node :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
    id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844050912)
    }
    self := self
    type_ := type_
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_replace_node :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
    id_: Int,
    new_class_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("replace_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3144735253)
    }
    self := self
    type_ := type_
    id_ := id_
    new_class_ := new_class_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &id_,
        &new_class_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_is_node_connection :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
    from_node_: Int,
    from_port_: Int,
    to_node_: Int,
    to_port_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_node_connection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3922381898)
    }
    self := self
    type_ := type_
    from_node_ := from_node_
    from_port_ := from_port_
    to_node_ := to_node_
    to_port_ := to_port_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &from_node_,
        &from_port_,
        &to_node_,
        &to_port_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_can_connect_nodes :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
    from_node_: Int,
    from_port_: Int,
    to_node_: Int,
    to_port_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("can_connect_nodes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3922381898)
    }
    self := self
    type_ := type_
    from_node_ := from_node_
    from_port_ := from_port_
    to_node_ := to_node_
    to_port_ := to_port_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &from_node_,
        &from_port_,
        &to_node_,
        &to_port_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_connect_nodes :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
    from_node_: Int,
    from_port_: Int,
    to_node_: Int,
    to_port_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("connect_nodes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3081049573)
    }
    self := self
    type_ := type_
    from_node_ := from_node_
    from_port_ := from_port_
    to_node_ := to_node_
    to_port_ := to_port_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &from_node_,
        &from_port_,
        &to_node_,
        &to_port_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_disconnect_nodes :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
    from_node_: Int,
    from_port_: Int,
    to_node_: Int,
    to_port_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("disconnect_nodes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2268060358)
    }
    self := self
    type_ := type_
    from_node_ := from_node_
    from_port_ := from_port_
    to_node_ := to_node_
    to_port_ := to_port_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &from_node_,
        &from_port_,
        &to_node_,
        &to_port_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_connect_nodes_forced :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
    from_node_: Int,
    from_port_: Int,
    to_node_: Int,
    to_port_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("connect_nodes_forced", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2268060358)
    }
    self := self
    type_ := type_
    from_node_ := from_node_
    from_port_ := from_port_
    to_node_ := to_node_
    to_port_ := to_port_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &from_node_,
        &from_port_,
        &to_node_,
        &to_port_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_get_node_connections :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node_connections", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1441964831)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_attach_node_to_frame :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
    id_: Int,
    frame_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("attach_node_to_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2479945279)
    }
    self := self
    type_ := type_
    id_ := id_
    frame_ := frame_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &id_,
        &frame_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_detach_node_from_frame :: proc "contextless" (
    self: Visual_Shader,
    type_: Visual_Shader_Type,
    id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("detach_node_from_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844050912)
    }
    self := self
    type_ := type_
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_add_varying :: proc "contextless" (
    self: Visual_Shader,
    name_: String,
    mode_: Visual_Shader_Varying_Mode,
    type_: Visual_Shader_Varying_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_varying", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2084110726)
    }
    self := self
    name_ := name_
    mode_ := mode_
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &mode_,
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_remove_varying :: proc "contextless" (
    self: Visual_Shader,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_varying", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_has_varying :: proc "contextless" (
    self: Visual_Shader,
    name_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_varying", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_set_graph_offset :: proc "contextless" (
    self: Visual_Shader,
    offset_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_graph_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_get_graph_offset :: proc "contextless" (
    self: Visual_Shader,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_graph_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
visual_shader_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("VisualShader", true)
}

@(private = "file")
__class_name: String_Name