package godot

import __bindgen_gde "godot:gdext"

Drawable_Texture2d_Constants :: enum {
}
Drawable_Texture2d_Drawable_Format :: enum int {
    Drawable_Format_Rgba8 = 0,
    Drawable_Format_Rgba8_Srgb = 1,
    Drawable_Format_Rgbah = 2,
    Drawable_Format_Rgbaf = 3,
}



drawable_texture2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

drawable_texture2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_drawable_texture2d :: proc "contextless" () -> Drawable_Texture2d {
    return cast(Drawable_Texture2d)__bindgen_gde.classdb_construct_object(drawable_texture2d_name_ref())
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

drawable_texture2d_set_format :: proc "contextless" (
    self: Drawable_Texture2d,
    format_: Drawable_Texture2d_Drawable_Format,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2875673594)
    }
    self := self
    format_ := format_
    args := []__bindgen_gde.TypePtr {
        &format_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

drawable_texture2d_set_use_mipmaps :: proc "contextless" (
    self: Drawable_Texture2d,
    mipmaps_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_mipmaps", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    mipmaps_ := mipmaps_
    args := []__bindgen_gde.TypePtr {
        &mipmaps_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

drawable_texture2d_get_use_mipmaps :: proc "contextless" (
    self: Drawable_Texture2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_use_mipmaps", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

drawable_texture2d_setup :: proc "contextless" (
    self: Drawable_Texture2d,
    width_: Int,
    height_: Int,
    format_: Drawable_Texture2d_Drawable_Format,
    color_: Color,
    use_mipmaps_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("setup", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 674365339)
    }
    self := self
    width_ := width_
    height_ := height_
    format_ := format_
    color_ := color_
    use_mipmaps_ := use_mipmaps_
    args := []__bindgen_gde.TypePtr {
        &width_,
        &height_,
        &format_,
        &color_,
        &use_mipmaps_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

drawable_texture2d_blit_rect :: proc "contextless" (
    self: Drawable_Texture2d,
    rect_: Rect2i,
    source_: Texture2d,
    modulate_: Color,
    mipmap_: Int,
    material_: Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("blit_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 319217173)
    }
    self := self
    rect_ := rect_
    source_ := source_
    modulate_ := modulate_
    mipmap_ := mipmap_
    material_ := material_
    args := []__bindgen_gde.TypePtr {
        &rect_,
        &source_,
        &modulate_,
        &mipmap_,
        &material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

drawable_texture2d_blit_rect_multi :: proc "contextless" (
    self: Drawable_Texture2d,
    rect_: Rect2i,
    sources_: Typed_Array(Texture2d),
    extra_targets_: Typed_Array(Drawable_Texture2d),
    modulate_: Color,
    mipmap_: Int,
    material_: Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("blit_rect_multi", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3074783066)
    }
    self := self
    rect_ := rect_
    sources_ := sources_
    extra_targets_ := extra_targets_
    modulate_ := modulate_
    mipmap_ := mipmap_
    material_ := material_
    args := []__bindgen_gde.TypePtr {
        &rect_,
        &sources_,
        &extra_targets_,
        &modulate_,
        &mipmap_,
        &material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

drawable_texture2d_generate_mipmaps :: proc "contextless" (
    self: Drawable_Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generate_mipmaps", true)
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
drawable_texture2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("DrawableTexture2D", true)
}

@(private = "file")
__class_name: String_Name