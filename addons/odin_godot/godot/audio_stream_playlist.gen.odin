package godot

import __bindgen_gde "godot:gdext"

Audio_Stream_Playlist_Constants :: enum {
    MAX_STREAMS = 64,
}



audio_stream_playlist_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

audio_stream_playlist_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_audio_stream_playlist :: proc "contextless" () -> Audio_Stream_Playlist {
    return cast(Audio_Stream_Playlist)__bindgen_gde.classdb_construct_object(audio_stream_playlist_name_ref())
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

audio_stream_playlist_set_stream_count :: proc "contextless" (
    self: Audio_Stream_Playlist,
    stream_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stream_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    stream_count_ := stream_count_
    args := []__bindgen_gde.TypePtr {
        &stream_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_playlist_get_stream_count :: proc "contextless" (
    self: Audio_Stream_Playlist,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stream_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_playlist_get_bpm :: proc "contextless" (
    self: Audio_Stream_Playlist,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bpm", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_playlist_set_list_stream :: proc "contextless" (
    self: Audio_Stream_Playlist,
    stream_index_: Int,
    audio_stream_: Audio_Stream,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_list_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 111075094)
    }
    self := self
    stream_index_ := stream_index_
    audio_stream_ := audio_stream_
    args := []__bindgen_gde.TypePtr {
        &stream_index_,
        &audio_stream_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_playlist_get_list_stream :: proc "contextless" (
    self: Audio_Stream_Playlist,
    stream_index_: Int,
) -> (ret: Audio_Stream) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_list_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2739380747)
    }
    self := self
    stream_index_ := stream_index_
    args := []__bindgen_gde.TypePtr {
        &stream_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_playlist_set_shuffle :: proc "contextless" (
    self: Audio_Stream_Playlist,
    shuffle_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shuffle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    shuffle_ := shuffle_
    args := []__bindgen_gde.TypePtr {
        &shuffle_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_playlist_get_shuffle :: proc "contextless" (
    self: Audio_Stream_Playlist,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shuffle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_playlist_set_fade_time :: proc "contextless" (
    self: Audio_Stream_Playlist,
    dec_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fade_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    dec_ := dec_
    args := []__bindgen_gde.TypePtr {
        &dec_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_playlist_get_fade_time :: proc "contextless" (
    self: Audio_Stream_Playlist,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fade_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_playlist_set_loop :: proc "contextless" (
    self: Audio_Stream_Playlist,
    loop_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_loop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    loop_ := loop_
    args := []__bindgen_gde.TypePtr {
        &loop_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_playlist_has_loop :: proc "contextless" (
    self: Audio_Stream_Playlist,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_loop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
audio_stream_playlist_get_loop :: proc "contextless" (self: Audio_Stream_Playlist) -> Bool {
    return audio_stream_playlist_has_loop(self)
}
audio_stream_playlist_get_stream_0 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(0))
}
audio_stream_playlist_set_stream_0 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(0), value)
}
audio_stream_playlist_get_stream_1 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(1))
}
audio_stream_playlist_set_stream_1 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(1), value)
}
audio_stream_playlist_get_stream_2 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(2))
}
audio_stream_playlist_set_stream_2 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(2), value)
}
audio_stream_playlist_get_stream_3 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(3))
}
audio_stream_playlist_set_stream_3 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(3), value)
}
audio_stream_playlist_get_stream_4 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(4))
}
audio_stream_playlist_set_stream_4 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(4), value)
}
audio_stream_playlist_get_stream_5 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(5))
}
audio_stream_playlist_set_stream_5 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(5), value)
}
audio_stream_playlist_get_stream_6 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(6))
}
audio_stream_playlist_set_stream_6 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(6), value)
}
audio_stream_playlist_get_stream_7 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(7))
}
audio_stream_playlist_set_stream_7 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(7), value)
}
audio_stream_playlist_get_stream_8 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(8))
}
audio_stream_playlist_set_stream_8 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(8), value)
}
audio_stream_playlist_get_stream_9 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(9))
}
audio_stream_playlist_set_stream_9 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(9), value)
}
audio_stream_playlist_get_stream_10 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(10))
}
audio_stream_playlist_set_stream_10 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(10), value)
}
audio_stream_playlist_get_stream_11 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(11))
}
audio_stream_playlist_set_stream_11 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(11), value)
}
audio_stream_playlist_get_stream_12 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(12))
}
audio_stream_playlist_set_stream_12 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(12), value)
}
audio_stream_playlist_get_stream_13 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(13))
}
audio_stream_playlist_set_stream_13 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(13), value)
}
audio_stream_playlist_get_stream_14 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(14))
}
audio_stream_playlist_set_stream_14 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(14), value)
}
audio_stream_playlist_get_stream_15 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(15))
}
audio_stream_playlist_set_stream_15 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(15), value)
}
audio_stream_playlist_get_stream_16 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(16))
}
audio_stream_playlist_set_stream_16 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(16), value)
}
audio_stream_playlist_get_stream_17 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(17))
}
audio_stream_playlist_set_stream_17 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(17), value)
}
audio_stream_playlist_get_stream_18 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(18))
}
audio_stream_playlist_set_stream_18 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(18), value)
}
audio_stream_playlist_get_stream_19 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(19))
}
audio_stream_playlist_set_stream_19 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(19), value)
}
audio_stream_playlist_get_stream_20 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(20))
}
audio_stream_playlist_set_stream_20 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(20), value)
}
audio_stream_playlist_get_stream_21 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(21))
}
audio_stream_playlist_set_stream_21 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(21), value)
}
audio_stream_playlist_get_stream_22 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(22))
}
audio_stream_playlist_set_stream_22 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(22), value)
}
audio_stream_playlist_get_stream_23 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(23))
}
audio_stream_playlist_set_stream_23 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(23), value)
}
audio_stream_playlist_get_stream_24 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(24))
}
audio_stream_playlist_set_stream_24 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(24), value)
}
audio_stream_playlist_get_stream_25 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(25))
}
audio_stream_playlist_set_stream_25 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(25), value)
}
audio_stream_playlist_get_stream_26 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(26))
}
audio_stream_playlist_set_stream_26 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(26), value)
}
audio_stream_playlist_get_stream_27 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(27))
}
audio_stream_playlist_set_stream_27 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(27), value)
}
audio_stream_playlist_get_stream_28 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(28))
}
audio_stream_playlist_set_stream_28 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(28), value)
}
audio_stream_playlist_get_stream_29 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(29))
}
audio_stream_playlist_set_stream_29 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(29), value)
}
audio_stream_playlist_get_stream_30 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(30))
}
audio_stream_playlist_set_stream_30 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(30), value)
}
audio_stream_playlist_get_stream_31 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(31))
}
audio_stream_playlist_set_stream_31 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(31), value)
}
audio_stream_playlist_get_stream_32 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(32))
}
audio_stream_playlist_set_stream_32 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(32), value)
}
audio_stream_playlist_get_stream_33 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(33))
}
audio_stream_playlist_set_stream_33 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(33), value)
}
audio_stream_playlist_get_stream_34 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(34))
}
audio_stream_playlist_set_stream_34 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(34), value)
}
audio_stream_playlist_get_stream_35 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(35))
}
audio_stream_playlist_set_stream_35 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(35), value)
}
audio_stream_playlist_get_stream_36 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(36))
}
audio_stream_playlist_set_stream_36 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(36), value)
}
audio_stream_playlist_get_stream_37 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(37))
}
audio_stream_playlist_set_stream_37 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(37), value)
}
audio_stream_playlist_get_stream_38 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(38))
}
audio_stream_playlist_set_stream_38 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(38), value)
}
audio_stream_playlist_get_stream_39 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(39))
}
audio_stream_playlist_set_stream_39 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(39), value)
}
audio_stream_playlist_get_stream_40 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(40))
}
audio_stream_playlist_set_stream_40 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(40), value)
}
audio_stream_playlist_get_stream_41 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(41))
}
audio_stream_playlist_set_stream_41 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(41), value)
}
audio_stream_playlist_get_stream_42 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(42))
}
audio_stream_playlist_set_stream_42 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(42), value)
}
audio_stream_playlist_get_stream_43 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(43))
}
audio_stream_playlist_set_stream_43 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(43), value)
}
audio_stream_playlist_get_stream_44 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(44))
}
audio_stream_playlist_set_stream_44 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(44), value)
}
audio_stream_playlist_get_stream_45 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(45))
}
audio_stream_playlist_set_stream_45 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(45), value)
}
audio_stream_playlist_get_stream_46 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(46))
}
audio_stream_playlist_set_stream_46 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(46), value)
}
audio_stream_playlist_get_stream_47 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(47))
}
audio_stream_playlist_set_stream_47 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(47), value)
}
audio_stream_playlist_get_stream_48 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(48))
}
audio_stream_playlist_set_stream_48 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(48), value)
}
audio_stream_playlist_get_stream_49 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(49))
}
audio_stream_playlist_set_stream_49 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(49), value)
}
audio_stream_playlist_get_stream_50 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(50))
}
audio_stream_playlist_set_stream_50 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(50), value)
}
audio_stream_playlist_get_stream_51 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(51))
}
audio_stream_playlist_set_stream_51 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(51), value)
}
audio_stream_playlist_get_stream_52 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(52))
}
audio_stream_playlist_set_stream_52 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(52), value)
}
audio_stream_playlist_get_stream_53 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(53))
}
audio_stream_playlist_set_stream_53 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(53), value)
}
audio_stream_playlist_get_stream_54 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(54))
}
audio_stream_playlist_set_stream_54 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(54), value)
}
audio_stream_playlist_get_stream_55 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(55))
}
audio_stream_playlist_set_stream_55 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(55), value)
}
audio_stream_playlist_get_stream_56 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(56))
}
audio_stream_playlist_set_stream_56 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(56), value)
}
audio_stream_playlist_get_stream_57 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(57))
}
audio_stream_playlist_set_stream_57 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(57), value)
}
audio_stream_playlist_get_stream_58 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(58))
}
audio_stream_playlist_set_stream_58 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(58), value)
}
audio_stream_playlist_get_stream_59 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(59))
}
audio_stream_playlist_set_stream_59 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(59), value)
}
audio_stream_playlist_get_stream_60 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(60))
}
audio_stream_playlist_set_stream_60 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(60), value)
}
audio_stream_playlist_get_stream_61 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(61))
}
audio_stream_playlist_set_stream_61 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(61), value)
}
audio_stream_playlist_get_stream_62 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(62))
}
audio_stream_playlist_set_stream_62 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(62), value)
}
audio_stream_playlist_get_stream_63 :: proc "contextless" (self: Audio_Stream_Playlist) -> Audio_Stream {
    return audio_stream_playlist_get_list_stream(self, Int(63))
}
audio_stream_playlist_set_stream_63 :: proc "contextless" (self: Audio_Stream_Playlist, value: Audio_Stream) {
    audio_stream_playlist_set_list_stream(self, Int(63), value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
audio_stream_playlist_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AudioStreamPlaylist", true)
}

@(private = "file")
__class_name: String_Name