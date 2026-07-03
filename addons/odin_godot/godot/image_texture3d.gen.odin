package godot

import __bindgen_gde "godot:gdext"

Image_Texture3d_Constants :: enum {
}



image_texture3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

image_texture3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_image_texture3d :: proc "contextless" () -> Image_Texture3d {
    return cast(Image_Texture3d)__bindgen_gde.classdb_construct_object(image_texture3d_name_ref())
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

image_texture3d_create :: proc "contextless" (
    self: Image_Texture3d,
    format_: Image_Format,
    width_: Int,
    height_: Int,
    depth_: Int,
    use_mipmaps_: Bool,
    data_: Typed_Array(Image),
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130379827)
    }
    self := self
    format_ := format_
    width_ := width_
    height_ := height_
    depth_ := depth_
    use_mipmaps_ := use_mipmaps_
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &format_,
        &width_,
        &height_,
        &depth_,
        &use_mipmaps_,
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_texture3d_update :: proc "contextless" (
    self: Image_Texture3d,
    data_: Typed_Array(Image),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
image_texture3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ImageTexture3D", true)
}

@(private = "file")
__class_name: String_Name