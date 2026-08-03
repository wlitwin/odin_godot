package godot

import __bindgen_gde "godot:gdext"

Slider_Joint3d_Constants :: enum {
}
Slider_Joint3d_Param :: enum int {
    Param_Linear_Limit_Upper = 0,
    Param_Linear_Limit_Lower = 1,
    Param_Linear_Limit_Softness = 2,
    Param_Linear_Limit_Restitution = 3,
    Param_Linear_Limit_Damping = 4,
    Param_Linear_Motion_Softness = 5,
    Param_Linear_Motion_Restitution = 6,
    Param_Linear_Motion_Damping = 7,
    Param_Linear_Orthogonal_Softness = 8,
    Param_Linear_Orthogonal_Restitution = 9,
    Param_Linear_Orthogonal_Damping = 10,
    Param_Angular_Limit_Upper = 11,
    Param_Angular_Limit_Lower = 12,
    Param_Angular_Limit_Softness = 13,
    Param_Angular_Limit_Restitution = 14,
    Param_Angular_Limit_Damping = 15,
    Param_Angular_Motion_Softness = 16,
    Param_Angular_Motion_Restitution = 17,
    Param_Angular_Motion_Damping = 18,
    Param_Angular_Orthogonal_Softness = 19,
    Param_Angular_Orthogonal_Restitution = 20,
    Param_Angular_Orthogonal_Damping = 21,
    Param_Max = 22,
}



slider_joint3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

slider_joint3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_slider_joint3d :: proc "contextless" () -> Slider_Joint3d {
    return cast(Slider_Joint3d)__bindgen_gde.classdb_construct_object(slider_joint3d_name_ref())
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

slider_joint3d_set_param :: proc "contextless" (
    self: Slider_Joint3d,
    param_: Slider_Joint3d_Param,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 918243683)
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

slider_joint3d_get_param :: proc "contextless" (
    self: Slider_Joint3d,
    param_: Slider_Joint3d_Param,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 959925627)
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

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
slider_joint3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SliderJoint3D", true)
}

@(private = "file")
__class_name: String_Name