package godot

import __bindgen_gde "godot:gdext"

Navigation_Mesh_Source_Geometry_Data3d_Constants :: enum {
}



navigation_mesh_source_geometry_data3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

navigation_mesh_source_geometry_data3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_navigation_mesh_source_geometry_data3d :: proc "contextless" () -> Navigation_Mesh_Source_Geometry_Data3d {
    return cast(Navigation_Mesh_Source_Geometry_Data3d)__bindgen_gde.classdb_construct_object(navigation_mesh_source_geometry_data3d_name_ref())
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

navigation_mesh_source_geometry_data3d_set_vertices :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
    vertices_: Packed_Float32_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertices", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2899603908)
    }
    self := self
    vertices_ := vertices_
    args := []__bindgen_gde.TypePtr {
        &vertices_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data3d_get_vertices :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
) -> (ret: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertices", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 675695659)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_mesh_source_geometry_data3d_set_indices :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
    indices_: Packed_Int32_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_indices", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3614634198)
    }
    self := self
    indices_ := indices_
    args := []__bindgen_gde.TypePtr {
        &indices_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data3d_get_indices :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_indices", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1930428628)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_mesh_source_geometry_data3d_append_arrays :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
    vertices_: Packed_Float32_Array,
    indices_: Packed_Int32_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_arrays", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3117535015)
    }
    self := self
    vertices_ := vertices_
    indices_ := indices_
    args := []__bindgen_gde.TypePtr {
        &vertices_,
        &indices_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data3d_clear :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
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

navigation_mesh_source_geometry_data3d_has_data :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_mesh_source_geometry_data3d_add_mesh :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
    mesh_: Mesh,
    xform_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 975462459)
    }
    self := self
    mesh_ := mesh_
    xform_ := xform_
    args := []__bindgen_gde.TypePtr {
        &mesh_,
        &xform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data3d_add_mesh_array :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
    mesh_array_: Array,
    xform_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_mesh_array", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4235710913)
    }
    self := self
    mesh_array_ := mesh_array_
    xform_ := xform_
    args := []__bindgen_gde.TypePtr {
        &mesh_array_,
        &xform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data3d_add_faces :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
    faces_: Packed_Vector3_Array,
    xform_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_faces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1440358797)
    }
    self := self
    faces_ := faces_
    xform_ := xform_
    args := []__bindgen_gde.TypePtr {
        &faces_,
        &xform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data3d_merge :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
    other_geometry_: Navigation_Mesh_Source_Geometry_Data3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("merge", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 655828145)
    }
    self := self
    other_geometry_ := other_geometry_
    args := []__bindgen_gde.TypePtr {
        &other_geometry_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data3d_add_projected_obstruction :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
    vertices_: Packed_Vector3_Array,
    elevation_: f64,
    height_: f64,
    carve_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_projected_obstruction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3351846707)
    }
    self := self
    vertices_ := vertices_
    elevation_ := elevation_
    height_ := height_
    carve_ := carve_
    args := []__bindgen_gde.TypePtr {
        &vertices_,
        &elevation_,
        &height_,
        &carve_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data3d_clear_projected_obstructions :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_projected_obstructions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data3d_set_projected_obstructions :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
    projected_obstructions_: Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_projected_obstructions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    projected_obstructions_ := projected_obstructions_
    args := []__bindgen_gde.TypePtr {
        &projected_obstructions_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data3d_get_projected_obstructions :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_projected_obstructions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_mesh_source_geometry_data3d_get_bounds :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data3d,
) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bounds", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1021181044)
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
navigation_mesh_source_geometry_data3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("NavigationMeshSourceGeometryData3D", true)
}

@(private = "file")
__class_name: String_Name