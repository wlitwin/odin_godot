package godot

import __bindgen_gde "godot:gdext"

Audio_Stream_Playback_Resampled_Constants :: enum {
}



audio_stream_playback_resampled_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

audio_stream_playback_resampled_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_audio_stream_playback_resampled :: proc "contextless" () -> Audio_Stream_Playback_Resampled {
    return cast(Audio_Stream_Playback_Resampled)__bindgen_gde.classdb_construct_object(audio_stream_playback_resampled_name_ref())
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

audio_stream_playback_resampled__mix_resampled :: proc "contextless" (
    self: Audio_Stream_Playback_Resampled,
    dst_buffer_: ^Audio_Frame,
    frame_count_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_mix_resampled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 50157827)
    }
    self := self
    dst_buffer_ := dst_buffer_
    frame_count_ := frame_count_
    args := []__bindgen_gde.TypePtr {
        &dst_buffer_,
        &frame_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_playback_resampled__get_stream_sampling_rate :: proc "contextless" (
    self: Audio_Stream_Playback_Resampled,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_stream_sampling_rate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_playback_resampled_begin_resample :: proc "contextless" (
    self: Audio_Stream_Playback_Resampled,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("begin_resample", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
audio_stream_playback_resampled_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AudioStreamPlaybackResampled", true)
}

@(private = "file")
__class_name: String_Name