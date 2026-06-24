package godot

import __bindgen_gde "godot:gdext"

Surface_Tool_Constants :: enum {
}
Surface_Tool_Custom_Format :: enum int {
    Custom_Rgba8_Unorm = 0,
    Custom_Rgba8_Snorm = 1,
    Custom_Rg_Half = 2,
    Custom_Rgba_Half = 3,
    Custom_R_Float = 4,
    Custom_Rg_Float = 5,
    Custom_Rgb_Float = 6,
    Custom_Rgba_Float = 7,
    Custom_Max = 8,
}
Surface_Tool_Skin_Weight_Count :: enum int {
    Skin_4_Weights = 0,
    Skin_8_Weights = 1,
}



surface_tool_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

surface_tool_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_surface_tool :: proc "contextless" () -> Surface_Tool {
    return cast(Surface_Tool)__bindgen_gde.classdb_construct_object(surface_tool_name_ref())
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

surface_tool_set_skin_weight_count :: proc "contextless" (
    self: Surface_Tool,
    count_: Surface_Tool_Skin_Weight_Count,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_skin_weight_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 618679515)
    }
    self := self
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_get_skin_weight_count :: proc "contextless" (
    self: Surface_Tool,
) -> (ret: Surface_Tool_Skin_Weight_Count) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skin_weight_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1072401130)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

