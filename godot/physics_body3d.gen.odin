package godot

import __bindgen_gde "godot:gdext"

Physics_Body3d_Constants :: enum {
}



physics_body3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

physics_body3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_physics_body3d :: proc "contextless" () -> Physics_Body3d {
    return cast(Physics_Body3d)__bindgen_gde.classdb_construct_object(physics_body3d_name_ref())
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

physics_body3d_move_and_collide :: proc "contextless" (
    self: Physics_Body3d,
    motion_: Vector3,
    test_only_: Bool,
    safe_margin_: f64,
    recovery_as_collision_: Bool,
    max_collisions_: Int,
) -> (ret: Kinematic_Collision3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_and_collide", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3208792678)
    }
    self := self
    motion_ := motion_
    test_only_ := test_only_
    safe_margin_ := safe_margin_
    recovery_as_collision_ := recovery_as_collision_
    max_collisions_ := max_collisions_
    args := []__bindgen_gde.TypePtr {
        &motion_,
        &test_only_,
        &safe_margin_,
        &recovery_as_collision_,
        &max_collisions_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_body3d_test_move :: proc "contextless" (
    self: Physics_Body3d,
    from_: Transform3d,
    motion_: Vector3,
    collision_: Kinematic_Collision3d,
    safe_margin_: f64,
    recovery_as_collision_: Bool,
    max_collisions_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("test_move", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2481691619)
    }
    self := self
    from_ := from_
    motion_ := motion_
    collision_ := collision_
    safe_margin_ := safe_margin_
    recovery_as_collision_ := recovery_as_collision_
    max_collisions_ := max_collisions_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &motion_,
        &collision_,
        &safe_margin_,
        &recovery_as_collision_,
        &max_collisions_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_body3d_get_gravity :: proc "contextless" (
    self: Physics_Body3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_body3d_set_axis_lock :: proc "contextless" (
    self: Physics_Body3d,
    axis_: Physics_Server3d_Body_Axis,
    lock_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_axis_lock", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1787895195)
    }
    self := self
    axis_ := axis_
    lock_ := lock_
    args := []__bindgen_gde.TypePtr {
        &axis_,
        &lock_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_body3d_get_axis_lock :: proc "contextless" (
    self: Physics_Body3d,
    axis_: Physics_Server3d_Body_Axis,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_axis_lock", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2264617709)
    }
    self := self
    axis_ := axis_
    args := []__bindgen_gde.TypePtr {
        &axis_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_body3d_get_collision_exceptions :: proc "contextless" (
    self: Physics_Body3d,
) -> (ret: Typed_Array(Physics_Body3d)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_exceptions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_body3d_add_collision_exception_with :: proc "contextless" (
    self: Physics_Body3d,
    body_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_collision_exception_with", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_body3d_remove_collision_exception_with :: proc "contextless" (
    self: Physics_Body3d,
    body_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_collision_exception_with", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
physics_body3d_get_axis_lock_linear_x :: proc "contextless" (self: Physics_Body3d) -> Bool {
    return physics_body3d_get_axis_lock(self, Physics_Server3d_Body_Axis(1))
}
physics_body3d_set_axis_lock_linear_x :: proc "contextless" (self: Physics_Body3d, value: Bool) {
    physics_body3d_set_axis_lock(self, Physics_Server3d_Body_Axis(1), value)
}
physics_body3d_get_axis_lock_linear_y :: proc "contextless" (self: Physics_Body3d) -> Bool {
    return physics_body3d_get_axis_lock(self, Physics_Server3d_Body_Axis(2))
}
physics_body3d_set_axis_lock_linear_y :: proc "contextless" (self: Physics_Body3d, value: Bool) {
    physics_body3d_set_axis_lock(self, Physics_Server3d_Body_Axis(2), value)
}
physics_body3d_get_axis_lock_linear_z :: proc "contextless" (self: Physics_Body3d) -> Bool {
    return physics_body3d_get_axis_lock(self, Physics_Server3d_Body_Axis(4))
}
physics_body3d_set_axis_lock_linear_z :: proc "contextless" (self: Physics_Body3d, value: Bool) {
    physics_body3d_set_axis_lock(self, Physics_Server3d_Body_Axis(4), value)
}
physics_body3d_get_axis_lock_angular_x :: proc "contextless" (self: Physics_Body3d) -> Bool {
    return physics_body3d_get_axis_lock(self, Physics_Server3d_Body_Axis(8))
}
physics_body3d_set_axis_lock_angular_x :: proc "contextless" (self: Physics_Body3d, value: Bool) {
    physics_body3d_set_axis_lock(self, Physics_Server3d_Body_Axis(8), value)
}
physics_body3d_get_axis_lock_angular_y :: proc "contextless" (self: Physics_Body3d) -> Bool {
    return physics_body3d_get_axis_lock(self, Physics_Server3d_Body_Axis(16))
}
physics_body3d_set_axis_lock_angular_y :: proc "contextless" (self: Physics_Body3d, value: Bool) {
    physics_body3d_set_axis_lock(self, Physics_Server3d_Body_Axis(16), value)
}
physics_body3d_get_axis_lock_angular_z :: proc "contextless" (self: Physics_Body3d) -> Bool {
    return physics_body3d_get_axis_lock(self, Physics_Server3d_Body_Axis(32))
}
physics_body3d_set_axis_lock_angular_z :: proc "contextless" (self: Physics_Body3d, value: Bool) {
    physics_body3d_set_axis_lock(self, Physics_Server3d_Body_Axis(32), value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
physics_body3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PhysicsBody3D", true)
}

@(private = "file")
__class_name: String_Name