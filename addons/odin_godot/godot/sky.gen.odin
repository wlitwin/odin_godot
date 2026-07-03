package godot

import __bindgen_gde "godot:gdext"

Sky_Constants :: enum {
}
Sky_Radiance_Size :: enum int {
    Radiance_Size_32 = 0,
    Radiance_Size_64 = 1,
    Radiance_Size_128 = 2,
    Radiance_Size_256 = 3,
    Radiance_Size_512 = 4,
    Radiance_Size_1024 = 5,
    Radiance_Size_2048 = 6,
    Radiance_Size_Max = 7,
}
Sky_Process_Mode :: enum int {
    Process_Mode_Automatic = 0,
    Process_Mode_Quality = 1,
    Process_Mode_Incremental = 2,
    Process_Mode_Realtime = 3,
}



sky_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

sky_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_sky :: proc "contextless" () -> Sky {
    return cast(Sky)__bindgen_gde.classdb_construct_object(sky_name_ref())
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

sky_set_radiance_size :: proc "contextless" (
    self: Sky,
    size_: Sky_Radiance_Size,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_radiance_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1512957179)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sky_get_radiance_size :: proc "contextless" (
    self: Sky,
) -> (ret: Sky_Radiance_Size) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_radiance_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2708733976)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sky_set_process_mode :: proc "contextless" (
    self: Sky,
    mode_: Sky_Process_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_process_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 875986769)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sky_get_process_mode :: proc "contextless" (
    self: Sky,
) -> (ret: Sky_Process_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_process_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 731245043)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sky_set_material :: proc "contextless" (
    self: Sky,
    material_: Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2757459619)
    }
    self := self
    material_ := material_
    args := []__bindgen_gde.TypePtr {
        &material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sky_get_material :: proc "contextless" (
    self: Sky,
) -> (ret: Material) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 5934680)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
sky_get_sky_material :: proc "contextless" (self: Sky) -> Material {
    return sky_get_material(self)
}
sky_set_sky_material :: proc "contextless" (self: Sky, value: Material) {
    sky_set_material(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
sky_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Sky", true)
}

@(private = "file")
__class_name: String_Name