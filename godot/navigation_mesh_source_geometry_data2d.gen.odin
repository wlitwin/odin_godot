package godot

import __bindgen_gde "godot:gdext"

Navigation_Mesh_Source_Geometry_Data2d_Constants :: enum {
}



navigation_mesh_source_geometry_data2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

navigation_mesh_source_geometry_data2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_navigation_mesh_source_geometry_data2d :: proc "contextless" () -> Navigation_Mesh_Source_Geometry_Data2d {
    return cast(Navigation_Mesh_Source_Geometry_Data2d)__bindgen_gde.classdb_construct_object(navigation_mesh_source_geometry_data2d_name_ref())
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

navigation_mesh_source_geometry_data2d_clear :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
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

navigation_mesh_source_geometry_data2d_has_data :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
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

navigation_mesh_source_geometry_data2d_set_traversable_outlines :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
    traversable_outlines_: Typed_Array(Packed_Vector2_Array),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_traversable_outlines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    traversable_outlines_ := traversable_outlines_
    args := []__bindgen_gde.TypePtr {
        &traversable_outlines_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data2d_get_traversable_outlines :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
) -> (ret: Typed_Array(Packed_Vector2_Array)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_traversable_outlines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_mesh_source_geometry_data2d_set_obstruction_outlines :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
    obstruction_outlines_: Typed_Array(Packed_Vector2_Array),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_obstruction_outlines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    obstruction_outlines_ := obstruction_outlines_
    args := []__bindgen_gde.TypePtr {
        &obstruction_outlines_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data2d_get_obstruction_outlines :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
) -> (ret: Typed_Array(Packed_Vector2_Array)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_obstruction_outlines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_mesh_source_geometry_data2d_append_traversable_outlines :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
    traversable_outlines_: Typed_Array(Packed_Vector2_Array),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_traversable_outlines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    traversable_outlines_ := traversable_outlines_
    args := []__bindgen_gde.TypePtr {
        &traversable_outlines_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data2d_append_obstruction_outlines :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
    obstruction_outlines_: Typed_Array(Packed_Vector2_Array),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_obstruction_outlines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    obstruction_outlines_ := obstruction_outlines_
    args := []__bindgen_gde.TypePtr {
        &obstruction_outlines_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data2d_add_traversable_outline :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
    shape_outline_: Packed_Vector2_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_traversable_outline", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1509147220)
    }
    self := self
    shape_outline_ := shape_outline_
    args := []__bindgen_gde.TypePtr {
        &shape_outline_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data2d_add_obstruction_outline :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
    shape_outline_: Packed_Vector2_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_obstruction_outline", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1509147220)
    }
    self := self
    shape_outline_ := shape_outline_
    args := []__bindgen_gde.TypePtr {
        &shape_outline_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data2d_merge :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
    other_geometry_: Navigation_Mesh_Source_Geometry_Data2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("merge", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 742424872)
    }
    self := self
    other_geometry_ := other_geometry_
    args := []__bindgen_gde.TypePtr {
        &other_geometry_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data2d_add_projected_obstruction :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
    vertices_: Packed_Vector2_Array,
    carve_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_projected_obstruction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3882407395)
    }
    self := self
    vertices_ := vertices_
    carve_ := carve_
    args := []__bindgen_gde.TypePtr {
        &vertices_,
        &carve_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_mesh_source_geometry_data2d_clear_projected_obstructions :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
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

navigation_mesh_source_geometry_data2d_set_projected_obstructions :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
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

navigation_mesh_source_geometry_data2d_get_projected_obstructions :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
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

navigation_mesh_source_geometry_data2d_get_bounds :: proc "contextless" (
    self: Navigation_Mesh_Source_Geometry_Data2d,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bounds", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3248174)
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
navigation_mesh_source_geometry_data2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("NavigationMeshSourceGeometryData2D", true)
}

@(private = "file")
__class_name: String_Name