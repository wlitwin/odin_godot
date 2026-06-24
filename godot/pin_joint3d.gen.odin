package godot

import __bindgen_gde "godot:gdext"

Pin_Joint3d_Constants :: enum {
}
Pin_Joint3d_Param :: enum int {
    Param_Bias = 0,
    Param_Damping = 1,
    Param_Impulse_Clamp = 2,
}



pin_joint3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

pin_joint3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_pin_joint3d :: proc "contextless" () -> Pin_Joint3d {
    return __bindgen_gde.classdb_construct_object(pin_joint3d_name_ref())
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

pin_joint3d_set_param :: proc "contextless" (
    self: Pin_Joint3d,
    param_: Pin_Joint3d_Param,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2059913726)
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

pin_joint3d_get_param :: proc "contextless" (
    self: Pin_Joint3d,
    param_: Pin_Joint3d_Param,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1758438771)
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
pin_joint3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PinJoint3D", true)
}

@(private = "file")
__class_name: String_Name