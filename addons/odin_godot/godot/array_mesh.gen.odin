package godot

import __bindgen_gde "godot:gdext"

Array_Mesh_Constants :: enum {
}



array_mesh_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

array_mesh_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_array_mesh :: proc "contextless" () -> Array_Mesh {
    return cast(Array_Mesh)__bindgen_gde.classdb_construct_object(array_mesh_name_ref())
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

array_mesh_add_blend_shape :: proc "contextless" (
    self: Array_Mesh,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_blend_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_get_blend_shape_count :: proc "contextless" (
    self: Array_Mesh,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_blend_shape_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

array_mesh_get_blend_shape_name :: proc "contextless" (
    self: Array_Mesh,
    index_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_blend_shape_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 659327637)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

array_mesh_set_blend_shape_name :: proc "contextless" (
    self: Array_Mesh,
    index_: Int,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_blend_shape_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3780747571)
    }
    self := self
    index_ := index_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_clear_blend_shapes :: proc "contextless" (
    self: Array_Mesh,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_blend_shapes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_set_blend_shape_mode :: proc "contextless" (
    self: Array_Mesh,
    mode_: Mesh_Blend_Shape_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_blend_shape_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 227983991)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_get_blend_shape_mode :: proc "contextless" (
    self: Array_Mesh,
) -> (ret: Mesh_Blend_Shape_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_blend_shape_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 836485024)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

array_mesh_add_surface_from_arrays :: proc "contextless" (
    self: Array_Mesh,
    primitive_: Mesh_Primitive_Type,
    arrays_: Array,
    blend_shapes_: Typed_Array(Array),
    lods_: Dictionary,
    flags_: Mesh_Array_Format,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_surface_from_arrays", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1796411378)
    }
    self := self
    primitive_ := primitive_
    arrays_ := arrays_
    blend_shapes_ := blend_shapes_
    lods_ := lods_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &primitive_,
        &arrays_,
        &blend_shapes_,
        &lods_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_clear_surfaces :: proc "contextless" (
    self: Array_Mesh,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_surfaces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_surface_remove :: proc "contextless" (
    self: Array_Mesh,
    surf_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_remove", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    surf_idx_ := surf_idx_
    args := []__bindgen_gde.TypePtr {
        &surf_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_surface_update_vertex_region :: proc "contextless" (
    self: Array_Mesh,
    surf_idx_: Int,
    offset_: Int,
    data_: Packed_Byte_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_update_vertex_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3837166854)
    }
    self := self
    surf_idx_ := surf_idx_
    offset_ := offset_
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &surf_idx_,
        &offset_,
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_surface_update_attribute_region :: proc "contextless" (
    self: Array_Mesh,
    surf_idx_: Int,
    offset_: Int,
    data_: Packed_Byte_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_update_attribute_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3837166854)
    }
    self := self
    surf_idx_ := surf_idx_
    offset_ := offset_
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &surf_idx_,
        &offset_,
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_surface_update_skin_region :: proc "contextless" (
    self: Array_Mesh,
    surf_idx_: Int,
    offset_: Int,
    data_: Packed_Byte_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_update_skin_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3837166854)
    }
    self := self
    surf_idx_ := surf_idx_
    offset_ := offset_
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &surf_idx_,
        &offset_,
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_surface_get_array_len :: proc "contextless" (
    self: Array_Mesh,
    surf_idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_get_array_len", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    surf_idx_ := surf_idx_
    args := []__bindgen_gde.TypePtr {
        &surf_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

array_mesh_surface_get_array_index_len :: proc "contextless" (
    self: Array_Mesh,
    surf_idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_get_array_index_len", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    surf_idx_ := surf_idx_
    args := []__bindgen_gde.TypePtr {
        &surf_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

array_mesh_surface_get_format :: proc "contextless" (
    self: Array_Mesh,
    surf_idx_: Int,
) -> (ret: Mesh_Array_Format) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_get_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3718287884)
    }
    self := self
    surf_idx_ := surf_idx_
    args := []__bindgen_gde.TypePtr {
        &surf_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

array_mesh_surface_get_primitive_type :: proc "contextless" (
    self: Array_Mesh,
    surf_idx_: Int,
) -> (ret: Mesh_Primitive_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_get_primitive_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4141943888)
    }
    self := self
    surf_idx_ := surf_idx_
    args := []__bindgen_gde.TypePtr {
        &surf_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

array_mesh_surface_find_by_name :: proc "contextless" (
    self: Array_Mesh,
    name_: String,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_find_by_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1321353865)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

array_mesh_surface_set_name :: proc "contextless" (
    self: Array_Mesh,
    surf_idx_: Int,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_set_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    surf_idx_ := surf_idx_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &surf_idx_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_surface_get_name :: proc "contextless" (
    self: Array_Mesh,
    surf_idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_get_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    surf_idx_ := surf_idx_
    args := []__bindgen_gde.TypePtr {
        &surf_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

array_mesh_regen_normal_maps :: proc "contextless" (
    self: Array_Mesh,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("regen_normal_maps", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_lightmap_unwrap :: proc "contextless" (
    self: Array_Mesh,
    transform_: Transform3d,
    texel_size_: f64,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("lightmap_unwrap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1476641071)
    }
    self := self
    transform_ := transform_
    texel_size_ := texel_size_
    args := []__bindgen_gde.TypePtr {
        &transform_,
        &texel_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

array_mesh_set_custom_aabb :: proc "contextless" (
    self: Array_Mesh,
    aabb_: Aabb,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_aabb", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 259215842)
    }
    self := self
    aabb_ := aabb_
    args := []__bindgen_gde.TypePtr {
        &aabb_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_get_custom_aabb :: proc "contextless" (
    self: Array_Mesh,
) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_aabb", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1068685055)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

array_mesh_set_shadow_mesh :: proc "contextless" (
    self: Array_Mesh,
    mesh_: Array_Mesh,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadow_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3377897901)
    }
    self := self
    mesh_ := mesh_
    args := []__bindgen_gde.TypePtr {
        &mesh_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

array_mesh_get_shadow_mesh :: proc "contextless" (
    self: Array_Mesh,
) -> (ret: Array_Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shadow_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3206942465)
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
array_mesh_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ArrayMesh", true)
}

@(private = "file")
__class_name: String_Name