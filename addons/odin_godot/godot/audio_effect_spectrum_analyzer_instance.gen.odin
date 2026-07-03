package godot

import __bindgen_gde "godot:gdext"

Audio_Effect_Spectrum_Analyzer_Instance_Constants :: enum {
}
Audio_Effect_Spectrum_Analyzer_Instance_Magnitude_Mode :: enum int {
    Magnitude_Average = 0,
    Magnitude_Max = 1,
}



audio_effect_spectrum_analyzer_instance_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

audio_effect_spectrum_analyzer_instance_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_audio_effect_spectrum_analyzer_instance :: proc "contextless" () -> Audio_Effect_Spectrum_Analyzer_Instance {
    return cast(Audio_Effect_Spectrum_Analyzer_Instance)__bindgen_gde.classdb_construct_object(audio_effect_spectrum_analyzer_instance_name_ref())
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

audio_effect_spectrum_analyzer_instance_get_magnitude_for_frequency_range :: proc "contextless" (
    self: Audio_Effect_Spectrum_Analyzer_Instance,
    from_hz_: f64,
    to_hz_: f64,
    mode_: Audio_Effect_Spectrum_Analyzer_Instance_Magnitude_Mode,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_magnitude_for_frequency_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 797993915)
    }
    self := self
    from_hz_ := from_hz_
    to_hz_ := to_hz_
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &from_hz_,
        &to_hz_,
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
audio_effect_spectrum_analyzer_instance_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AudioEffectSpectrumAnalyzerInstance", true)
}

@(private = "file")
__class_name: String_Name