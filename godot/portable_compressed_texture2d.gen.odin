package godot

import __bindgen_gde "godot:gdext"

Portable_Compressed_Texture2d_Constants :: enum {
}
Portable_Compressed_Texture2d_Compression_Mode :: enum int {
    Compression_Mode_Lossless = 0,
    Compression_Mode_Lossy = 1,
    Compression_Mode_Basis_Universal = 2,
    Compression_Mode_S3tc = 3,
    Compression_Mode_Etc2 = 4,
    Compression_Mode_Bptc = 5,
    Compression_Mode_Astc = 6,
}



portable_compressed_texture2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

portable_compressed_texture2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_portable_compressed_texture2d :: proc "contextless" () -> Portable_Compressed_Texture2d {
    return cast(Portable_Compressed_Texture2d)__bindgen_gde.classdb_construct_object(portable_compressed_texture2d_name_ref())
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
portable_compressed_texture2d_set_keep_all_compressed_buffers :: proc "contextless" (
    keep_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_keep_all_compressed_buffers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    keep_ := keep_
    args := []__bindgen_gde.TypePtr {
        &keep_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), nil)
}

portable_compressed_texture2d_is_keeping_all_compressed_buffers :: proc "contextless" (
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_keeping_all_compressed_buffers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}


portable_compressed_texture2d_create_from_image :: proc "contextless" (
    self: Portable_Compressed_Texture2d,
    image_: Image,
    compression_mode_: Portable_Compressed_Texture2d_Compression_Mode,
    normal_map_: Bool,
    lossy_quality_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_from_image", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3679243433)
    }
    self := self
    image_ := image_
    compression_mode_ := compression_mode_
    normal_map_ := normal_map_
    lossy_quality_ := lossy_quality_
    args := []__bindgen_gde.TypePtr {
        &image_,
        &compression_mode_,
        &normal_map_,
        &lossy_quality_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

portable_compressed_texture2d_get_format :: proc "contextless" (
    self: Portable_Compressed_Texture2d,
) -> (ret: Image_Format) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3847873762)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

portable_compressed_texture2d_get_compression_mode :: proc "contextless" (
    self: Portable_Compressed_Texture2d,
) -> (ret: Portable_Compressed_Texture2d_Compression_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_compression_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3265612739)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

portable_compressed_texture2d_set_size_override :: proc "contextless" (
    self: Portable_Compressed_Texture2d,
    size_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_size_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

portable_compressed_texture2d_get_size_override :: proc "contextless" (
    self: Portable_Compressed_Texture2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_size_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

portable_compressed_texture2d_set_keep_compressed_buffer :: proc "contextless" (
    self: Portable_Compressed_Texture2d,
    keep_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_keep_compressed_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    keep_ := keep_
    args := []__bindgen_gde.TypePtr {
        &keep_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

portable_compressed_texture2d_is_keeping_compressed_buffer :: proc "contextless" (
    self: Portable_Compressed_Texture2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_keeping_compressed_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

portable_compressed_texture2d_set_basisu_compressor_params :: proc "contextless" (
    self: Portable_Compressed_Texture2d,
    uastc_level_: Int,
    rdo_quality_loss_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_basisu_compressor_params", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    uastc_level_ := uastc_level_
    rdo_quality_loss_ := rdo_quality_loss_
    args := []__bindgen_gde.TypePtr {
        &uastc_level_,
        &rdo_quality_loss_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
portable_compressed_texture2d_get_keep_compressed_buffer :: proc "contextless" (self: Portable_Compressed_Texture2d) -> Bool {
    return portable_compressed_texture2d_is_keeping_compressed_buffer(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
portable_compressed_texture2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PortableCompressedTexture2D", true)
}

@(private = "file")
__class_name: String_Name