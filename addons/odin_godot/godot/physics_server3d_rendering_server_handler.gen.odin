package godot

import __bindgen_gde "godot:gdext"

Physics_Server3d_Rendering_Server_Handler_Constants :: enum {
}



physics_server3d_rendering_server_handler_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

physics_server3d_rendering_server_handler_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_physics_server3d_rendering_server_handler :: proc "contextless" () -> Physics_Server3d_Rendering_Server_Handler {
    return cast(Physics_Server3d_Rendering_Server_Handler)__bindgen_gde.classdb_construct_object(physics_server3d_rendering_server_handler_name_ref())
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

physics_server3d_rendering_server_handler__set_vertex :: proc "contextless" (
    self: Physics_Server3d_Rendering_Server_Handler,
    vertex_id_: Int,
    vertex_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_vertex", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1530502735)
    }
    self := self
    vertex_id_ := vertex_id_
    vertex_ := vertex_
    args := []__bindgen_gde.TypePtr {
        &vertex_id_,
        &vertex_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_rendering_server_handler__set_normal :: proc "contextless" (
    self: Physics_Server3d_Rendering_Server_Handler,
    vertex_id_: Int,
    normal_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_normal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1530502735)
    }
    self := self
    vertex_id_ := vertex_id_
    normal_ := normal_
    args := []__bindgen_gde.TypePtr {
        &vertex_id_,
        &normal_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_rendering_server_handler__set_aabb :: proc "contextless" (
    self: Physics_Server3d_Rendering_Server_Handler,
    aabb_: Aabb,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_aabb", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 259215842)
    }
    self := self
    aabb_ := aabb_
    args := []__bindgen_gde.TypePtr {
        &aabb_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_rendering_server_handler_set_vertex :: proc "contextless" (
    self: Physics_Server3d_Rendering_Server_Handler,
    vertex_id_: Int,
    vertex_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertex", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1530502735)
    }
    self := self
    vertex_id_ := vertex_id_
    vertex_ := vertex_
    args := []__bindgen_gde.TypePtr {
        &vertex_id_,
        &vertex_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_rendering_server_handler_set_normal :: proc "contextless" (
    self: Physics_Server3d_Rendering_Server_Handler,
    vertex_id_: Int,
    normal_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_normal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1530502735)
    }
    self := self
    vertex_id_ := vertex_id_
    normal_ := normal_
    args := []__bindgen_gde.TypePtr {
        &vertex_id_,
        &normal_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_rendering_server_handler_set_aabb :: proc "contextless" (
    self: Physics_Server3d_Rendering_Server_Handler,
    aabb_: Aabb,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_aabb", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 259215842)
    }
    self := self
    aabb_ := aabb_
    args := []__bindgen_gde.TypePtr {
        &aabb_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
physics_server3d_rendering_server_handler_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PhysicsServer3DRenderingServerHandler", true)
}

@(private = "file")
__class_name: String_Name