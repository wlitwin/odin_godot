package godot

import __bindgen_gde "godot:gdext"

Mesh_Convex_Decomposition_Settings_Constants :: enum {
}
Mesh_Convex_Decomposition_Settings_Mode :: enum int {
    Convex_Decomposition_Mode_Voxel = 0,
    Convex_Decomposition_Mode_Tetrahedron = 1,
}



mesh_convex_decomposition_settings_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

mesh_convex_decomposition_settings_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_mesh_convex_decomposition_settings :: proc "contextless" () -> Mesh_Convex_Decomposition_Settings {
    return cast(Mesh_Convex_Decomposition_Settings)__bindgen_gde.classdb_construct_object(mesh_convex_decomposition_settings_name_ref())
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

mesh_convex_decomposition_settings_set_max_concavity :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
    max_concavity_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_concavity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    max_concavity_ := max_concavity_
    args := []__bindgen_gde.TypePtr {
        &max_concavity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_convex_decomposition_settings_get_max_concavity :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_concavity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_convex_decomposition_settings_set_symmetry_planes_clipping_bias :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
    symmetry_planes_clipping_bias_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_symmetry_planes_clipping_bias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    symmetry_planes_clipping_bias_ := symmetry_planes_clipping_bias_
    args := []__bindgen_gde.TypePtr {
        &symmetry_planes_clipping_bias_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_convex_decomposition_settings_get_symmetry_planes_clipping_bias :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_symmetry_planes_clipping_bias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_convex_decomposition_settings_set_revolution_axes_clipping_bias :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
    revolution_axes_clipping_bias_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_revolution_axes_clipping_bias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    revolution_axes_clipping_bias_ := revolution_axes_clipping_bias_
    args := []__bindgen_gde.TypePtr {
        &revolution_axes_clipping_bias_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_convex_decomposition_settings_get_revolution_axes_clipping_bias :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_revolution_axes_clipping_bias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_convex_decomposition_settings_set_min_volume_per_convex_hull :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
    min_volume_per_convex_hull_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_min_volume_per_convex_hull", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    min_volume_per_convex_hull_ := min_volume_per_convex_hull_
    args := []__bindgen_gde.TypePtr {
        &min_volume_per_convex_hull_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_convex_decomposition_settings_get_min_volume_per_convex_hull :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_min_volume_per_convex_hull", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_convex_decomposition_settings_set_resolution :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
    min_volume_per_convex_hull_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_resolution", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    min_volume_per_convex_hull_ := min_volume_per_convex_hull_
    args := []__bindgen_gde.TypePtr {
        &min_volume_per_convex_hull_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_convex_decomposition_settings_get_resolution :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_resolution", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_convex_decomposition_settings_set_max_num_vertices_per_convex_hull :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
    max_num_vertices_per_convex_hull_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_num_vertices_per_convex_hull", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    max_num_vertices_per_convex_hull_ := max_num_vertices_per_convex_hull_
    args := []__bindgen_gde.TypePtr {
        &max_num_vertices_per_convex_hull_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_convex_decomposition_settings_get_max_num_vertices_per_convex_hull :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_num_vertices_per_convex_hull", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_convex_decomposition_settings_set_plane_downsampling :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
    plane_downsampling_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_plane_downsampling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    plane_downsampling_ := plane_downsampling_
    args := []__bindgen_gde.TypePtr {
        &plane_downsampling_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_convex_decomposition_settings_get_plane_downsampling :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_plane_downsampling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_convex_decomposition_settings_set_convex_hull_downsampling :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
    convex_hull_downsampling_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_convex_hull_downsampling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    convex_hull_downsampling_ := convex_hull_downsampling_
    args := []__bindgen_gde.TypePtr {
        &convex_hull_downsampling_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_convex_decomposition_settings_get_convex_hull_downsampling :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_convex_hull_downsampling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_convex_decomposition_settings_set_normalize_mesh :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
    normalize_mesh_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_normalize_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    normalize_mesh_ := normalize_mesh_
    args := []__bindgen_gde.TypePtr {
        &normalize_mesh_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_convex_decomposition_settings_get_normalize_mesh :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_normalize_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_convex_decomposition_settings_set_mode :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
    mode_: Mesh_Convex_Decomposition_Settings_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1668072869)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_convex_decomposition_settings_get_mode :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
) -> (ret: Mesh_Convex_Decomposition_Settings_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 23479454)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_convex_decomposition_settings_set_convex_hull_approximation :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
    convex_hull_approximation_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_convex_hull_approximation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    convex_hull_approximation_ := convex_hull_approximation_
    args := []__bindgen_gde.TypePtr {
        &convex_hull_approximation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_convex_decomposition_settings_get_convex_hull_approximation :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_convex_hull_approximation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_convex_decomposition_settings_set_max_convex_hulls :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
    max_convex_hulls_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_convex_hulls", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    max_convex_hulls_ := max_convex_hulls_
    args := []__bindgen_gde.TypePtr {
        &max_convex_hulls_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_convex_decomposition_settings_get_max_convex_hulls :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_convex_hulls", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_convex_decomposition_settings_set_project_hull_vertices :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
    project_hull_vertices_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_project_hull_vertices", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    project_hull_vertices_ := project_hull_vertices_
    args := []__bindgen_gde.TypePtr {
        &project_hull_vertices_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_convex_decomposition_settings_get_project_hull_vertices :: proc "contextless" (
    self: Mesh_Convex_Decomposition_Settings,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_project_hull_vertices", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
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
mesh_convex_decomposition_settings_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("MeshConvexDecompositionSettings", true)
}

@(private = "file")
__class_name: String_Name