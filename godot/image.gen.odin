package godot

import __bindgen_gde "godot:gdext"

Image_Constants :: enum {
    MAX_WIDTH = 16777216,
    MAX_HEIGHT = 16777216,
}
Image_Format :: enum int {
    Format_L8 = 0,
    Format_La8 = 1,
    Format_R8 = 2,
    Format_Rg8 = 3,
    Format_Rgb8 = 4,
    Format_Rgba8 = 5,
    Format_Rgba4444 = 6,
    Format_Rgb565 = 7,
    Format_Rf = 8,
    Format_Rgf = 9,
    Format_Rgbf = 10,
    Format_Rgbaf = 11,
    Format_Rh = 12,
    Format_Rgh = 13,
    Format_Rgbh = 14,
    Format_Rgbah = 15,
    Format_Rgbe9995 = 16,
    Format_Dxt1 = 17,
    Format_Dxt3 = 18,
    Format_Dxt5 = 19,
    Format_Rgtc_R = 20,
    Format_Rgtc_Rg = 21,
    Format_Bptc_Rgba = 22,
    Format_Bptc_Rgbf = 23,
    Format_Bptc_Rgbfu = 24,
    Format_Etc = 25,
    Format_Etc2_R11 = 26,
    Format_Etc2_R11s = 27,
    Format_Etc2_Rg11 = 28,
    Format_Etc2_Rg11s = 29,
    Format_Etc2_Rgb8 = 30,
    Format_Etc2_Rgba8 = 31,
    Format_Etc2_Rgb8a1 = 32,
    Format_Etc2_Ra_As_Rg = 33,
    Format_Dxt5_Ra_As_Rg = 34,
    Format_Astc_4x4 = 35,
    Format_Astc_4x4_Hdr = 36,
    Format_Astc_8x8 = 37,
    Format_Astc_8x8_Hdr = 38,
    Format_R16 = 39,
    Format_Rg16 = 40,
    Format_Rgb16 = 41,
    Format_Rgba16 = 42,
    Format_R16i = 43,
    Format_Rg16i = 44,
    Format_Rgb16i = 45,
    Format_Rgba16i = 46,
    Format_Max = 47,
}
Image_Interpolation :: enum int {
    Interpolate_Nearest = 0,
    Interpolate_Bilinear = 1,
    Interpolate_Cubic = 2,
    Interpolate_Trilinear = 3,
    Interpolate_Lanczos = 4,
}
Image_Alpha_Mode :: enum int {
    Alpha_None = 0,
    Alpha_Bit = 1,
    Alpha_Blend = 2,
}
Image_Compress_Mode :: enum int {
    Compress_S3tc = 0,
    Compress_Etc = 1,
    Compress_Etc2 = 2,
    Compress_Bptc = 3,
    Compress_Astc = 4,
    Compress_Max = 5,
}
Image_Used_Channels :: enum int {
    Used_Channels_L = 0,
    Used_Channels_La = 1,
    Used_Channels_R = 2,
    Used_Channels_Rg = 3,
    Used_Channels_Rgb = 4,
    Used_Channels_Rgba = 5,
}
Image_Compress_Source :: enum int {
    Compress_Source_Generic = 0,
    Compress_Source_Srgb = 1,
    Compress_Source_Normal = 2,
}
Image_Astc_Format :: enum int {
    Astc_Format_4x4 = 0,
    Astc_Format_8x8 = 1,
}



image_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

image_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_image :: proc "contextless" () -> Image {
    return cast(Image)__bindgen_gde.classdb_construct_object(image_name_ref())
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
image_create :: proc "contextless" (
    width_: Int,
    height_: Int,
    use_mipmaps_: Bool,
    format_: Image_Format,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 986942177)
    }
    width_ := width_
    height_ := height_
    use_mipmaps_ := use_mipmaps_
    format_ := format_
    args := []__bindgen_gde.TypePtr {
        &width_,
        &height_,
        &use_mipmaps_,
        &format_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}

image_create_empty :: proc "contextless" (
    width_: Int,
    height_: Int,
    use_mipmaps_: Bool,
    format_: Image_Format,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_empty", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 986942177)
    }
    width_ := width_
    height_ := height_
    use_mipmaps_ := use_mipmaps_
    format_ := format_
    args := []__bindgen_gde.TypePtr {
        &width_,
        &height_,
        &use_mipmaps_,
        &format_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}

