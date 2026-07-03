package godot

import __bindgen_gde "godot:gdext"

Audio_Effect_Chorus_Constants :: enum {
}



audio_effect_chorus_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

audio_effect_chorus_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_audio_effect_chorus :: proc "contextless" () -> Audio_Effect_Chorus {
    return cast(Audio_Effect_Chorus)__bindgen_gde.classdb_construct_object(audio_effect_chorus_name_ref())
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

audio_effect_chorus_set_voice_count :: proc "contextless" (
    self: Audio_Effect_Chorus,
    voices_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_voice_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    voices_ := voices_
    args := []__bindgen_gde.TypePtr {
        &voices_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_chorus_get_voice_count :: proc "contextless" (
    self: Audio_Effect_Chorus,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_voice_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_chorus_set_voice_delay_ms :: proc "contextless" (
    self: Audio_Effect_Chorus,
    voice_idx_: Int,
    delay_ms_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_voice_delay_ms", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    voice_idx_ := voice_idx_
    delay_ms_ := delay_ms_
    args := []__bindgen_gde.TypePtr {
        &voice_idx_,
        &delay_ms_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_chorus_get_voice_delay_ms :: proc "contextless" (
    self: Audio_Effect_Chorus,
    voice_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_voice_delay_ms", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    voice_idx_ := voice_idx_
    args := []__bindgen_gde.TypePtr {
        &voice_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_chorus_set_voice_rate_hz :: proc "contextless" (
    self: Audio_Effect_Chorus,
    voice_idx_: Int,
    rate_hz_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_voice_rate_hz", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    voice_idx_ := voice_idx_
    rate_hz_ := rate_hz_
    args := []__bindgen_gde.TypePtr {
        &voice_idx_,
        &rate_hz_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_chorus_get_voice_rate_hz :: proc "contextless" (
    self: Audio_Effect_Chorus,
    voice_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_voice_rate_hz", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    voice_idx_ := voice_idx_
    args := []__bindgen_gde.TypePtr {
        &voice_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_chorus_set_voice_depth_ms :: proc "contextless" (
    self: Audio_Effect_Chorus,
    voice_idx_: Int,
    depth_ms_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_voice_depth_ms", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    voice_idx_ := voice_idx_
    depth_ms_ := depth_ms_
    args := []__bindgen_gde.TypePtr {
        &voice_idx_,
        &depth_ms_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_chorus_get_voice_depth_ms :: proc "contextless" (
    self: Audio_Effect_Chorus,
    voice_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_voice_depth_ms", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    voice_idx_ := voice_idx_
    args := []__bindgen_gde.TypePtr {
        &voice_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_chorus_set_voice_level_db :: proc "contextless" (
    self: Audio_Effect_Chorus,
    voice_idx_: Int,
    level_db_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_voice_level_db", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    voice_idx_ := voice_idx_
    level_db_ := level_db_
    args := []__bindgen_gde.TypePtr {
        &voice_idx_,
        &level_db_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_chorus_get_voice_level_db :: proc "contextless" (
    self: Audio_Effect_Chorus,
    voice_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_voice_level_db", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    voice_idx_ := voice_idx_
    args := []__bindgen_gde.TypePtr {
        &voice_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_chorus_set_voice_cutoff_hz :: proc "contextless" (
    self: Audio_Effect_Chorus,
    voice_idx_: Int,
    cutoff_hz_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_voice_cutoff_hz", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    voice_idx_ := voice_idx_
    cutoff_hz_ := cutoff_hz_
    args := []__bindgen_gde.TypePtr {
        &voice_idx_,
        &cutoff_hz_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_chorus_get_voice_cutoff_hz :: proc "contextless" (
    self: Audio_Effect_Chorus,
    voice_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_voice_cutoff_hz", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    voice_idx_ := voice_idx_
    args := []__bindgen_gde.TypePtr {
        &voice_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_chorus_set_voice_pan :: proc "contextless" (
    self: Audio_Effect_Chorus,
    voice_idx_: Int,
    pan_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_voice_pan", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    voice_idx_ := voice_idx_
    pan_ := pan_
    args := []__bindgen_gde.TypePtr {
        &voice_idx_,
        &pan_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_chorus_get_voice_pan :: proc "contextless" (
    self: Audio_Effect_Chorus,
    voice_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_voice_pan", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    voice_idx_ := voice_idx_
    args := []__bindgen_gde.TypePtr {
        &voice_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_chorus_set_wet :: proc "contextless" (
    self: Audio_Effect_Chorus,
    amount_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_wet", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_chorus_get_wet :: proc "contextless" (
    self: Audio_Effect_Chorus,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_wet", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_chorus_set_dry :: proc "contextless" (
    self: Audio_Effect_Chorus,
    amount_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_dry", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_chorus_get_dry :: proc "contextless" (
    self: Audio_Effect_Chorus,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_dry", true)
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
audio_effect_chorus_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AudioEffectChorus", true)
}

@(private = "file")
__class_name: String_Name