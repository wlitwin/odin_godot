package godot

import __bindgen_gde "godot:gdext"

Font_File_Constants :: enum {
}



font_file_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

font_file_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_font_file :: proc "contextless" () -> Font_File {
    return cast(Font_File)__bindgen_gde.classdb_construct_object(font_file_name_ref())
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

font_file_load_bitmap_font :: proc "contextless" (
    self: Font_File,
    path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_bitmap_font", true)
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

font_file_load_dynamic_font :: proc "contextless" (
    self: Font_File,
    path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_dynamic_font", true)
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

font_file_set_data :: proc "contextless" (
    self: Font_File,
    data_: Packed_Byte_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2971499966)
    }
    self := self
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_data :: proc "contextless" (
    self: Font_File,
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

font_file_set_font_name :: proc "contextless" (
    self: Font_File,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_font_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_set_font_style_name :: proc "contextless" (
    self: Font_File,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_font_style_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_set_font_style :: proc "contextless" (
    self: Font_File,
    style_: Text_Server_Font_Style,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_font_style", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 918070724)
    }
    self := self
    style_ := style_
    args := []__bindgen_gde.TypePtr {
        &style_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_set_font_weight :: proc "contextless" (
    self: Font_File,
    weight_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_font_weight", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    weight_ := weight_
    args := []__bindgen_gde.TypePtr {
        &weight_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_set_font_stretch :: proc "contextless" (
    self: Font_File,
    stretch_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_font_stretch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    stretch_ := stretch_
    args := []__bindgen_gde.TypePtr {
        &stretch_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_set_antialiasing :: proc "contextless" (
    self: Font_File,
    antialiasing_: Text_Server_Font_Antialiasing,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_antialiasing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1669900)
    }
    self := self
    antialiasing_ := antialiasing_
    args := []__bindgen_gde.TypePtr {
        &antialiasing_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_antialiasing :: proc "contextless" (
    self: Font_File,
) -> (ret: Text_Server_Font_Antialiasing) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_antialiasing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4262718649)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_disable_embedded_bitmaps :: proc "contextless" (
    self: Font_File,
    disable_embedded_bitmaps_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_disable_embedded_bitmaps", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    disable_embedded_bitmaps_ := disable_embedded_bitmaps_
    args := []__bindgen_gde.TypePtr {
        &disable_embedded_bitmaps_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_disable_embedded_bitmaps :: proc "contextless" (
    self: Font_File,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_disable_embedded_bitmaps", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_generate_mipmaps :: proc "contextless" (
    self: Font_File,
    generate_mipmaps_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_generate_mipmaps", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    generate_mipmaps_ := generate_mipmaps_
    args := []__bindgen_gde.TypePtr {
        &generate_mipmaps_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_generate_mipmaps :: proc "contextless" (
    self: Font_File,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_generate_mipmaps", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_multichannel_signed_distance_field :: proc "contextless" (
    self: Font_File,
    msdf_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_multichannel_signed_distance_field", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    msdf_ := msdf_
    args := []__bindgen_gde.TypePtr {
        &msdf_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_is_multichannel_signed_distance_field :: proc "contextless" (
    self: Font_File,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_multichannel_signed_distance_field", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_msdf_pixel_range :: proc "contextless" (
    self: Font_File,
    msdf_pixel_range_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_msdf_pixel_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    msdf_pixel_range_ := msdf_pixel_range_
    args := []__bindgen_gde.TypePtr {
        &msdf_pixel_range_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_msdf_pixel_range :: proc "contextless" (
    self: Font_File,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_msdf_pixel_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_msdf_size :: proc "contextless" (
    self: Font_File,
    msdf_size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_msdf_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    msdf_size_ := msdf_size_
    args := []__bindgen_gde.TypePtr {
        &msdf_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_msdf_size :: proc "contextless" (
    self: Font_File,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_msdf_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_fixed_size :: proc "contextless" (
    self: Font_File,
    fixed_size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fixed_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    fixed_size_ := fixed_size_
    args := []__bindgen_gde.TypePtr {
        &fixed_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_fixed_size :: proc "contextless" (
    self: Font_File,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fixed_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_fixed_size_scale_mode :: proc "contextless" (
    self: Font_File,
    fixed_size_scale_mode_: Text_Server_Fixed_Size_Scale_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fixed_size_scale_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1660989956)
    }
    self := self
    fixed_size_scale_mode_ := fixed_size_scale_mode_
    args := []__bindgen_gde.TypePtr {
        &fixed_size_scale_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_fixed_size_scale_mode :: proc "contextless" (
    self: Font_File,
) -> (ret: Text_Server_Fixed_Size_Scale_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fixed_size_scale_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 753873478)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_allow_system_fallback :: proc "contextless" (
    self: Font_File,
    allow_system_fallback_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_allow_system_fallback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    allow_system_fallback_ := allow_system_fallback_
    args := []__bindgen_gde.TypePtr {
        &allow_system_fallback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_is_allow_system_fallback :: proc "contextless" (
    self: Font_File,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_allow_system_fallback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_force_autohinter :: proc "contextless" (
    self: Font_File,
    force_autohinter_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_force_autohinter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    force_autohinter_ := force_autohinter_
    args := []__bindgen_gde.TypePtr {
        &force_autohinter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_is_force_autohinter :: proc "contextless" (
    self: Font_File,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_force_autohinter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_modulate_color_glyphs :: proc "contextless" (
    self: Font_File,
    modulate_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_modulate_color_glyphs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    modulate_ := modulate_
    args := []__bindgen_gde.TypePtr {
        &modulate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_is_modulate_color_glyphs :: proc "contextless" (
    self: Font_File,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_modulate_color_glyphs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_hinting :: proc "contextless" (
    self: Font_File,
    hinting_: Text_Server_Hinting,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hinting", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1827459492)
    }
    self := self
    hinting_ := hinting_
    args := []__bindgen_gde.TypePtr {
        &hinting_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_hinting :: proc "contextless" (
    self: Font_File,
) -> (ret: Text_Server_Hinting) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hinting", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3683214614)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_subpixel_positioning :: proc "contextless" (
    self: Font_File,
    subpixel_positioning_: Text_Server_Subpixel_Positioning,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_subpixel_positioning", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4225742182)
    }
    self := self
    subpixel_positioning_ := subpixel_positioning_
    args := []__bindgen_gde.TypePtr {
        &subpixel_positioning_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_subpixel_positioning :: proc "contextless" (
    self: Font_File,
) -> (ret: Text_Server_Subpixel_Positioning) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_subpixel_positioning", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1069238588)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_keep_rounding_remainders :: proc "contextless" (
    self: Font_File,
    keep_rounding_remainders_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_keep_rounding_remainders", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    keep_rounding_remainders_ := keep_rounding_remainders_
    args := []__bindgen_gde.TypePtr {
        &keep_rounding_remainders_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_keep_rounding_remainders :: proc "contextless" (
    self: Font_File,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_keep_rounding_remainders", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_oversampling :: proc "contextless" (
    self: Font_File,
    oversampling_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_oversampling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    oversampling_ := oversampling_
    args := []__bindgen_gde.TypePtr {
        &oversampling_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_oversampling :: proc "contextless" (
    self: Font_File,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_oversampling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_get_cache_count :: proc "contextless" (
    self: Font_File,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cache_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_clear_cache :: proc "contextless" (
    self: Font_File,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_cache", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_remove_cache :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_cache", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    cache_index_ := cache_index_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_size_cache_list :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
) -> (ret: Typed_Array(Vector2i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_size_cache_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 663333327)
    }
    self := self
    cache_index_ := cache_index_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_clear_size_cache :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_size_cache", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    cache_index_ := cache_index_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_remove_size_cache :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_size_cache", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2311374912)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_set_variation_coordinates :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    variation_coordinates_: Dictionary,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_variation_coordinates", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 64545446)
    }
    self := self
    cache_index_ := cache_index_
    variation_coordinates_ := variation_coordinates_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &variation_coordinates_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_variation_coordinates :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_variation_coordinates", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3485342025)
    }
    self := self
    cache_index_ := cache_index_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_embolden :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    strength_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_embolden", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    cache_index_ := cache_index_
    strength_ := strength_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &strength_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_embolden :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_embolden", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    cache_index_ := cache_index_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_transform :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    transform_: Transform2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 30160968)
    }
    self := self
    cache_index_ := cache_index_
    transform_ := transform_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &transform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_transform :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3836996910)
    }
    self := self
    cache_index_ := cache_index_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_extra_spacing :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    spacing_: Text_Server_Spacing_Type,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_extra_spacing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 62942285)
    }
    self := self
    cache_index_ := cache_index_
    spacing_ := spacing_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &spacing_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_extra_spacing :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    spacing_: Text_Server_Spacing_Type,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_extra_spacing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1924257185)
    }
    self := self
    cache_index_ := cache_index_
    spacing_ := spacing_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &spacing_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_extra_baseline_offset :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    baseline_offset_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_extra_baseline_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    cache_index_ := cache_index_
    baseline_offset_ := baseline_offset_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &baseline_offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_extra_baseline_offset :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_extra_baseline_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    cache_index_ := cache_index_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_face_index :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    face_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_face_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    cache_index_ := cache_index_
    face_index_ := face_index_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &face_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_face_index :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_face_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    cache_index_ := cache_index_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_cache_ascent :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
    ascent_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cache_ascent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    ascent_ := ascent_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &ascent_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_cache_ascent :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cache_ascent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_cache_descent :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
    descent_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cache_descent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    descent_ := descent_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &descent_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_cache_descent :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cache_descent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_cache_underline_position :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
    underline_position_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cache_underline_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    underline_position_ := underline_position_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &underline_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_cache_underline_position :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cache_underline_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_cache_underline_thickness :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
    underline_thickness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cache_underline_thickness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    underline_thickness_ := underline_thickness_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &underline_thickness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_cache_underline_thickness :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cache_underline_thickness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_cache_scale :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
    scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cache_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_cache_scale :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cache_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_get_texture_count :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1987661582)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_clear_textures :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_textures", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2311374912)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_remove_texture :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    texture_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2328951467)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    texture_index_ := texture_index_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &texture_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_set_texture_image :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    texture_index_: Int,
    image_: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_image", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4157974066)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    texture_index_ := texture_index_
    image_ := image_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &texture_index_,
        &image_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_texture_image :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    texture_index_: Int,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_image", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3878418953)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    texture_index_ := texture_index_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &texture_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_texture_offsets :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    texture_index_: Int,
    offset_: Packed_Int32_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_offsets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2849993437)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    texture_index_ := texture_index_
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &texture_index_,
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_texture_offsets :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    texture_index_: Int,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_offsets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3703444828)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    texture_index_ := texture_index_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &texture_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_get_glyph_list :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_glyph_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 681709689)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_clear_glyphs :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_glyphs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2311374912)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_remove_glyph :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    glyph_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_glyph", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2328951467)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_ := glyph_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_set_glyph_advance :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
    glyph_: Int,
    advance_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_glyph_advance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 947991729)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_ := glyph_
    advance_ := advance_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_,
        &advance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_glyph_advance :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
    glyph_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_glyph_advance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1601573536)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_ := glyph_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_glyph_offset :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    glyph_: Int,
    offset_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_glyph_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 921719850)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_ := glyph_
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_,
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_glyph_offset :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    glyph_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_glyph_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3205412300)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_ := glyph_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_glyph_size :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    glyph_: Int,
    gl_size_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_glyph_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 921719850)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_ := glyph_
    gl_size_ := gl_size_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_,
        &gl_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_glyph_size :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    glyph_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_glyph_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3205412300)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_ := glyph_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_glyph_uv_rect :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    glyph_: Int,
    uv_rect_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_glyph_uv_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3821620992)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_ := glyph_
    uv_rect_ := uv_rect_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_,
        &uv_rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_glyph_uv_rect :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    glyph_: Int,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_glyph_uv_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927917900)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_ := glyph_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_glyph_texture_idx :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    glyph_: Int,
    texture_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_glyph_texture_idx", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 355564111)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_ := glyph_
    texture_idx_ := texture_idx_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_,
        &texture_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_glyph_texture_idx :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    glyph_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_glyph_texture_idx", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1629411054)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_ := glyph_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_get_kerning_list :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
) -> (ret: Typed_Array(Vector2i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_kerning_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2345056839)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_clear_kerning_map :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_kerning_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_remove_kerning :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
    glyph_pair_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_kerning", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3930204747)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_pair_ := glyph_pair_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_pair_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_set_kerning :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
    glyph_pair_: Vector2i,
    kerning_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_kerning", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3182200918)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_pair_ := glyph_pair_
    kerning_ := kerning_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_pair_,
        &kerning_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_kerning :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Int,
    glyph_pair_: Vector2i,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_kerning", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1611912865)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    glyph_pair_ := glyph_pair_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &glyph_pair_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_render_range :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    start_: Int,
    end_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 355564111)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    start_ := start_
    end_ := end_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &start_,
        &end_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_render_glyph :: proc "contextless" (
    self: Font_File,
    cache_index_: Int,
    size_: Vector2i,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("render_glyph", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2328951467)
    }
    self := self
    cache_index_ := cache_index_
    size_ := size_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &cache_index_,
        &size_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_set_language_support_override :: proc "contextless" (
    self: Font_File,
    language_: String,
    supported_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_language_support_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2678287736)
    }
    self := self
    language_ := language_
    supported_ := supported_
    args := []__bindgen_gde.TypePtr {
        &language_,
        &supported_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_language_support_override :: proc "contextless" (
    self: Font_File,
    language_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_language_support_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    language_ := language_
    args := []__bindgen_gde.TypePtr {
        &language_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_remove_language_support_override :: proc "contextless" (
    self: Font_File,
    language_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_language_support_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    language_ := language_
    args := []__bindgen_gde.TypePtr {
        &language_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_language_support_overrides :: proc "contextless" (
    self: Font_File,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_language_support_overrides", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_script_support_override :: proc "contextless" (
    self: Font_File,
    script_: String,
    supported_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_script_support_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2678287736)
    }
    self := self
    script_ := script_
    supported_ := supported_
    args := []__bindgen_gde.TypePtr {
        &script_,
        &supported_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_script_support_override :: proc "contextless" (
    self: Font_File,
    script_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_script_support_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    script_ := script_
    args := []__bindgen_gde.TypePtr {
        &script_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_remove_script_support_override :: proc "contextless" (
    self: Font_File,
    script_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_script_support_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    script_ := script_
    args := []__bindgen_gde.TypePtr {
        &script_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_script_support_overrides :: proc "contextless" (
    self: Font_File,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_script_support_overrides", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_set_opentype_feature_overrides :: proc "contextless" (
    self: Font_File,
    overrides_: Dictionary,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_opentype_feature_overrides", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155329257)
    }
    self := self
    overrides_ := overrides_
    args := []__bindgen_gde.TypePtr {
        &overrides_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_file_get_opentype_feature_overrides :: proc "contextless" (
    self: Font_File,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_opentype_feature_overrides", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_get_glyph_index :: proc "contextless" (
    self: Font_File,
    size_: Int,
    char_: Int,
    variation_selector_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_glyph_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 864943070)
    }
    self := self
    size_ := size_
    char_ := char_
    variation_selector_ := variation_selector_
    args := []__bindgen_gde.TypePtr {
        &size_,
        &char_,
        &variation_selector_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_file_get_char_from_glyph_index :: proc "contextless" (
    self: Font_File,
    size_: Int,
    glyph_index_: Int,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_char_from_glyph_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175239445)
    }
    self := self
    size_ := size_
    glyph_index_ := glyph_index_
    args := []__bindgen_gde.TypePtr {
        &size_,
        &glyph_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
font_file_get_multichannel_signed_distance_field :: proc "contextless" (self: Font_File) -> Bool {
    return font_file_is_multichannel_signed_distance_field(self)
}
font_file_get_allow_system_fallback :: proc "contextless" (self: Font_File) -> Bool {
    return font_file_is_allow_system_fallback(self)
}
font_file_get_force_autohinter :: proc "contextless" (self: Font_File) -> Bool {
    return font_file_is_force_autohinter(self)
}
font_file_get_modulate_color_glyphs :: proc "contextless" (self: Font_File) -> Bool {
    return font_file_is_modulate_color_glyphs(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
font_file_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("FontFile", true)
}

@(private = "file")
__class_name: String_Name