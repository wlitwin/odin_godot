package godot

import __bindgen_gde "godot:gdext"

Image_Texture_Layered_Constants :: enum {
}



image_texture_layered_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

image_texture_layered_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_image_texture_layered :: proc "contextless" () -> Image_Texture_Layered {
    return cast(Image_Texture_Layered)__bindgen_gde.classdb_construct_object(image_texture_layered_name_ref())
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

image_texture_layered_create_from_images :: proc "contextless" (
    self: Image_Texture_Layered,
    images_: Typed_Array(Image),
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_from_images", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2785773503)
    }
    self := self
    images_ := images_
    args := []__bindgen_gde.TypePtr {
        &images_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_texture_layered_update_layer :: proc "contextless" (
    self: Image_Texture_Layered,
    image_: Image,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3331733361)
    }
    self := self
    image_ := image_
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &image_,
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
image_texture_layered_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ImageTextureLayered", true)
}

@(private = "file")
__class_name: String_Name