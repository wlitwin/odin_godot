package godot

import __bindgen_gde "godot:gdext"

Immediate_Mesh_Constants :: enum {
}



immediate_mesh_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

immediate_mesh_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_immediate_mesh :: proc "contextless" () -> Immediate_Mesh {
    return cast(Immediate_Mesh)__bindgen_gde.classdb_construct_object(immediate_mesh_name_ref())
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

immediate_mesh_surface_begin :: proc "contextless" (
    self: Immediate_Mesh,
    primitive_: Mesh_Primitive_Type,
    material_: Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_begin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2794442543)
    }
    self := self
    primitive_ := primitive_
    material_ := material_
    args := []__bindgen_gde.TypePtr {
        &primitive_,
        &material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

immediate_mesh_surface_set_color :: proc "contextless" (
    self: Immediate_Mesh,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_set_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

immediate_mesh_surface_set_normal :: proc "contextless" (
    self: Immediate_Mesh,
    normal_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_set_normal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    normal_ := normal_
    args := []__bindgen_gde.TypePtr {
        &normal_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

immediate_mesh_surface_set_tangent :: proc "contextless" (
    self: Immediate_Mesh,
    tangent_: Plane,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_set_tangent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3505987427)
    }
    self := self
    tangent_ := tangent_
    args := []__bindgen_gde.TypePtr {
        &tangent_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

immediate_mesh_surface_set_uv :: proc "contextless" (
    self: Immediate_Mesh,
    uv_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_set_uv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    uv_ := uv_
    args := []__bindgen_gde.TypePtr {
        &uv_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

immediate_mesh_surface_set_uv2 :: proc "contextless" (
    self: Immediate_Mesh,
    uv2_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_set_uv2", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    uv2_ := uv2_
    args := []__bindgen_gde.TypePtr {
        &uv2_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

immediate_mesh_surface_add_vertex :: proc "contextless" (
    self: Immediate_Mesh,
    vertex_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_add_vertex", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    vertex_ := vertex_
    args := []__bindgen_gde.TypePtr {
        &vertex_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

immediate_mesh_surface_add_vertex_2d :: proc "contextless" (
    self: Immediate_Mesh,
    vertex_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_add_vertex_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    vertex_ := vertex_
    args := []__bindgen_gde.TypePtr {
        &vertex_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

immediate_mesh_surface_end :: proc "contextless" (
    self: Immediate_Mesh,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("surface_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

immediate_mesh_clear_surfaces :: proc "contextless" (
    self: Immediate_Mesh,
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


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
immediate_mesh_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ImmediateMesh", true)
}

@(private = "file")
__class_name: String_Name