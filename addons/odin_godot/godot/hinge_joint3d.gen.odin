package godot

import __bindgen_gde "godot:gdext"

Hinge_Joint3d_Constants :: enum {
}
Hinge_Joint3d_Param :: enum int {
    Param_Bias = 0,
    Param_Limit_Upper = 1,
    Param_Limit_Lower = 2,
    Param_Limit_Bias = 3,
    Param_Limit_Softness = 4,
    Param_Limit_Relaxation = 5,
    Param_Motor_Target_Velocity = 6,
    Param_Motor_Max_Impulse = 7,
    Param_Max = 8,
}
Hinge_Joint3d_Flag :: enum int {
    Flag_Use_Limit = 0,
    Flag_Enable_Motor = 1,
    Flag_Max = 2,
}



hinge_joint3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

hinge_joint3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_hinge_joint3d :: proc "contextless" () -> Hinge_Joint3d {
    return __bindgen_gde.classdb_construct_object(hinge_joint3d_name_ref())
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

hinge_joint3d_set_param :: proc "contextless" (
    self: Hinge_Joint3d,
    param_: Hinge_Joint3d_Param,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3082977519)
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

hinge_joint3d_get_param :: proc "contextless" (
    self: Hinge_Joint3d,
    param_: Hinge_Joint3d_Param,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4066002676)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

hinge_joint3d_set_flag :: proc "contextless" (
    self: Hinge_Joint3d,
    flag_: Hinge_Joint3d_Flag,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1083494620)
    }
    self := self
    flag_ := flag_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &flag_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

hinge_joint3d_get_flag :: proc "contextless" (
    self: Hinge_Joint3d,
    flag_: Hinge_Joint3d_Flag,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2841369610)
    }
    self := self
    flag_ := flag_
    args := []__bindgen_gde.TypePtr {
        &flag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
hinge_joint3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("HingeJoint3D", true)
}

@(private = "file")
__class_name: String_Name