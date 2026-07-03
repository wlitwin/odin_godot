package godot

import __bindgen_gde "godot:gdext"

Omni_Light3d_Constants :: enum {
}
Omni_Light3d_Shadow_Mode :: enum int {
    Shadow_Dual_Paraboloid = 0,
    Shadow_Cube = 1,
}



omni_light3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

omni_light3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_omni_light3d :: proc "contextless" () -> Omni_Light3d {
    return __bindgen_gde.classdb_construct_object(omni_light3d_name_ref())
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

omni_light3d_set_shadow_mode :: proc "contextless" (
    self: Omni_Light3d,
    mode_: Omni_Light3d_Shadow_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadow_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 121862228)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

omni_light3d_get_shadow_mode :: proc "contextless" (
    self: Omni_Light3d,
) -> (ret: Omni_Light3d_Shadow_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shadow_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4181586331)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
omni_light3d_get_omni_shadow_mode :: proc "contextless" (self: Omni_Light3d) -> Omni_Light3d_Shadow_Mode {
    return omni_light3d_get_shadow_mode(self)
}
omni_light3d_set_omni_shadow_mode :: proc "contextless" (self: Omni_Light3d, value: Omni_Light3d_Shadow_Mode) {
    omni_light3d_set_shadow_mode(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
omni_light3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OmniLight3D", true)
}

@(private = "file")
__class_name: String_Name