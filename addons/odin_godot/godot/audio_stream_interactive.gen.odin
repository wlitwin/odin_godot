package godot

import __bindgen_gde "godot:gdext"

Audio_Stream_Interactive_Constants :: enum {
    CLIP_ANY = -1,
}
Audio_Stream_Interactive_Transition_From_Time :: enum int {
    Transition_From_Time_Immediate = 0,
    Transition_From_Time_Next_Beat = 1,
    Transition_From_Time_Next_Bar = 2,
    Transition_From_Time_End = 3,
}
Audio_Stream_Interactive_Transition_To_Time :: enum int {
    Transition_To_Time_Same_Position = 0,
    Transition_To_Time_Start = 1,
}
Audio_Stream_Interactive_Fade_Mode :: enum int {
    Fade_Disabled = 0,
    Fade_In = 1,
    Fade_Out = 2,
    Fade_Cross = 3,
    Fade_Automatic = 4,
}
Audio_Stream_Interactive_Auto_Advance_Mode :: enum int {
    Auto_Advance_Disabled = 0,
    Auto_Advance_Enabled = 1,
    Auto_Advance_Return_To_Hold = 2,
}



audio_stream_interactive_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

audio_stream_interactive_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_audio_stream_interactive :: proc "contextless" () -> Audio_Stream_Interactive {
    return cast(Audio_Stream_Interactive)__bindgen_gde.classdb_construct_object(audio_stream_interactive_name_ref())
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

audio_stream_interactive_set_clip_count :: proc "contextless" (
    self: Audio_Stream_Interactive,
    clip_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_clip_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    clip_count_ := clip_count_
    args := []__bindgen_gde.TypePtr {
        &clip_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_interactive_get_clip_count :: proc "contextless" (
    self: Audio_Stream_Interactive,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_clip_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_set_initial_clip :: proc "contextless" (
    self: Audio_Stream_Interactive,
    clip_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_initial_clip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    clip_index_ := clip_index_
    args := []__bindgen_gde.TypePtr {
        &clip_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_interactive_get_initial_clip :: proc "contextless" (
    self: Audio_Stream_Interactive,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_initial_clip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_set_clip_name :: proc "contextless" (
    self: Audio_Stream_Interactive,
    clip_index_: Int,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_clip_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3780747571)
    }
    self := self
    clip_index_ := clip_index_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &clip_index_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_interactive_get_clip_name :: proc "contextless" (
    self: Audio_Stream_Interactive,
    clip_index_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_clip_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 659327637)
    }
    self := self
    clip_index_ := clip_index_
    args := []__bindgen_gde.TypePtr {
        &clip_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_set_clip_stream :: proc "contextless" (
    self: Audio_Stream_Interactive,
    clip_index_: Int,
    stream_: Audio_Stream,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_clip_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 111075094)
    }
    self := self
    clip_index_ := clip_index_
    stream_ := stream_
    args := []__bindgen_gde.TypePtr {
        &clip_index_,
        &stream_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_interactive_get_clip_stream :: proc "contextless" (
    self: Audio_Stream_Interactive,
    clip_index_: Int,
) -> (ret: Audio_Stream) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_clip_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2739380747)
    }
    self := self
    clip_index_ := clip_index_
    args := []__bindgen_gde.TypePtr {
        &clip_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_set_clip_auto_advance :: proc "contextless" (
    self: Audio_Stream_Interactive,
    clip_index_: Int,
    mode_: Audio_Stream_Interactive_Auto_Advance_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_clip_auto_advance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 57217598)
    }
    self := self
    clip_index_ := clip_index_
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &clip_index_,
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_interactive_get_clip_auto_advance :: proc "contextless" (
    self: Audio_Stream_Interactive,
    clip_index_: Int,
) -> (ret: Audio_Stream_Interactive_Auto_Advance_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_clip_auto_advance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1778634807)
    }
    self := self
    clip_index_ := clip_index_
    args := []__bindgen_gde.TypePtr {
        &clip_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_set_clip_auto_advance_next_clip :: proc "contextless" (
    self: Audio_Stream_Interactive,
    clip_index_: Int,
    auto_advance_next_clip_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_clip_auto_advance_next_clip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    clip_index_ := clip_index_
    auto_advance_next_clip_ := auto_advance_next_clip_
    args := []__bindgen_gde.TypePtr {
        &clip_index_,
        &auto_advance_next_clip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_interactive_get_clip_auto_advance_next_clip :: proc "contextless" (
    self: Audio_Stream_Interactive,
    clip_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_clip_auto_advance_next_clip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    clip_index_ := clip_index_
    args := []__bindgen_gde.TypePtr {
        &clip_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_add_transition :: proc "contextless" (
    self: Audio_Stream_Interactive,
    from_clip_: Int,
    to_clip_: Int,
    from_time_: Audio_Stream_Interactive_Transition_From_Time,
    to_time_: Audio_Stream_Interactive_Transition_To_Time,
    fade_mode_: Audio_Stream_Interactive_Fade_Mode,
    fade_beats_: f64,
    use_filler_clip_: Bool,
    filler_clip_: Int,
    hold_previous_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_transition", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1630280552)
    }
    self := self
    from_clip_ := from_clip_
    to_clip_ := to_clip_
    from_time_ := from_time_
    to_time_ := to_time_
    fade_mode_ := fade_mode_
    fade_beats_ := fade_beats_
    use_filler_clip_ := use_filler_clip_
    filler_clip_ := filler_clip_
    hold_previous_ := hold_previous_
    args := []__bindgen_gde.TypePtr {
        &from_clip_,
        &to_clip_,
        &from_time_,
        &to_time_,
        &fade_mode_,
        &fade_beats_,
        &use_filler_clip_,
        &filler_clip_,
        &hold_previous_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_interactive_has_transition :: proc "contextless" (
    self: Audio_Stream_Interactive,
    from_clip_: Int,
    to_clip_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_transition", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2522259332)
    }
    self := self
    from_clip_ := from_clip_
    to_clip_ := to_clip_
    args := []__bindgen_gde.TypePtr {
        &from_clip_,
        &to_clip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_erase_transition :: proc "contextless" (
    self: Audio_Stream_Interactive,
    from_clip_: Int,
    to_clip_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase_transition", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    from_clip_ := from_clip_
    to_clip_ := to_clip_
    args := []__bindgen_gde.TypePtr {
        &from_clip_,
        &to_clip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_interactive_get_transition_list :: proc "contextless" (
    self: Audio_Stream_Interactive,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transition_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1930428628)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_get_transition_from_time :: proc "contextless" (
    self: Audio_Stream_Interactive,
    from_clip_: Int,
    to_clip_: Int,
) -> (ret: Audio_Stream_Interactive_Transition_From_Time) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transition_from_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3453338158)
    }
    self := self
    from_clip_ := from_clip_
    to_clip_ := to_clip_
    args := []__bindgen_gde.TypePtr {
        &from_clip_,
        &to_clip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_get_transition_to_time :: proc "contextless" (
    self: Audio_Stream_Interactive,
    from_clip_: Int,
    to_clip_: Int,
) -> (ret: Audio_Stream_Interactive_Transition_To_Time) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transition_to_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1369651373)
    }
    self := self
    from_clip_ := from_clip_
    to_clip_ := to_clip_
    args := []__bindgen_gde.TypePtr {
        &from_clip_,
        &to_clip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_get_transition_fade_mode :: proc "contextless" (
    self: Audio_Stream_Interactive,
    from_clip_: Int,
    to_clip_: Int,
) -> (ret: Audio_Stream_Interactive_Fade_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transition_fade_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4065396087)
    }
    self := self
    from_clip_ := from_clip_
    to_clip_ := to_clip_
    args := []__bindgen_gde.TypePtr {
        &from_clip_,
        &to_clip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_get_transition_fade_beats :: proc "contextless" (
    self: Audio_Stream_Interactive,
    from_clip_: Int,
    to_clip_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transition_fade_beats", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    from_clip_ := from_clip_
    to_clip_ := to_clip_
    args := []__bindgen_gde.TypePtr {
        &from_clip_,
        &to_clip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_is_transition_using_filler_clip :: proc "contextless" (
    self: Audio_Stream_Interactive,
    from_clip_: Int,
    to_clip_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_transition_using_filler_clip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2522259332)
    }
    self := self
    from_clip_ := from_clip_
    to_clip_ := to_clip_
    args := []__bindgen_gde.TypePtr {
        &from_clip_,
        &to_clip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_get_transition_filler_clip :: proc "contextless" (
    self: Audio_Stream_Interactive,
    from_clip_: Int,
    to_clip_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transition_filler_clip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175239445)
    }
    self := self
    from_clip_ := from_clip_
    to_clip_ := to_clip_
    args := []__bindgen_gde.TypePtr {
        &from_clip_,
        &to_clip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_stream_interactive_is_transition_holding_previous :: proc "contextless" (
    self: Audio_Stream_Interactive,
    from_clip_: Int,
    to_clip_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_transition_holding_previous", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2522259332)
    }
    self := self
    from_clip_ := from_clip_
    to_clip_ := to_clip_
    args := []__bindgen_gde.TypePtr {
        &from_clip_,
        &to_clip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
audio_stream_interactive_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AudioStreamInteractive", true)
}

@(private = "file")
__class_name: String_Name