image_create_from_data :: proc "contextless" (
    width_: Int,
    height_: Int,
    use_mipmaps_: Bool,
    format_: Image_Format,
    data_: Packed_Byte_Array,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_from_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 299398494)
    }
    width_ := width_
    height_ := height_
    use_mipmaps_ := use_mipmaps_
    format_ := format_
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &width_,
        &height_,
        &use_mipmaps_,
        &format_,
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}

image_load_from_file :: proc "contextless" (
    path_: String,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_from_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 736337515)
    }
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}


image_get_width :: proc "contextless" (
    self: Image,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_get_height :: proc "contextless" (
    self: Image,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_get_size :: proc "contextless" (
    self: Image,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_has_mipmaps :: proc "contextless" (
    self: Image,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_mipmaps", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_get_format :: proc "contextless" (
    self: Image,
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

image_get_data :: proc "contextless" (
    self: Image,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2362200018)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_get_data_size :: proc "contextless" (
    self: Image,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_data_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_convert :: proc "contextless" (
    self: Image,
    format_: Image_Format,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("convert", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2120693146)
    }
    self := self
    format_ := format_
    args := []__bindgen_gde.TypePtr {
        &format_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_get_mipmap_count :: proc "contextless" (
    self: Image,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mipmap_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_get_mipmap_offset :: proc "contextless" (
    self: Image,
    mipmap_: Int,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mipmap_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    mipmap_ := mipmap_
    args := []__bindgen_gde.TypePtr {
        &mipmap_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_resize_to_po2 :: proc "contextless" (
    self: Image,
    square_: Bool,
    interpolation_: Image_Interpolation,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("resize_to_po2", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4189212329)
    }
    self := self
    square_ := square_
    interpolation_ := interpolation_
    args := []__bindgen_gde.TypePtr {
        &square_,
        &interpolation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_resize :: proc "contextless" (
    self: Image,
    width_: Int,
    height_: Int,
    interpolation_: Image_Interpolation,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("resize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 994498151)
    }
    self := self
    width_ := width_
    height_ := height_
    interpolation_ := interpolation_
    args := []__bindgen_gde.TypePtr {
        &width_,
        &height_,
        &interpolation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_shrink_x2 :: proc "contextless" (
    self: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shrink_x2", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_crop :: proc "contextless" (
    self: Image,
    width_: Int,
    height_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("crop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    width_ := width_
    height_ := height_
    args := []__bindgen_gde.TypePtr {
        &width_,
        &height_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_flip_x :: proc "contextless" (
    self: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("flip_x", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_flip_y :: proc "contextless" (
    self: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("flip_y", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_generate_mipmaps :: proc "contextless" (
    self: Image,
    renormalize_: Bool,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generate_mipmaps", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1633102583)
    }
    self := self
    renormalize_ := renormalize_
    args := []__bindgen_gde.TypePtr {
        &renormalize_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_clear_mipmaps :: proc "contextless" (
    self: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_mipmaps", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_set_data :: proc "contextless" (
    self: Image,
    width_: Int,
    height_: Int,
    use_mipmaps_: Bool,
    format_: Image_Format,
    data_: Packed_Byte_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2740482212)
    }
    self := self
    width_ := width_
    height_ := height_
    use_mipmaps_ := use_mipmaps_
    format_ := format_
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &width_,
        &height_,
        &use_mipmaps_,
        &format_,
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_is_empty :: proc "contextless" (
    self: Image,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_empty", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_load :: proc "contextless" (
    self: Image,
    path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166001499)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_save_png :: proc "contextless" (
    self: Image,
    path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_png", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2113323047)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_save_png_to_buffer :: proc "contextless" (
    self: Image,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_png_to_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2362200018)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_save_jpg :: proc "contextless" (
    self: Image,
    path_: String,
    quality_: f64,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_jpg", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2800019068)
    }
    self := self
    path_ := path_
    quality_ := quality_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &quality_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_save_jpg_to_buffer :: proc "contextless" (
    self: Image,
    quality_: f64,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_jpg_to_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 592235273)
    }
    self := self
    quality_ := quality_
    args := []__bindgen_gde.TypePtr {
        &quality_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_save_exr :: proc "contextless" (
    self: Image,
    path_: String,
    grayscale_: Bool,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_exr", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3108122999)
    }
    self := self
    path_ := path_
    grayscale_ := grayscale_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &grayscale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_save_exr_to_buffer :: proc "contextless" (
    self: Image,
    grayscale_: Bool,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_exr_to_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3178917920)
    }
    self := self
    grayscale_ := grayscale_
    args := []__bindgen_gde.TypePtr {
        &grayscale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_save_dds :: proc "contextless" (
    self: Image,
    path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_dds", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2113323047)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_save_dds_to_buffer :: proc "contextless" (
    self: Image,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_dds_to_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2362200018)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_save_webp :: proc "contextless" (
    self: Image,
    path_: String,
    lossy_: Bool,
    quality_: f64,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_webp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2781156876)
    }
    self := self
    path_ := path_
    lossy_ := lossy_
    quality_ := quality_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &lossy_,
        &quality_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_save_webp_to_buffer :: proc "contextless" (
    self: Image,
    lossy_: Bool,
    quality_: f64,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_webp_to_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1214628238)
    }
    self := self
    lossy_ := lossy_
    quality_ := quality_
    args := []__bindgen_gde.TypePtr {
        &lossy_,
        &quality_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_detect_alpha :: proc "contextless" (
    self: Image,
) -> (ret: Image_Alpha_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("detect_alpha", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2030116505)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_is_invisible :: proc "contextless" (
    self: Image,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_invisible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_detect_used_channels :: proc "contextless" (
    self: Image,
    source_: Image_Compress_Source,
) -> (ret: Image_Used_Channels) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("detect_used_channels", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2703139984)
    }
    self := self
    source_ := source_
    args := []__bindgen_gde.TypePtr {
        &source_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_compress :: proc "contextless" (
    self: Image,
    mode_: Image_Compress_Mode,
    source_: Image_Compress_Source,
    astc_format_: Image_Astc_Format,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compress", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2975424957)
    }
    self := self
    mode_ := mode_
    source_ := source_
    astc_format_ := astc_format_
    args := []__bindgen_gde.TypePtr {
        &mode_,
        &source_,
        &astc_format_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_compress_from_channels :: proc "contextless" (
    self: Image,
    mode_: Image_Compress_Mode,
    channels_: Image_Used_Channels,
    astc_format_: Image_Astc_Format,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compress_from_channels", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4212890953)
    }
    self := self
    mode_ := mode_
    channels_ := channels_
    astc_format_ := astc_format_
    args := []__bindgen_gde.TypePtr {
        &mode_,
        &channels_,
        &astc_format_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_decompress :: proc "contextless" (
    self: Image,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decompress", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_is_compressed :: proc "contextless" (
    self: Image,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_compressed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_rotate_90 :: proc "contextless" (
    self: Image,
    direction_: Clock_Direction,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotate_90", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1901204267)
    }
    self := self
    direction_ := direction_
    args := []__bindgen_gde.TypePtr {
        &direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_rotate_180 :: proc "contextless" (
    self: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotate_180", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_fix_alpha_edges :: proc "contextless" (
    self: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("fix_alpha_edges", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_premultiply_alpha :: proc "contextless" (
    self: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("premultiply_alpha", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_srgb_to_linear :: proc "contextless" (
    self: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("srgb_to_linear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_linear_to_srgb :: proc "contextless" (
    self: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("linear_to_srgb", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_normal_map_to_xy :: proc "contextless" (
    self: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("normal_map_to_xy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_rgbe_to_srgb :: proc "contextless" (
    self: Image,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rgbe_to_srgb", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 564927088)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_bump_map_to_normal_map :: proc "contextless" (
    self: Image,
    bump_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bump_map_to_normal_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3423495036)
    }
    self := self
    bump_scale_ := bump_scale_
    args := []__bindgen_gde.TypePtr {
        &bump_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_compute_image_metrics :: proc "contextless" (
    self: Image,
    compared_image_: Image,
    use_luma_: Bool,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compute_image_metrics", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3080961247)
    }
    self := self
    compared_image_ := compared_image_
    use_luma_ := use_luma_
    args := []__bindgen_gde.TypePtr {
        &compared_image_,
        &use_luma_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_blit_rect :: proc "contextless" (
    self: Image,
    src_: Image,
    src_rect_: Rect2i,
    dst_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("blit_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2903928755)
    }
    self := self
    src_ := src_
    src_rect_ := src_rect_
    dst_ := dst_
    args := []__bindgen_gde.TypePtr {
        &src_,
        &src_rect_,
        &dst_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_blit_rect_mask :: proc "contextless" (
    self: Image,
    src_: Image,
    mask_: Image,
    src_rect_: Rect2i,
    dst_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("blit_rect_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3383581145)
    }
    self := self
    src_ := src_
    mask_ := mask_
    src_rect_ := src_rect_
    dst_ := dst_
    args := []__bindgen_gde.TypePtr {
        &src_,
        &mask_,
        &src_rect_,
        &dst_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_blend_rect :: proc "contextless" (
    self: Image,
    src_: Image,
    src_rect_: Rect2i,
    dst_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("blend_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2903928755)
    }
    self := self
    src_ := src_
    src_rect_ := src_rect_
    dst_ := dst_
    args := []__bindgen_gde.TypePtr {
        &src_,
        &src_rect_,
        &dst_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_blend_rect_mask :: proc "contextless" (
    self: Image,
    src_: Image,
    mask_: Image,
    src_rect_: Rect2i,
    dst_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("blend_rect_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3383581145)
    }
    self := self
    src_ := src_
    mask_ := mask_
    src_rect_ := src_rect_
    dst_ := dst_
    args := []__bindgen_gde.TypePtr {
        &src_,
        &mask_,
        &src_rect_,
        &dst_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_fill :: proc "contextless" (
    self: Image,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("fill", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_fill_rect :: proc "contextless" (
    self: Image,
    rect_: Rect2i,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("fill_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 514693913)
    }
    self := self
    rect_ := rect_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &rect_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_get_used_rect :: proc "contextless" (
    self: Image,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_used_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 410525958)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_get_region :: proc "contextless" (
    self: Image,
    region_: Rect2i,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2601441065)
    }
    self := self
    region_ := region_
    args := []__bindgen_gde.TypePtr {
        &region_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_copy_from :: proc "contextless" (
    self: Image,
    src_: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("copy_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 532598488)
    }
    self := self
    src_ := src_
    args := []__bindgen_gde.TypePtr {
        &src_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_get_pixelv :: proc "contextless" (
    self: Image,
    point_: Vector2i,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pixelv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1532707496)
    }
    self := self
    point_ := point_
    args := []__bindgen_gde.TypePtr {
        &point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_get_pixel :: proc "contextless" (
    self: Image,
    x_: Int,
    y_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pixel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2165839948)
    }
    self := self
    x_ := x_
    y_ := y_
    args := []__bindgen_gde.TypePtr {
        &x_,
        &y_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_set_pixelv :: proc "contextless" (
    self: Image,
    point_: Vector2i,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_pixelv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 287851464)
    }
    self := self
    point_ := point_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &point_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_set_pixel :: proc "contextless" (
    self: Image,
    x_: Int,
    y_: Int,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_pixel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3733378741)
    }
    self := self
    x_ := x_
    y_ := y_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &x_,
        &y_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_adjust_bcs :: proc "contextless" (
    self: Image,
    brightness_: f64,
    contrast_: f64,
    saturation_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("adjust_bcs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2385087082)
    }
    self := self
    brightness_ := brightness_
    contrast_ := contrast_
    saturation_ := saturation_
    args := []__bindgen_gde.TypePtr {
        &brightness_,
        &contrast_,
        &saturation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_load_png_from_buffer :: proc "contextless" (
    self: Image,
    buffer_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_png_from_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 680677267)
    }
    self := self
    buffer_ := buffer_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_load_jpg_from_buffer :: proc "contextless" (
    self: Image,
    buffer_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_jpg_from_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 680677267)
    }
    self := self
    buffer_ := buffer_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_load_webp_from_buffer :: proc "contextless" (
    self: Image,
    buffer_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_webp_from_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 680677267)
    }
    self := self
    buffer_ := buffer_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_load_tga_from_buffer :: proc "contextless" (
    self: Image,
    buffer_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_tga_from_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 680677267)
    }
    self := self
    buffer_ := buffer_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_load_bmp_from_buffer :: proc "contextless" (
    self: Image,
    buffer_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_bmp_from_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 680677267)
    }
    self := self
    buffer_ := buffer_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_load_ktx_from_buffer :: proc "contextless" (
    self: Image,
    buffer_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_ktx_from_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 680677267)
    }
    self := self
    buffer_ := buffer_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_load_dds_from_buffer :: proc "contextless" (
    self: Image,
    buffer_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_dds_from_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 680677267)
    }
    self := self
    buffer_ := buffer_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_load_exr_from_buffer :: proc "contextless" (
    self: Image,
    buffer_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_exr_from_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 680677267)
    }
    self := self
    buffer_ := buffer_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_load_svg_from_buffer :: proc "contextless" (
    self: Image,
    buffer_: Packed_Byte_Array,
    scale_: f64,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_svg_from_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 311853421)
    }
    self := self
    buffer_ := buffer_
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &buffer_,
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_load_svg_from_string :: proc "contextless" (
    self: Image,
    svg_str_: String,
    scale_: f64,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_svg_from_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3254053600)
    }
    self := self
    svg_str_ := svg_str_
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &svg_str_,
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
image_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Image", true)
}

@(private = "file")
__class_name: String_Name