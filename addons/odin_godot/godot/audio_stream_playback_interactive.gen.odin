package godot

import __bindgen_gde "godot:gdext"

Audio_Stream_Playback_Interactive_Constants :: enum {
}



audio_stream_playback_interactive_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

audio_stream_playback_interactive_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_audio_stream_playback_interactive :: proc "contextless" () -> Audio_Stream_Playback_Interactive {
    return cast(Audio_Stream_Playback_Interactive)__bindgen_gde.classdb_construct_object(audio_stream_playback_interactive_name_ref())
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

audio_stream_playback_interactive_switch_to_clip_by_name :: proc "contextless" (
    self: Audio_Stream_Playback_Interactive,
    clip_name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("switch_to_clip_by_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    clip_name_ := clip_name_
    args := []__bindgen_gde.TypePtr {
        &clip_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_playback_interactive_switch_to_clip :: proc "contextless" (
    self: Audio_Stream_Playback_Interactive,
    clip_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("switch_to_clip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    clip_index_ := clip_index_
    args := []__bindgen_gde.TypePtr {
        &clip_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_stream_playback_interactive_get_current_clip_index :: proc "contextless" (
    self: Audio_Stream_Playback_Interactive,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_clip_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
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
audio_stream_playback_interactive_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AudioStreamPlaybackInteractive", true)
}

@(private = "file")
__class_name: String_Name