surface_tool_set_custom_format :: proc "contextless" (
    self: Surface_Tool,
    channel_index_: Int,
    format_: Surface_Tool_Custom_Format,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4087759856)
    }
    self := self
    channel_index_ := channel_index_
    format_ := format_
    args := []__bindgen_gde.TypePtr {
        &channel_index_,
        &format_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_get_custom_format :: proc "contextless" (
    self: Surface_Tool,
    channel_index_: Int,
) -> (ret: Surface_Tool_Custom_Format) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 839863283)
    }
    self := self
    channel_index_ := channel_index_
    args := []__bindgen_gde.TypePtr {
        &channel_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

surface_tool_begin :: proc "contextless" (
    self: Surface_Tool,
    primitive_: Mesh_Primitive_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("begin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2230304113)
    }
    self := self
    primitive_ := primitive_
    args := []__bindgen_gde.TypePtr {
        &primitive_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_add_vertex :: proc "contextless" (
    self: Surface_Tool,
    vertex_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_vertex", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    vertex_ := vertex_
    args := []__bindgen_gde.TypePtr {
        &vertex_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_set_color :: proc "contextless" (
    self: Surface_Tool,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_set_normal :: proc "contextless" (
    self: Surface_Tool,
    normal_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_normal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    normal_ := normal_
    args := []__bindgen_gde.TypePtr {
        &normal_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_set_tangent :: proc "contextless" (
    self: Surface_Tool,
    tangent_: Plane,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tangent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3505987427)
    }
    self := self
    tangent_ := tangent_
    args := []__bindgen_gde.TypePtr {
        &tangent_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_set_uv :: proc "contextless" (
    self: Surface_Tool,
    uv_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_uv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    uv_ := uv_
    args := []__bindgen_gde.TypePtr {
        &uv_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_set_uv2 :: proc "contextless" (
    self: Surface_Tool,
    uv2_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_uv2", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    uv2_ := uv2_
    args := []__bindgen_gde.TypePtr {
        &uv2_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_set_bones :: proc "contextless" (
    self: Surface_Tool,
    bones_: Packed_Int32_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bones", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3614634198)
    }
    self := self
    bones_ := bones_
    args := []__bindgen_gde.TypePtr {
        &bones_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_set_weights :: proc "contextless" (
    self: Surface_Tool,
    weights_: Packed_Float32_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_weights", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2899603908)
    }
    self := self
    weights_ := weights_
    args := []__bindgen_gde.TypePtr {
        &weights_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_set_custom :: proc "contextless" (
    self: Surface_Tool,
    channel_index_: Int,
    custom_color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878471219)
    }
    self := self
    channel_index_ := channel_index_
    custom_color_ := custom_color_
    args := []__bindgen_gde.TypePtr {
        &channel_index_,
        &custom_color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_set_smooth_group :: proc "contextless" (
    self: Surface_Tool,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_smooth_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_add_triangle_fan :: proc "contextless" (
    self: Surface_Tool,
    vertices_: Packed_Vector3_Array,
    uvs_: Packed_Vector2_Array,
    colors_: Packed_Color_Array,
    uv2s_: Packed_Vector2_Array,
    normals_: Packed_Vector3_Array,
    tangents_: Typed_Array(Plane),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_triangle_fan", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2235017613)
    }
    self := self
    vertices_ := vertices_
    uvs_ := uvs_
    colors_ := colors_
    uv2s_ := uv2s_
    normals_ := normals_
    tangents_ := tangents_
    args := []__bindgen_gde.TypePtr {
        &vertices_,
        &uvs_,
        &colors_,
        &uv2s_,
        &normals_,
        &tangents_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_add_index :: proc "contextless" (
    self: Surface_Tool,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_index :: proc "contextless" (
    self: Surface_Tool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_deindex :: proc "contextless" (
    self: Surface_Tool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("deindex", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_generate_normals :: proc "contextless" (
    self: Surface_Tool,
    flip_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generate_normals", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 107499316)
    }
    self := self
    flip_ := flip_
    args := []__bindgen_gde.TypePtr {
        &flip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_generate_tangents :: proc "contextless" (
    self: Surface_Tool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generate_tangents", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_optimize_indices_for_cache :: proc "contextless" (
    self: Surface_Tool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("optimize_indices_for_cache", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_get_aabb :: proc "contextless" (
    self: Surface_Tool,
) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_aabb", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1068685055)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

surface_tool_generate_lod :: proc "contextless" (
    self: Surface_Tool,
    nd_threshold_: f64,
    target_index_count_: Int,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generate_lod", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1938056459)
    }
    self := self
    nd_threshold_ := nd_threshold_
    target_index_count_ := target_index_count_
    args := []__bindgen_gde.TypePtr {
        &nd_threshold_,
        &target_index_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

surface_tool_set_material :: proc "contextless" (
    self: Surface_Tool,
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

surface_tool_get_primitive_type :: proc "contextless" (
    self: Surface_Tool,
) -> (ret: Mesh_Primitive_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_primitive_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 768822145)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

surface_tool_clear :: proc "contextless" (
    self: Surface_Tool,
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

surface_tool_create_from :: proc "contextless" (
    self: Surface_Tool,
    existing_: Mesh,
    surface_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1767024570)
    }
    self := self
    existing_ := existing_
    surface_ := surface_
    args := []__bindgen_gde.TypePtr {
        &existing_,
        &surface_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_create_from_arrays :: proc "contextless" (
    self: Surface_Tool,
    arrays_: Array,
    primitive_type_: Mesh_Primitive_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_from_arrays", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1894639680)
    }
    self := self
    arrays_ := arrays_
    primitive_type_ := primitive_type_
    args := []__bindgen_gde.TypePtr {
        &arrays_,
        &primitive_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_create_from_blend_shape :: proc "contextless" (
    self: Surface_Tool,
    existing_: Mesh,
    surface_: Int,
    blend_shape_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_from_blend_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1306185582)
    }
    self := self
    existing_ := existing_
    surface_ := surface_
    blend_shape_ := blend_shape_
    args := []__bindgen_gde.TypePtr {
        &existing_,
        &surface_,
        &blend_shape_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_append_from :: proc "contextless" (
    self: Surface_Tool,
    existing_: Mesh,
    surface_: Int,
    transform_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2217967155)
    }
    self := self
    existing_ := existing_
    surface_ := surface_
    transform_ := transform_
    args := []__bindgen_gde.TypePtr {
        &existing_,
        &surface_,
        &transform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

surface_tool_commit :: proc "contextless" (
    self: Surface_Tool,
    existing_: Array_Mesh,
    flags_: Int,
) -> (ret: Array_Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("commit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4107864055)
    }
    self := self
    existing_ := existing_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &existing_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

surface_tool_commit_to_arrays :: proc "contextless" (
    self: Surface_Tool,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("commit_to_arrays", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
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
surface_tool_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SurfaceTool", true)
}

@(private = "file")
__class_name: String_Name