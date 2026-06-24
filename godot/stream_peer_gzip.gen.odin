package godot

import __bindgen_gde "godot:gdext"

Stream_Peer_Gzip_Constants :: enum {
}



stream_peer_gzip_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

stream_peer_gzip_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_stream_peer_gzip :: proc "contextless" () -> Stream_Peer_Gzip {
    return cast(Stream_Peer_Gzip)__bindgen_gde.classdb_construct_object(stream_peer_gzip_name_ref())
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

stream_peer_gzip_start_compression :: proc "contextless" (
    self: Stream_Peer_Gzip,
    use_deflate_: Bool,
    buffer_size_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("start_compression", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 781582770)
    }
    self := self
    use_deflate_ := use_deflate_
    buffer_size_ := buffer_size_
    args := []__bindgen_gde.TypePtr {
        &use_deflate_,
        &buffer_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

stream_peer_gzip_start_decompression :: proc "contextless" (
    self: Stream_Peer_Gzip,
    use_deflate_: Bool,
    buffer_size_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("start_decompression", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 781582770)
    }
    self := self
    use_deflate_ := use_deflate_
    buffer_size_ := buffer_size_
    args := []__bindgen_gde.TypePtr {
        &use_deflate_,
        &buffer_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

stream_peer_gzip_finish :: proc "contextless" (
    self: Stream_Peer_Gzip,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("finish", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

stream_peer_gzip_clear :: proc "contextless" (
    self: Stream_Peer_Gzip,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
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
stream_peer_gzip_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("StreamPeerGZIP", true)
}

@(private = "file")
__class_name: String_Name