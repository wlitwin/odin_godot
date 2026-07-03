package godot

import __bindgen_gde "godot:gdext"

Physics_Direct_Space_State2d_Constants :: enum {
}



physics_direct_space_state2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

physics_direct_space_state2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_physics_direct_space_state2d :: proc "contextless" () -> Physics_Direct_Space_State2d {
    return __bindgen_gde.classdb_construct_object(physics_direct_space_state2d_name_ref())
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

physics_direct_space_state2d_intersect_point :: proc "contextless" (
    self: Physics_Direct_Space_State2d,
    parameters_: Physics_Point_Query_Parameters2d,
    max_results_: Int,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersect_point", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2118456068)
    }
    self := self
    parameters_ := parameters_
    max_results_ := max_results_
    args := []__bindgen_gde.TypePtr {
        &parameters_,
        &max_results_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_direct_space_state2d_intersect_ray :: proc "contextless" (
    self: Physics_Direct_Space_State2d,
    parameters_: Physics_Ray_Query_Parameters2d,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersect_ray", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1590275562)
    }
    self := self
    parameters_ := parameters_
    args := []__bindgen_gde.TypePtr {
        &parameters_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_direct_space_state2d_intersect_shape :: proc "contextless" (
    self: Physics_Direct_Space_State2d,
    parameters_: Physics_Shape_Query_Parameters2d,
    max_results_: Int,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersect_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2488867228)
    }
    self := self
    parameters_ := parameters_
    max_results_ := max_results_
    args := []__bindgen_gde.TypePtr {
        &parameters_,
        &max_results_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_direct_space_state2d_cast_motion :: proc "contextless" (
    self: Physics_Direct_Space_State2d,
    parameters_: Physics_Shape_Query_Parameters2d,
) -> (ret: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cast_motion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 711275086)
    }
    self := self
    parameters_ := parameters_
    args := []__bindgen_gde.TypePtr {
        &parameters_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_direct_space_state2d_collide_shape :: proc "contextless" (
    self: Physics_Direct_Space_State2d,
    parameters_: Physics_Shape_Query_Parameters2d,
    max_results_: Int,
) -> (ret: Typed_Array(Vector2)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("collide_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2488867228)
    }
    self := self
    parameters_ := parameters_
    max_results_ := max_results_
    args := []__bindgen_gde.TypePtr {
        &parameters_,
        &max_results_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_direct_space_state2d_get_rest_info :: proc "contextless" (
    self: Physics_Direct_Space_State2d,
    parameters_: Physics_Shape_Query_Parameters2d,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rest_info", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2803666496)
    }
    self := self
    parameters_ := parameters_
    args := []__bindgen_gde.TypePtr {
        &parameters_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
physics_direct_space_state2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PhysicsDirectSpaceState2D", true)
}

@(private = "file")
__class_name: String_Name