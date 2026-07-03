package godot

import __bindgen_gde "godot:gdext"

Audio_Effect_Distortion_Constants :: enum {
}
Audio_Effect_Distortion_Mode :: enum int {
    Mode_Clip = 0,
    Mode_Atan = 1,
    Mode_Lofi = 2,
    Mode_Overdrive = 3,
    Mode_Waveshape = 4,
}



audio_effect_distortion_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

audio_effect_distortion_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_audio_effect_distortion :: proc "contextless" () -> Audio_Effect_Distortion {
    return cast(Audio_Effect_Distortion)__bindgen_gde.classdb_construct_object(audio_effect_distortion_name_ref())
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

audio_effect_distortion_set_mode :: proc "contextless" (
    self: Audio_Effect_Distortion,
    mode_: Audio_Effect_Distortion_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1314744793)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_distortion_get_mode :: proc "contextless" (
    self: Audio_Effect_Distortion,
) -> (ret: Audio_Effect_Distortion_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 809118343)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_distortion_set_pre_gain :: proc "contextless" (
    self: Audio_Effect_Distortion,
    pre_gain_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_pre_gain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    pre_gain_ := pre_gain_
    args := []__bindgen_gde.TypePtr {
        &pre_gain_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_distortion_get_pre_gain :: proc "contextless" (
    self: Audio_Effect_Distortion,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pre_gain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_distortion_set_keep_hf_hz :: proc "contextless" (
    self: Audio_Effect_Distortion,
    keep_hf_hz_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_keep_hf_hz", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    keep_hf_hz_ := keep_hf_hz_
    args := []__bindgen_gde.TypePtr {
        &keep_hf_hz_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_distortion_get_keep_hf_hz :: proc "contextless" (
    self: Audio_Effect_Distortion,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_keep_hf_hz", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_distortion_set_drive :: proc "contextless" (
    self: Audio_Effect_Distortion,
    drive_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_drive", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    drive_ := drive_
    args := []__bindgen_gde.TypePtr {
        &drive_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_distortion_get_drive :: proc "contextless" (
    self: Audio_Effect_Distortion,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_drive", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_distortion_set_post_gain :: proc "contextless" (
    self: Audio_Effect_Distortion,
    post_gain_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_post_gain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    post_gain_ := post_gain_
    args := []__bindgen_gde.TypePtr {
        &post_gain_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_distortion_get_post_gain :: proc "contextless" (
    self: Audio_Effect_Distortion,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_post_gain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
audio_effect_distortion_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AudioEffectDistortion", true)
}

@(private = "file")
__class_name: String_Name