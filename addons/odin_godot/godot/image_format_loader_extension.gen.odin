package godot

import __bindgen_gde "godot:gdext"

Image_Format_Loader_Extension_Constants :: enum {
}



image_format_loader_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

image_format_loader_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_image_format_loader_extension :: proc "contextless" () -> Image_Format_Loader_Extension {
    return cast(Image_Format_Loader_Extension)__bindgen_gde.classdb_construct_object(image_format_loader_extension_name_ref())
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

image_format_loader_extension__get_recognized_extensions :: proc "contextless" (
    self: Image_Format_Loader_Extension,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_recognized_extensions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_format_loader_extension__load_image :: proc "contextless" (
    self: Image_Format_Loader_Extension,
    image_: Image,
    fileaccess_: File_Access,
    flags_: Image_Format_Loader_Loader_Flags,
    scale_: f64,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_load_image", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3760540541)
    }
    self := self
    image_ := image_
    fileaccess_ := fileaccess_
    flags_ := flags_
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &image_,
        &fileaccess_,
        &flags_,
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

image_format_loader_extension_add_format_loader :: proc "contextless" (
    self: Image_Format_Loader_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_format_loader", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

image_format_loader_extension_remove_format_loader :: proc "contextless" (
    self: Image_Format_Loader_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_format_loader", true)
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
image_format_loader_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ImageFormatLoaderExtension", true)
}

@(private = "file")
__class_name: String_Name