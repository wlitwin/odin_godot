package godot

import __bindgen_gde "godot:gdext"

Importer_Mesh_Constants :: enum {
}



importer_mesh_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

importer_mesh_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_importer_mesh :: proc "contextless" () -> Importer_Mesh {
    return cast(Importer_Mesh)__bindgen_gde.classdb_construct_object(importer_mesh_name_ref())
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
importer_mesh_merge_importer_meshes :: proc "contextless" (
    importer_meshes_: Typed_Array(Importer_Mesh),
    relative_transforms_: Typed_Array(Transform3d),
    deduplicate_surfaces_: Bool,
) -> (ret: Importer_Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("merge_importer_meshes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1030647649)
    }
    importer_meshes_ := importer_meshes_
    relative_transforms_ := relative_transforms_
    deduplicate_surfaces_ := deduplicate_surfaces_
    args := []__bindgen_gde.TypePtr {
        &importer_meshes_,
        &relative_transforms_,
        &deduplicate_surfaces_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}

importer_mesh_from_mesh :: proc "contextless" (
    mesh_: Mesh,
) -> (ret: Importer_Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("from_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 283226343)
    }
    mesh_ := mesh_
    args := []__bindgen_gde.TypePtr {
        &mesh_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}


importer_mesh_add_blend_shape :: proc "contextless" (
    self: Importer_Mesh,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_blend_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_get_blend_shape_count :: proc "contextless" (
    self: Importer_Mesh,
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

importer_mesh_get_blend_shape_name :: proc "contextless" (
    self: Importer_Mesh,
    blend_shape_idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_blend_shape_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    blend_shape_idx_ := blend_shape_idx_
    args := []__bindgen_gde.TypePtr {
        &blend_shape_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_set_blend_shape_mode :: proc "contextless" (
    self: Importer_Mesh,
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

importer_mesh_get_blend_shape_mode :: proc "contextless" (
    self: Importer_Mesh,
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

importer_mesh_add_surface :: proc "contextless" (
    self: Importer_Mesh,
    primitive_: Mesh_Primitive_Type,
    arrays_: Array,
    blend_shapes_: Typed_Array(Array),
    lods_: Dictionary,
    material_: Material,
    name_: String,
    flags_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_surface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740448849)
    }
    self := self
    primitive_ := primitive_
    arrays_ := arrays_
    blend_shapes_ := blend_shapes_
    lods_ := lods_
    material_ := material_
    name_ := name_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &primitive_,
        &arrays_,
        &blend_shapes_,
        &lods_,
        &material_,
        &name_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_get_surface_count :: proc "contextless" (
    self: Importer_Mesh,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surface_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_get_surface_primitive_type :: proc "contextless" (
    self: Importer_Mesh,
    surface_idx_: Int,
) -> (ret: Mesh_Primitive_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surface_primitive_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3552571330)
    }
    self := self
    surface_idx_ := surface_idx_
    args := []__bindgen_gde.TypePtr {
        &surface_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_get_surface_name :: proc "contextless" (
    self: Importer_Mesh,
    surface_idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surface_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    surface_idx_ := surface_idx_
    args := []__bindgen_gde.TypePtr {
        &surface_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_get_surface_arrays :: proc "contextless" (
    self: Importer_Mesh,
    surface_idx_: Int,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surface_arrays", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 663333327)
    }
    self := self
    surface_idx_ := surface_idx_
    args := []__bindgen_gde.TypePtr {
        &surface_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_get_surface_blend_shape_arrays :: proc "contextless" (
    self: Importer_Mesh,
    surface_idx_: Int,
    blend_shape_idx_: Int,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surface_blend_shape_arrays", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2345056839)
    }
    self := self
    surface_idx_ := surface_idx_
    blend_shape_idx_ := blend_shape_idx_
    args := []__bindgen_gde.TypePtr {
        &surface_idx_,
        &blend_shape_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_get_surface_lod_count :: proc "contextless" (
    self: Importer_Mesh,
    surface_idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surface_lod_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    surface_idx_ := surface_idx_
    args := []__bindgen_gde.TypePtr {
        &surface_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_get_surface_lod_size :: proc "contextless" (
    self: Importer_Mesh,
    surface_idx_: Int,
    lod_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surface_lod_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    surface_idx_ := surface_idx_
    lod_idx_ := lod_idx_
    args := []__bindgen_gde.TypePtr {
        &surface_idx_,
        &lod_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_get_surface_lod_indices :: proc "contextless" (
    self: Importer_Mesh,
    surface_idx_: Int,
    lod_idx_: Int,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surface_lod_indices", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265128013)
    }
    self := self
    surface_idx_ := surface_idx_
    lod_idx_ := lod_idx_
    args := []__bindgen_gde.TypePtr {
        &surface_idx_,
        &lod_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_get_surface_material :: proc "contextless" (
    self: Importer_Mesh,
    surface_idx_: Int,
) -> (ret: Material) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surface_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2897466400)
    }
    self := self
    surface_idx_ := surface_idx_
    args := []__bindgen_gde.TypePtr {
        &surface_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_get_surface_format :: proc "contextless" (
    self: Importer_Mesh,
    surface_idx_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surface_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    surface_idx_ := surface_idx_
    args := []__bindgen_gde.TypePtr {
        &surface_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_set_surface_name :: proc "contextless" (
    self: Importer_Mesh,
    surface_idx_: Int,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_surface_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    surface_idx_ := surface_idx_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &surface_idx_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_set_surface_material :: proc "contextless" (
    self: Importer_Mesh,
    surface_idx_: Int,
    material_: Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_surface_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3671737478)
    }
    self := self
    surface_idx_ := surface_idx_
    material_ := material_
    args := []__bindgen_gde.TypePtr {
        &surface_idx_,
        &material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_generate_lods :: proc "contextless" (
    self: Importer_Mesh,
    normal_merge_angle_: f64,
    normal_split_angle_: f64,
    bone_transform_array_: Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generate_lods", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2491878677)
    }
    self := self
    normal_merge_angle_ := normal_merge_angle_
    normal_split_angle_ := normal_split_angle_
    bone_transform_array_ := bone_transform_array_
    args := []__bindgen_gde.TypePtr {
        &normal_merge_angle_,
        &normal_split_angle_,
        &bone_transform_array_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_get_mesh :: proc "contextless" (
    self: Importer_Mesh,
    base_mesh_: Array_Mesh,
) -> (ret: Array_Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1457573577)
    }
    self := self
    base_mesh_ := base_mesh_
    args := []__bindgen_gde.TypePtr {
        &base_mesh_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

importer_mesh_clear :: proc "contextless" (
    self: Importer_Mesh,
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

importer_mesh_set_lightmap_size_hint :: proc "contextless" (
    self: Importer_Mesh,
    size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_lightmap_size_hint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

importer_mesh_get_lightmap_size_hint :: proc "contextless" (
    self: Importer_Mesh,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_lightmap_size_hint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
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
importer_mesh_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ImporterMesh", true)
}

@(private = "file")
__class_name: String_Name