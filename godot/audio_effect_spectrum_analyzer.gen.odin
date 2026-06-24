package godot

import __bindgen_gde "godot:gdext"

Audio_Effect_Spectrum_Analyzer_Constants :: enum {
}
Audio_Effect_Spectrum_Analyzer_Fft_Size :: enum int {
    Fft_Size_256 = 0,
    Fft_Size_512 = 1,
    Fft_Size_1024 = 2,
    Fft_Size_2048 = 3,
    Fft_Size_4096 = 4,
    Fft_Size_Max = 5,
}



audio_effect_spectrum_analyzer_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

audio_effect_spectrum_analyzer_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_audio_effect_spectrum_analyzer :: proc "contextless" () -> Audio_Effect_Spectrum_Analyzer {
    return cast(Audio_Effect_Spectrum_Analyzer)__bindgen_gde.classdb_construct_object(audio_effect_spectrum_analyzer_name_ref())
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

audio_effect_spectrum_analyzer_set_buffer_length :: proc "contextless" (
    self: Audio_Effect_Spectrum_Analyzer,
    seconds_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_buffer_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    seconds_ := seconds_
    args := []__bindgen_gde.TypePtr {
        &seconds_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_spectrum_analyzer_get_buffer_length :: proc "contextless" (
    self: Audio_Effect_Spectrum_Analyzer,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_buffer_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_spectrum_analyzer_set_tap_back_pos :: proc "contextless" (
    self: Audio_Effect_Spectrum_Analyzer,
    seconds_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tap_back_pos", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    seconds_ := seconds_
    args := []__bindgen_gde.TypePtr {
        &seconds_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_spectrum_analyzer_get_tap_back_pos :: proc "contextless" (
    self: Audio_Effect_Spectrum_Analyzer,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tap_back_pos", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_spectrum_analyzer_set_fft_size :: proc "contextless" (
    self: Audio_Effect_Spectrum_Analyzer,
    size_: Audio_Effect_Spectrum_Analyzer_Fft_Size,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fft_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1202879215)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_spectrum_analyzer_get_fft_size :: proc "contextless" (
    self: Audio_Effect_Spectrum_Analyzer,
) -> (ret: Audio_Effect_Spectrum_Analyzer_Fft_Size) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fft_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3925405343)
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
audio_effect_spectrum_analyzer_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AudioEffectSpectrumAnalyzer", true)
}

@(private = "file")
__class_name: String_Name