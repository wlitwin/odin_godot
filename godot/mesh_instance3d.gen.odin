package godot

import __bindgen_gde "godot:gdext"

Mesh_Instance3d_Constants :: enum {
}



mesh_instance3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

mesh_instance3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_mesh_instance3d :: proc "contextless" () -> Mesh_Instance3d {
    return cast(Mesh_Instance3d)__bindgen_gde.classdb_construct_object(mesh_instance3d_name_ref())
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

mesh_instance3d_set_mesh :: proc "contextless" (
    self: Mesh_Instance3d,
    mesh_: Mesh,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 194775623)
    }
    self := self
    mesh_ := mesh_
    args := []__bindgen_gde.TypePtr {
        &mesh_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_instance3d_get_mesh :: proc "contextless" (
    self: Mesh_Instance3d,
) -> (ret: Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1808005922)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_instance3d_set_skeleton_path :: proc "contextless" (
    self: Mesh_Instance3d,
    skeleton_path_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_skeleton_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1348162250)
    }
    self := self
    skeleton_path_ := skeleton_path_
    args := []__bindgen_gde.TypePtr {
        &skeleton_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_instance3d_get_skeleton_path :: proc "contextless" (
    self: Mesh_Instance3d,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skeleton_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 277076166)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_instance3d_set_skin :: proc "contextless" (
    self: Mesh_Instance3d,
    skin_: Skin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_skin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3971435618)
    }
    self := self
    skin_ := skin_
    args := []__bindgen_gde.TypePtr {
        &skin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_instance3d_get_skin :: proc "contextless" (
    self: Mesh_Instance3d,
) -> (ret: Skin) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2074563878)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_instance3d_get_skin_reference :: proc "contextless" (
    self: Mesh_Instance3d,
) -> (ret: Skin_Reference) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skin_reference", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2060603409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_instance3d_get_surface_override_material_count :: proc "contextless" (
    self: Mesh_Instance3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surface_override_material_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_instance3d_set_surface_override_material :: proc "contextless" (
    self: Mesh_Instance3d,
    surface_: Int,
    material_: Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_surface_override_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3671737478)
    }
    self := self
    surface_ := surface_
    material_ := material_
    args := []__bindgen_gde.TypePtr {
        &surface_,
        &material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_instance3d_get_surface_override_material :: proc "contextless" (
    self: Mesh_Instance3d,
    surface_: Int,
) -> (ret: Material) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surface_override_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2897466400)
    }
    self := self
    surface_ := surface_
    args := []__bindgen_gde.TypePtr {
        &surface_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_instance3d_get_active_material :: proc "contextless" (
    self: Mesh_Instance3d,
    surface_: Int,
) -> (ret: Material) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_active_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2897466400)
    }
    self := self
    surface_ := surface_
    args := []__bindgen_gde.TypePtr {
        &surface_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_instance3d_create_trimesh_collision :: proc "contextless" (
    self: Mesh_Instance3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_trimesh_collision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_instance3d_create_convex_collision :: proc "contextless" (
    self: Mesh_Instance3d,
    clean_: Bool,
    simplify_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_convex_collision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2751962654)
    }
    self := self
    clean_ := clean_
    simplify_ := simplify_
    args := []__bindgen_gde.TypePtr {
        &clean_,
        &simplify_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_instance3d_create_multiple_convex_collisions :: proc "contextless" (
    self: Mesh_Instance3d,
    settings_: Mesh_Convex_Decomposition_Settings,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_multiple_convex_collisions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 628789669)
    }
    self := self
    settings_ := settings_
    args := []__bindgen_gde.TypePtr {
        &settings_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_instance3d_get_blend_shape_count :: proc "contextless" (
    self: Mesh_Instance3d,
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

mesh_instance3d_find_blend_shape_by_name :: proc "contextless" (
    self: Mesh_Instance3d,
    name_: String_Name,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_blend_shape_by_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4150868206)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_instance3d_get_blend_shape_value :: proc "contextless" (
    self: Mesh_Instance3d,
    blend_shape_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_blend_shape_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    blend_shape_idx_ := blend_shape_idx_
    args := []__bindgen_gde.TypePtr {
        &blend_shape_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_instance3d_set_blend_shape_value :: proc "contextless" (
    self: Mesh_Instance3d,
    blend_shape_idx_: Int,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_blend_shape_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    blend_shape_idx_ := blend_shape_idx_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &blend_shape_idx_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_instance3d_create_debug_tangents :: proc "contextless" (
    self: Mesh_Instance3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_debug_tangents", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

mesh_instance3d_bake_mesh_from_current_blend_shape_mix :: proc "contextless" (
    self: Mesh_Instance3d,
    existing_: Array_Mesh,
) -> (ret: Array_Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bake_mesh_from_current_blend_shape_mix", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1457573577)
    }
    self := self
    existing_ := existing_
    args := []__bindgen_gde.TypePtr {
        &existing_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

mesh_instance3d_bake_mesh_from_current_skeleton_pose :: proc "contextless" (
    self: Mesh_Instance3d,
    existing_: Array_Mesh,
) -> (ret: Array_Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bake_mesh_from_current_skeleton_pose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1457573577)
    }
    self := self
    existing_ := existing_
    args := []__bindgen_gde.TypePtr {
        &existing_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
mesh_instance3d_get_skeleton :: proc "contextless" (self: Mesh_Instance3d) -> Node_Path {
    return mesh_instance3d_get_skeleton_path(self)
}
mesh_instance3d_set_skeleton :: proc "contextless" (self: Mesh_Instance3d, value: Node_Path) {
    mesh_instance3d_set_skeleton_path(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
mesh_instance3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("MeshInstance3D", true)
}

@(private = "file")
__class_name: String_Name