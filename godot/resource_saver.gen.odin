package godot

import __bindgen_gde "godot:gdext"

Resource_Saver_Constants :: enum {
}

Resource_Saver_Saver_Flags :: enum i64 {
    Flag_None = 0,
    Flag_Relative_Paths = 1,
    Flag_Bundle_Resources = 2,
    Flag_Change_Path = 4,
    Flag_Omit_Editor_Properties = 8,
    Flag_Save_Big_Endian = 16,
    Flag_Compress = 32,
    Flag_Replace_Subresource_Paths = 64,
}


resource_saver_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

resource_saver_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_resource_saver :: proc "contextless" () -> Resource_Saver {
    return __bindgen_gde.classdb_construct_object(resource_saver_name_ref())
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

resource_saver_save :: proc "contextless" (
    self: Resource_Saver,
    resource_: Resource,
    path_: String,
    flags_: Resource_Saver_Saver_Flags,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2983274697)
    }
    self := self
    resource_ := resource_
    path_ := path_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &resource_,
        &path_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_saver_set_uid :: proc "contextless" (
    self: Resource_Saver,
    resource_: String,
    uid_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_uid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 993915709)
    }
    self := self
    resource_ := resource_
    uid_ := uid_
    args := []__bindgen_gde.TypePtr {
        &resource_,
        &uid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_saver_get_recognized_extensions :: proc "contextless" (
    self: Resource_Saver,
    type_: Resource,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_recognized_extensions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4223597960)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_saver_add_resource_format_saver :: proc "contextless" (
    self: Resource_Saver,
    format_saver_: Resource_Format_Saver,
    at_front_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_resource_format_saver", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 362894272)
    }
    self := self
    format_saver_ := format_saver_
    at_front_ := at_front_
    args := []__bindgen_gde.TypePtr {
        &format_saver_,
        &at_front_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

resource_saver_remove_resource_format_saver :: proc "contextless" (
    self: Resource_Saver,
    format_saver_: Resource_Format_Saver,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_resource_format_saver", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3373026878)
    }
    self := self
    format_saver_ := format_saver_
    args := []__bindgen_gde.TypePtr {
        &format_saver_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

resource_saver_get_resource_id_for_path :: proc "contextless" (
    self: Resource_Saver,
    path_: String,
    generate_: Bool,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_resource_id_for_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 150756522)
    }
    self := self
    path_ := path_
    generate_ := generate_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &generate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
resource_saver_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ResourceSaver", true)
}

@(private = "file")
__class_name: String_Name