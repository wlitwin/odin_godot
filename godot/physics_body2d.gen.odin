package godot

import __bindgen_gde "godot:gdext"

Physics_Body2d_Constants :: enum {
}



physics_body2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

physics_body2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_physics_body2d :: proc "contextless" () -> Physics_Body2d {
    return __bindgen_gde.classdb_construct_object(physics_body2d_name_ref())
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

physics_body2d_move_and_collide :: proc "contextless" (
    self: Physics_Body2d,
    motion_: Vector2,
    test_only_: Bool,
    safe_margin_: f64,
    recovery_as_collision_: Bool,
) -> (ret: Kinematic_Collision2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_and_collide", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3681923724)
    }
    self := self
    motion_ := motion_
    test_only_ := test_only_
    safe_margin_ := safe_margin_
    recovery_as_collision_ := recovery_as_collision_
    args := []__bindgen_gde.TypePtr {
        &motion_,
        &test_only_,
        &safe_margin_,
        &recovery_as_collision_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_body2d_test_move :: proc "contextless" (
    self: Physics_Body2d,
    from_: Transform2d,
    motion_: Vector2,
    collision_: Kinematic_Collision2d,
    safe_margin_: f64,
    recovery_as_collision_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("test_move", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3324464701)
    }
    self := self
    from_ := from_
    motion_ := motion_
    collision_ := collision_
    safe_margin_ := safe_margin_
    recovery_as_collision_ := recovery_as_collision_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &motion_,
        &collision_,
        &safe_margin_,
        &recovery_as_collision_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_body2d_get_gravity :: proc "contextless" (
    self: Physics_Body2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_body2d_get_collision_exceptions :: proc "contextless" (
    self: Physics_Body2d,
) -> (ret: Typed_Array(Physics_Body2d)) {
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

physics_body2d_add_collision_exception_with :: proc "contextless" (
    self: Physics_Body2d,
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

physics_body2d_remove_collision_exception_with :: proc "contextless" (
    self: Physics_Body2d,
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

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
physics_body2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PhysicsBody2D", true)
}

@(private = "file")
__class_name: String_Name