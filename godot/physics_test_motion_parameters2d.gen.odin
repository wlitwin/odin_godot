package godot

import __bindgen_gde "godot:gdext"

Physics_Test_Motion_Parameters2d_Constants :: enum {
}



physics_test_motion_parameters2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

physics_test_motion_parameters2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_physics_test_motion_parameters2d :: proc "contextless" () -> Physics_Test_Motion_Parameters2d {
    return cast(Physics_Test_Motion_Parameters2d)__bindgen_gde.classdb_construct_object(physics_test_motion_parameters2d_name_ref())
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

physics_test_motion_parameters2d_get_from :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814499831)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_test_motion_parameters2d_set_from :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
    from_: Transform2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2761652528)
    }
    self := self
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_test_motion_parameters2d_get_motion :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_motion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_test_motion_parameters2d_set_motion :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
    motion_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_motion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    motion_ := motion_
    args := []__bindgen_gde.TypePtr {
        &motion_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_test_motion_parameters2d_get_margin :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_test_motion_parameters2d_set_margin :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
    margin_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    margin_ := margin_
    args := []__bindgen_gde.TypePtr {
        &margin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_test_motion_parameters2d_is_collide_separation_ray_enabled :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_collide_separation_ray_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_test_motion_parameters2d_set_collide_separation_ray_enabled :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collide_separation_ray_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_test_motion_parameters2d_get_exclude_bodies :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
) -> (ret: Typed_Array(Rid)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_exclude_bodies", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_test_motion_parameters2d_set_exclude_bodies :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
    exclude_list_: Typed_Array(Rid),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_exclude_bodies", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    exclude_list_ := exclude_list_
    args := []__bindgen_gde.TypePtr {
        &exclude_list_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_test_motion_parameters2d_get_exclude_objects :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
) -> (ret: Typed_Array(Int)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_exclude_objects", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_test_motion_parameters2d_set_exclude_objects :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
    exclude_list_: Typed_Array(Int),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_exclude_objects", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    exclude_list_ := exclude_list_
    args := []__bindgen_gde.TypePtr {
        &exclude_list_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_test_motion_parameters2d_is_recovery_as_collision_enabled :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_recovery_as_collision_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_test_motion_parameters2d_set_recovery_as_collision_enabled :: proc "contextless" (
    self: Physics_Test_Motion_Parameters2d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_recovery_as_collision_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
physics_test_motion_parameters2d_get_collide_separation_ray :: proc "contextless" (self: Physics_Test_Motion_Parameters2d) -> Bool {
    return physics_test_motion_parameters2d_is_collide_separation_ray_enabled(self)
}
physics_test_motion_parameters2d_set_collide_separation_ray :: proc "contextless" (self: Physics_Test_Motion_Parameters2d, value: Bool) {
    physics_test_motion_parameters2d_set_collide_separation_ray_enabled(self, value)
}
physics_test_motion_parameters2d_get_recovery_as_collision :: proc "contextless" (self: Physics_Test_Motion_Parameters2d) -> Bool {
    return physics_test_motion_parameters2d_is_recovery_as_collision_enabled(self)
}
physics_test_motion_parameters2d_set_recovery_as_collision :: proc "contextless" (self: Physics_Test_Motion_Parameters2d, value: Bool) {
    physics_test_motion_parameters2d_set_recovery_as_collision_enabled(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
physics_test_motion_parameters2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PhysicsTestMotionParameters2D", true)
}

@(private = "file")
__class_name: String_Name