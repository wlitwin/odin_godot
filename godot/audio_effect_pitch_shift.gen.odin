package godot

import __bindgen_gde "godot:gdext"

Audio_Effect_Pitch_Shift_Constants :: enum {
}
Audio_Effect_Pitch_Shift_Fft_Size :: enum int {
    Fft_Size_256 = 0,
    Fft_Size_512 = 1,
    Fft_Size_1024 = 2,
    Fft_Size_2048 = 3,
    Fft_Size_4096 = 4,
    Fft_Size_Max = 5,
}



audio_effect_pitch_shift_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

audio_effect_pitch_shift_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_audio_effect_pitch_shift :: proc "contextless" () -> Audio_Effect_Pitch_Shift {
    return cast(Audio_Effect_Pitch_Shift)__bindgen_gde.classdb_construct_object(audio_effect_pitch_shift_name_ref())
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

audio_effect_pitch_shift_set_pitch_scale :: proc "contextless" (
    self: Audio_Effect_Pitch_Shift,
    rate_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_pitch_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    rate_ := rate_
    args := []__bindgen_gde.TypePtr {
        &rate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_pitch_shift_get_pitch_scale :: proc "contextless" (
    self: Audio_Effect_Pitch_Shift,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pitch_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_pitch_shift_set_oversampling :: proc "contextless" (
    self: Audio_Effect_Pitch_Shift,
    amount_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_oversampling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_pitch_shift_get_oversampling :: proc "contextless" (
    self: Audio_Effect_Pitch_Shift,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_oversampling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_effect_pitch_shift_set_fft_size :: proc "contextless" (
    self: Audio_Effect_Pitch_Shift,
    size_: Audio_Effect_Pitch_Shift_Fft_Size,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fft_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2323518741)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_effect_pitch_shift_get_fft_size :: proc "contextless" (
    self: Audio_Effect_Pitch_Shift,
) -> (ret: Audio_Effect_Pitch_Shift_Fft_Size) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fft_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2361246789)
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
audio_effect_pitch_shift_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AudioEffectPitchShift", true)
}

@(private = "file")
__class_name: String_Name