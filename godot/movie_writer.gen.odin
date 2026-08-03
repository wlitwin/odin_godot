package godot

import __bindgen_gde "godot:gdext"

Movie_Writer_Constants :: enum {
}



movie_writer_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

movie_writer_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_movie_writer :: proc "contextless" () -> Movie_Writer {
    return cast(Movie_Writer)__bindgen_gde.classdb_construct_object(movie_writer_name_ref())
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
movie_writer_add_writer :: proc "contextless" (
    writer_: Movie_Writer,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_writer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4023702871)
    }
    writer_ := writer_
    args := []__bindgen_gde.TypePtr {
        &writer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), nil)
}


movie_writer__get_audio_mix_rate :: proc "contextless" (
    self: Movie_Writer,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_audio_mix_rate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

movie_writer__get_audio_speaker_mode :: proc "contextless" (
    self: Movie_Writer,
) -> (ret: Audio_Server_Speaker_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_audio_speaker_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2549190337)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

movie_writer__handles_file :: proc "contextless" (
    self: Movie_Writer,
    path_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_handles_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

movie_writer__get_supported_extensions :: proc "contextless" (
    self: Movie_Writer,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_supported_extensions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

movie_writer__write_begin :: proc "contextless" (
    self: Movie_Writer,
    movie_size_: Vector2i,
    fps_: Int,
    base_path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_write_begin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1866453460)
    }
    self := self
    movie_size_ := movie_size_
    fps_ := fps_
    base_path_ := base_path_
    args := []__bindgen_gde.TypePtr {
        &movie_size_,
        &fps_,
        &base_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

movie_writer__write_frame :: proc "contextless" (
    self: Movie_Writer,
    frame_image_: Image,
    audio_frame_block_: rawptr,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_write_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2784607037)
    }
    self := self
    frame_image_ := frame_image_
    audio_frame_block_ := audio_frame_block_
    args := []__bindgen_gde.TypePtr {
        &frame_image_,
        &audio_frame_block_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

movie_writer__write_end :: proc "contextless" (
    self: Movie_Writer,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_write_end", true)
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
movie_writer_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("MovieWriter", true)
}

@(private = "file")
__class_name: String_Name