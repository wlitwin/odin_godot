package godot

import __bindgen_gde "godot:gdext"

Resource_Format_Loader_Constants :: enum {
}
Resource_Format_Loader_Cache_Mode :: enum int {
    Cache_Mode_Ignore = 0,
    Cache_Mode_Reuse = 1,
    Cache_Mode_Replace = 2,
    Cache_Mode_Ignore_Deep = 3,
    Cache_Mode_Replace_Deep = 4,
}



resource_format_loader_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

resource_format_loader_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_resource_format_loader :: proc "contextless" () -> Resource_Format_Loader {
    return cast(Resource_Format_Loader)__bindgen_gde.classdb_construct_object(resource_format_loader_name_ref())
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

resource_format_loader__get_recognized_extensions :: proc "contextless" (
    self: Resource_Format_Loader,
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

resource_format_loader__recognize_path :: proc "contextless" (
    self: Resource_Format_Loader,
    path_: String,
    type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_recognize_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2594487047)
    }
    self := self
    path_ := path_
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_format_loader__handles_type :: proc "contextless" (
    self: Resource_Format_Loader,
    type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_handles_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_format_loader__get_resource_type :: proc "contextless" (
    self: Resource_Format_Loader,
    path_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_resource_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3135753539)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_format_loader__get_resource_script_class :: proc "contextless" (
    self: Resource_Format_Loader,
    path_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_resource_script_class", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3135753539)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_format_loader__get_resource_uid :: proc "contextless" (
    self: Resource_Format_Loader,
    path_: String,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_resource_uid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1321353865)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_format_loader__get_dependencies :: proc "contextless" (
    self: Resource_Format_Loader,
    path_: String,
    add_types_: Bool,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_dependencies", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 6257701)
    }
    self := self
    path_ := path_
    add_types_ := add_types_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &add_types_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_format_loader__rename_dependencies :: proc "contextless" (
    self: Resource_Format_Loader,
    path_: String,
    renames_: Dictionary,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_rename_dependencies", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 223715120)
    }
    self := self
    path_ := path_
    renames_ := renames_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &renames_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_format_loader__exists :: proc "contextless" (
    self: Resource_Format_Loader,
    path_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_exists", true)
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

resource_format_loader__get_classes_used :: proc "contextless" (
    self: Resource_Format_Loader,
    path_: String,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_classes_used", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4291131558)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_format_loader__load :: proc "contextless" (
    self: Resource_Format_Loader,
    path_: String,
    original_path_: String,
    use_sub_threads_: Bool,
    cache_mode_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_load", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2885906527)
    }
    self := self
    path_ := path_
    original_path_ := original_path_
    use_sub_threads_ := use_sub_threads_
    cache_mode_ := cache_mode_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &original_path_,
        &use_sub_threads_,
        &cache_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
resource_format_loader_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ResourceFormatLoader", true)
}

@(private = "file")
__class_name: String_Name