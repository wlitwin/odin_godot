package godot

import __bindgen_gde "godot:gdext"

Audio_Stream_Randomizer_Constants :: enum {
}
Audio_Stream_Randomizer_Playback_Mode :: enum int {
    Playback_Random_No_Repeats = 0,
    Playback_Random = 1,
    Playback_Sequential = 2,
}



audio_stream_randomizer_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

audio_stream_randomizer_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_audio_stream_randomizer :: proc "contextless" () -> Audio_Stream_Randomizer {
    return cast(Audio_Stream_Randomizer)__bindgen_gde.classdb_construct_object(audio_stream_randomizer_name_ref())
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

audio_stream_randomizer_add_stream :: proc "contextless" (
    self: Audio_Stream_Randomizer,
    index_: Int,
    stream_: Audio_Stream,
    weight_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1892018854)
    }
    self := self
    index_ := index_
    stream_ := stream_
    weight_ := weight_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &stream_,
        &weight_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_randomizer_move_stream :: proc "contextless" (
    self: Audio_Stream_Randomizer,
    index_from_: Int,
    index_to_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    index_from_ := index_from_
    index_to_ := index_to_
    args := []__bindgen_gde.TypePtr {
        &index_from_,
        &index_to_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_randomizer_remove_stream :: proc "contextless" (
    self: Audio_Stream_Randomizer,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_randomizer_set_stream :: proc "contextless" (
    self: Audio_Stream_Randomizer,
    index_: Int,
    stream_: Audio_Stream,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 111075094)
    }
    self := self
    index_ := index_
    stream_ := stream_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &stream_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_randomizer_get_stream :: proc "contextless" (
    self: Audio_Stream_Randomizer,
    index_: Int,
) -> (ret: Audio_Stream) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2739380747)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_randomizer_set_stream_probability_weight :: proc "contextless" (
    self: Audio_Stream_Randomizer,
    index_: Int,
    weight_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stream_probability_weight", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    index_ := index_
    weight_ := weight_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &weight_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_randomizer_get_stream_probability_weight :: proc "contextless" (
    self: Audio_Stream_Randomizer,
    index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stream_probability_weight", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_randomizer_set_streams_count :: proc "contextless" (
    self: Audio_Stream_Randomizer,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_streams_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_randomizer_get_streams_count :: proc "contextless" (
    self: Audio_Stream_Randomizer,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_streams_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_randomizer_set_random_pitch :: proc "contextless" (
    self: Audio_Stream_Randomizer,
    scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_random_pitch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_randomizer_get_random_pitch :: proc "contextless" (
    self: Audio_Stream_Randomizer,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_random_pitch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_randomizer_set_random_pitch_semitones :: proc "contextless" (
    self: Audio_Stream_Randomizer,
    semitones_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_random_pitch_semitones", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    semitones_ := semitones_
    args := []__bindgen_gde.TypePtr {
        &semitones_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_randomizer_get_random_pitch_semitones :: proc "contextless" (
    self: Audio_Stream_Randomizer,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_random_pitch_semitones", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_randomizer_set_random_volume_offset_db :: proc "contextless" (
    self: Audio_Stream_Randomizer,
    db_offset_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_random_volume_offset_db", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    db_offset_ := db_offset_
    args := []__bindgen_gde.TypePtr {
        &db_offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_randomizer_get_random_volume_offset_db :: proc "contextless" (
    self: Audio_Stream_Randomizer,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_random_volume_offset_db", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_randomizer_set_playback_mode :: proc "contextless" (
    self: Audio_Stream_Randomizer,
    mode_: Audio_Stream_Randomizer_Playback_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_playback_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3950967023)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_randomizer_get_playback_mode :: proc "contextless" (
    self: Audio_Stream_Randomizer,
) -> (ret: Audio_Stream_Randomizer_Playback_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_playback_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3943055077)
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
audio_stream_randomizer_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AudioStreamRandomizer", true)
}

@(private = "file")
__class_name: String_Name