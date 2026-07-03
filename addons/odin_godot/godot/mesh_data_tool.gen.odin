package godot

import __bindgen_gde "godot:gdext"

Mesh_Data_Tool_Constants :: enum {
}



mesh_data_tool_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

mesh_data_tool_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_mesh_data_tool :: proc "contextless" () -> Mesh_Data_Tool {
    return cast(Mesh_Data_Tool)__bindgen_gde.classdb_construct_object(mesh_data_tool_name_ref())
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

mesh_data_tool_clear :: proc "contextless" (
    self: Mesh_Data_Tool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_data_tool_create_from_surface :: proc "contextless" (
    self: Mesh_Data_Tool,
    mesh_: Array_Mesh,
    surface_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_from_surface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2727020678)
    }
    self := self
    mesh_ := mesh_
    surface_ := surface_
    args := []__bindgen_gde.TypePtr {
        &mesh_,
        &surface_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_commit_to_surface :: proc "contextless" (
    self: Mesh_Data_Tool,
    mesh_: Array_Mesh,
    compression_flags_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("commit_to_surface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2021686445)
    }
    self := self
    mesh_ := mesh_
    compression_flags_ := compression_flags_
    args := []__bindgen_gde.TypePtr {
        &mesh_,
        &compression_flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_get_format :: proc "contextless" (
    self: Mesh_Data_Tool,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_get_vertex_count :: proc "contextless" (
    self: Mesh_Data_Tool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertex_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_get_edge_count :: proc "contextless" (
    self: Mesh_Data_Tool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_edge_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_get_face_count :: proc "contextless" (
    self: Mesh_Data_Tool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_face_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_set_vertex :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    vertex_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertex", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1530502735)
    }
    self := self
    idx_ := idx_
    vertex_ := vertex_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &vertex_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_data_tool_get_vertex :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertex", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 711720468)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_set_vertex_normal :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    normal_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertex_normal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1530502735)
    }
    self := self
    idx_ := idx_
    normal_ := normal_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &normal_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_data_tool_get_vertex_normal :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertex_normal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 711720468)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_set_vertex_tangent :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    tangent_: Plane,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertex_tangent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1104099133)
    }
    self := self
    idx_ := idx_
    tangent_ := tangent_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &tangent_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_data_tool_get_vertex_tangent :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Plane) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertex_tangent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1372055458)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_set_vertex_uv :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    uv_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertex_uv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 163021252)
    }
    self := self
    idx_ := idx_
    uv_ := uv_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &uv_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_data_tool_get_vertex_uv :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertex_uv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2299179447)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_set_vertex_uv2 :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    uv2_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertex_uv2", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 163021252)
    }
    self := self
    idx_ := idx_
    uv2_ := uv2_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &uv2_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_data_tool_get_vertex_uv2 :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertex_uv2", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2299179447)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_set_vertex_color :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertex_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878471219)
    }
    self := self
    idx_ := idx_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_data_tool_get_vertex_color :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertex_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3457211756)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_set_vertex_bones :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    bones_: Packed_Int32_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertex_bones", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3500328261)
    }
    self := self
    idx_ := idx_
    bones_ := bones_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &bones_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_data_tool_get_vertex_bones :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertex_bones", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1706082319)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_set_vertex_weights :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    weights_: Packed_Float32_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertex_weights", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1345852415)
    }
    self := self
    idx_ := idx_
    weights_ := weights_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &weights_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_data_tool_get_vertex_weights :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertex_weights", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1542882410)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_set_vertex_meta :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    meta_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertex_meta", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2152698145)
    }
    self := self
    idx_ := idx_
    meta_ := meta_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &meta_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_data_tool_get_vertex_meta :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertex_meta", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4227898402)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_get_vertex_edges :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertex_edges", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1706082319)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_get_vertex_faces :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertex_faces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1706082319)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_get_edge_vertex :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    vertex_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_edge_vertex", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175239445)
    }
    self := self
    idx_ := idx_
    vertex_ := vertex_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &vertex_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_get_edge_faces :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_edge_faces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1706082319)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_set_edge_meta :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    meta_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_edge_meta", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2152698145)
    }
    self := self
    idx_ := idx_
    meta_ := meta_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &meta_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_data_tool_get_edge_meta :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_edge_meta", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4227898402)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_get_face_vertex :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    vertex_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_face_vertex", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175239445)
    }
    self := self
    idx_ := idx_
    vertex_ := vertex_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &vertex_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_get_face_edge :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    edge_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_face_edge", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175239445)
    }
    self := self
    idx_ := idx_
    edge_ := edge_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &edge_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_set_face_meta :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
    meta_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_face_meta", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2152698145)
    }
    self := self
    idx_ := idx_
    meta_ := meta_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &meta_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_data_tool_get_face_meta :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_face_meta", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4227898402)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_get_face_normal :: proc "contextless" (
    self: Mesh_Data_Tool,
    idx_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_face_normal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 711720468)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_data_tool_set_material :: proc "contextless" (
    self: Mesh_Data_Tool,
    material_: Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2757459619)
    }
    self := self
    material_ := material_
    args := []__bindgen_gde.TypePtr {
        &material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_data_tool_get_material :: proc "contextless" (
    self: Mesh_Data_Tool,
) -> (ret: Material) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 5934680)
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
mesh_data_tool_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("MeshDataTool", true)
}

@(private = "file")
__class_name: String_Name