package godot

import __bindgen_gde "godot:gdext"

Directional_Light3d_Constants :: enum {
}
Directional_Light3d_Shadow_Mode :: enum int {
    Shadow_Orthogonal = 0,
    Shadow_Parallel_2_Splits = 1,
    Shadow_Parallel_4_Splits = 2,
}
Directional_Light3d_Sky_Mode :: enum int {
    Sky_Mode_Light_And_Sky = 0,
    Sky_Mode_Light_Only = 1,
    Sky_Mode_Sky_Only = 2,
}



directional_light3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

directional_light3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_directional_light3d :: proc "contextless" () -> Directional_Light3d {
    return cast(Directional_Light3d)__bindgen_gde.classdb_construct_object(directional_light3d_name_ref())
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

directional_light3d_set_shadow_mode :: proc "contextless" (
    self: Directional_Light3d,
    mode_: Directional_Light3d_Shadow_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadow_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1261211726)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

directional_light3d_get_shadow_mode :: proc "contextless" (
    self: Directional_Light3d,
) -> (ret: Directional_Light3d_Shadow_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shadow_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2765228544)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

directional_light3d_set_blend_splits :: proc "contextless" (
    self: Directional_Light3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_blend_splits", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

directional_light3d_is_blend_splits_enabled :: proc "contextless" (
    self: Directional_Light3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_blend_splits_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

directional_light3d_set_sky_mode :: proc "contextless" (
    self: Directional_Light3d,
    mode_: Directional_Light3d_Sky_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sky_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2691194817)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

directional_light3d_get_sky_mode :: proc "contextless" (
    self: Directional_Light3d,
) -> (ret: Directional_Light3d_Sky_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sky_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3819982774)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
directional_light3d_get_directional_shadow_mode :: proc "contextless" (self: Directional_Light3d) -> Directional_Light3d_Shadow_Mode {
    return directional_light3d_get_shadow_mode(self)
}
directional_light3d_set_directional_shadow_mode :: proc "contextless" (self: Directional_Light3d, value: Directional_Light3d_Shadow_Mode) {
    directional_light3d_set_shadow_mode(self, value)
}
directional_light3d_get_directional_shadow_blend_splits :: proc "contextless" (self: Directional_Light3d) -> Bool {
    return directional_light3d_is_blend_splits_enabled(self)
}
directional_light3d_set_directional_shadow_blend_splits :: proc "contextless" (self: Directional_Light3d, value: Bool) {
    directional_light3d_set_blend_splits(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
directional_light3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("DirectionalLight3D", true)
}

@(private = "file")
__class_name: String_Name