package godot

import __bindgen_gde "godot:gdext"

Cone_Twist_Joint3d_Constants :: enum {
}
Cone_Twist_Joint3d_Param :: enum int {
    Param_Swing_Span = 0,
    Param_Twist_Span = 1,
    Param_Bias = 2,
    Param_Softness = 3,
    Param_Relaxation = 4,
    Param_Max = 5,
}



cone_twist_joint3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

cone_twist_joint3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_cone_twist_joint3d :: proc "contextless" () -> Cone_Twist_Joint3d {
    return __bindgen_gde.classdb_construct_object(cone_twist_joint3d_name_ref())
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

cone_twist_joint3d_set_param :: proc "contextless" (
    self: Cone_Twist_Joint3d,
    param_: Cone_Twist_Joint3d_Param,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1062470226)
    }
    self := self
    param_ := param_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &param_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cone_twist_joint3d_get_param :: proc "contextless" (
    self: Cone_Twist_Joint3d,
    param_: Cone_Twist_Joint3d_Param,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2928790850)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
cone_twist_joint3d_get_swing_span :: proc "contextless" (self: Cone_Twist_Joint3d) -> f64 {
    return cone_twist_joint3d_get_param(self, Cone_Twist_Joint3d_Param(0))
}
cone_twist_joint3d_set_swing_span :: proc "contextless" (self: Cone_Twist_Joint3d, value: f64) {
    cone_twist_joint3d_set_param(self, Cone_Twist_Joint3d_Param(0), value)
}
cone_twist_joint3d_get_twist_span :: proc "contextless" (self: Cone_Twist_Joint3d) -> f64 {
    return cone_twist_joint3d_get_param(self, Cone_Twist_Joint3d_Param(1))
}
cone_twist_joint3d_set_twist_span :: proc "contextless" (self: Cone_Twist_Joint3d, value: f64) {
    cone_twist_joint3d_set_param(self, Cone_Twist_Joint3d_Param(1), value)
}
cone_twist_joint3d_get_bias :: proc "contextless" (self: Cone_Twist_Joint3d) -> f64 {
    return cone_twist_joint3d_get_param(self, Cone_Twist_Joint3d_Param(2))
}
cone_twist_joint3d_set_bias :: proc "contextless" (self: Cone_Twist_Joint3d, value: f64) {
    cone_twist_joint3d_set_param(self, Cone_Twist_Joint3d_Param(2), value)
}
cone_twist_joint3d_get_softness :: proc "contextless" (self: Cone_Twist_Joint3d) -> f64 {
    return cone_twist_joint3d_get_param(self, Cone_Twist_Joint3d_Param(3))
}
cone_twist_joint3d_set_softness :: proc "contextless" (self: Cone_Twist_Joint3d, value: f64) {
    cone_twist_joint3d_set_param(self, Cone_Twist_Joint3d_Param(3), value)
}
cone_twist_joint3d_get_relaxation :: proc "contextless" (self: Cone_Twist_Joint3d) -> f64 {
    return cone_twist_joint3d_get_param(self, Cone_Twist_Joint3d_Param(4))
}
cone_twist_joint3d_set_relaxation :: proc "contextless" (self: Cone_Twist_Joint3d, value: f64) {
    cone_twist_joint3d_set_param(self, Cone_Twist_Joint3d_Param(4), value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
cone_twist_joint3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ConeTwistJoint3D", true)
}

@(private = "file")
__class_name: String_Name