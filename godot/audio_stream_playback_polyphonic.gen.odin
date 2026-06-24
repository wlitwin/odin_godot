package godot

import __bindgen_gde "godot:gdext"

Audio_Stream_Playback_Polyphonic_Constants :: enum {
    INVALID_ID = -1,
}



audio_stream_playback_polyphonic_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

audio_stream_playback_polyphonic_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_audio_stream_playback_polyphonic :: proc "contextless" () -> Audio_Stream_Playback_Polyphonic {
    return cast(Audio_Stream_Playback_Polyphonic)__bindgen_gde.classdb_construct_object(audio_stream_playback_polyphonic_name_ref())
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

audio_stream_playback_polyphonic_play_stream :: proc "contextless" (
    self: Audio_Stream_Playback_Polyphonic,
    stream_: Audio_Stream,
    from_offset_: f64,
    volume_db_: f64,
    pitch_scale_: f64,
    playback_type_: Audio_Server_Playback_Type,
    bus_: String_Name,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("play_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1846744803)
    }
    self := self
    stream_ := stream_
    from_offset_ := from_offset_
    volume_db_ := volume_db_
    pitch_scale_ := pitch_scale_
    playback_type_ := playback_type_
    bus_ := bus_
    args := []__bindgen_gde.TypePtr {
        &stream_,
        &from_offset_,
        &volume_db_,
        &pitch_scale_,
        &playback_type_,
        &bus_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_playback_polyphonic_set_stream_volume :: proc "contextless" (
    self: Audio_Stream_Playback_Polyphonic,
    stream_: Int,
    volume_db_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stream_volume", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    stream_ := stream_
    volume_db_ := volume_db_
    args := []__bindgen_gde.TypePtr {
        &stream_,
        &volume_db_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_playback_polyphonic_set_stream_pitch_scale :: proc "contextless" (
    self: Audio_Stream_Playback_Polyphonic,
    stream_: Int,
    pitch_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stream_pitch_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    stream_ := stream_
    pitch_scale_ := pitch_scale_
    args := []__bindgen_gde.TypePtr {
        &stream_,
        &pitch_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_playback_polyphonic_is_stream_playing :: proc "contextless" (
    self: Audio_Stream_Playback_Polyphonic,
    stream_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_stream_playing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    stream_ := stream_
    args := []__bindgen_gde.TypePtr {
        &stream_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_playback_polyphonic_stop_stream :: proc "contextless" (
    self: Audio_Stream_Playback_Polyphonic,
    stream_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("stop_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    stream_ := stream_
    args := []__bindgen_gde.TypePtr {
        &stream_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
audio_stream_playback_polyphonic_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AudioStreamPlaybackPolyphonic", true)
}

@(private = "file")
__class_name: String_Name