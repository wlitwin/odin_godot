package godot

import __bindgen_gde "godot:gdext"

Audio_Stream_Player_Constants :: enum {
}
Audio_Stream_Player_Mix_Target :: enum int {
    Mix_Target_Stereo = 0,
    Mix_Target_Surround = 1,
    Mix_Target_Center = 2,
}



audio_stream_player_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

audio_stream_player_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_audio_stream_player :: proc "contextless" () -> Audio_Stream_Player {
    return cast(Audio_Stream_Player)__bindgen_gde.classdb_construct_object(audio_stream_player_name_ref())
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

audio_stream_player_set_stream :: proc "contextless" (
    self: Audio_Stream_Player,
    stream_: Audio_Stream,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2210767741)
    }
    self := self
    stream_ := stream_
    args := []__bindgen_gde.TypePtr {
        &stream_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_get_stream :: proc "contextless" (
    self: Audio_Stream_Player,
) -> (ret: Audio_Stream) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 160907539)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_player_set_volume_db :: proc "contextless" (
    self: Audio_Stream_Player,
    volume_db_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_volume_db", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    volume_db_ := volume_db_
    args := []__bindgen_gde.TypePtr {
        &volume_db_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_get_volume_db :: proc "contextless" (
    self: Audio_Stream_Player,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_volume_db", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_player_set_volume_linear :: proc "contextless" (
    self: Audio_Stream_Player,
    volume_linear_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_volume_linear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    volume_linear_ := volume_linear_
    args := []__bindgen_gde.TypePtr {
        &volume_linear_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_get_volume_linear :: proc "contextless" (
    self: Audio_Stream_Player,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_volume_linear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_player_set_pitch_scale :: proc "contextless" (
    self: Audio_Stream_Player,
    pitch_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_pitch_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    pitch_scale_ := pitch_scale_
    args := []__bindgen_gde.TypePtr {
        &pitch_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_get_pitch_scale :: proc "contextless" (
    self: Audio_Stream_Player,
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

audio_stream_player_play :: proc "contextless" (
    self: Audio_Stream_Player,
    from_position_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("play", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1958160172)
    }
    self := self
    from_position_ := from_position_
    args := []__bindgen_gde.TypePtr {
        &from_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_seek :: proc "contextless" (
    self: Audio_Stream_Player,
    to_position_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("seek", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_stop :: proc "contextless" (
    self: Audio_Stream_Player,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("stop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_is_playing :: proc "contextless" (
    self: Audio_Stream_Player,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_playing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_player_get_playback_position :: proc "contextless" (
    self: Audio_Stream_Player,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_playback_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_player_set_bus :: proc "contextless" (
    self: Audio_Stream_Player,
    bus_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    bus_ := bus_
    args := []__bindgen_gde.TypePtr {
        &bus_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_get_bus :: proc "contextless" (
    self: Audio_Stream_Player,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2002593661)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_player_set_autoplay :: proc "contextless" (
    self: Audio_Stream_Player,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_autoplay", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_is_autoplay_enabled :: proc "contextless" (
    self: Audio_Stream_Player,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_autoplay_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_player_set_mix_target :: proc "contextless" (
    self: Audio_Stream_Player,
    mix_target_: Audio_Stream_Player_Mix_Target,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mix_target", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2300306138)
    }
    self := self
    mix_target_ := mix_target_
    args := []__bindgen_gde.TypePtr {
        &mix_target_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_get_mix_target :: proc "contextless" (
    self: Audio_Stream_Player,
) -> (ret: Audio_Stream_Player_Mix_Target) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mix_target", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 172807476)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_player_set_playing :: proc "contextless" (
    self: Audio_Stream_Player,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_playing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_set_stream_paused :: proc "contextless" (
    self: Audio_Stream_Player,
    pause_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stream_paused", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    pause_ := pause_
    args := []__bindgen_gde.TypePtr {
        &pause_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_get_stream_paused :: proc "contextless" (
    self: Audio_Stream_Player,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stream_paused", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_player_set_max_polyphony :: proc "contextless" (
    self: Audio_Stream_Player,
    max_polyphony_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_polyphony", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    max_polyphony_ := max_polyphony_
    args := []__bindgen_gde.TypePtr {
        &max_polyphony_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_get_max_polyphony :: proc "contextless" (
    self: Audio_Stream_Player,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_polyphony", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_player_has_stream_playback :: proc "contextless" (
    self: Audio_Stream_Player,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_stream_playback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_player_get_stream_playback :: proc "contextless" (
    self: Audio_Stream_Player,
) -> (ret: Audio_Stream_Playback) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stream_playback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 210135309)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_player_set_playback_type :: proc "contextless" (
    self: Audio_Stream_Player,
    playback_type_: Audio_Server_Playback_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_playback_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 725473817)
    }
    self := self
    playback_type_ := playback_type_
    args := []__bindgen_gde.TypePtr {
        &playback_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_player_get_playback_type :: proc "contextless" (
    self: Audio_Stream_Player,
) -> (ret: Audio_Server_Playback_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_playback_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4011264623)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
audio_stream_player_get_playing :: proc "contextless" (self: Audio_Stream_Player) -> Bool {
    return audio_stream_player_is_playing(self)
}
audio_stream_player_get_autoplay :: proc "contextless" (self: Audio_Stream_Player) -> Bool {
    return audio_stream_player_is_autoplay_enabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
audio_stream_player_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AudioStreamPlayer", true)
}

@(private = "file")
__class_name: String_Name