package godot

import __bindgen_gde "godot:gdext"

Resource_Format_Saver_Constants :: enum {
}



resource_format_saver_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

resource_format_saver_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_resource_format_saver :: proc "contextless" () -> Resource_Format_Saver {
    return cast(Resource_Format_Saver)__bindgen_gde.classdb_construct_object(resource_format_saver_name_ref())
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

resource_format_saver__save :: proc "contextless" (
    self: Resource_Format_Saver,
    resource_: Resource,
    path_: String,
    flags_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_save", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2794699034)
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

resource_format_saver__set_uid :: proc "contextless" (
    self: Resource_Format_Saver,
    path_: String,
    uid_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_uid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 993915709)
    }
    self := self
    path_ := path_
    uid_ := uid_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &uid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_format_saver__recognize :: proc "contextless" (
    self: Resource_Format_Saver,
    resource_: Resource,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_recognize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3190994482)
    }
    self := self
    resource_ := resource_
    args := []__bindgen_gde.TypePtr {
        &resource_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_format_saver__get_recognized_extensions :: proc "contextless" (
    self: Resource_Format_Saver,
    resource_: Resource,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_recognized_extensions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1567505034)
    }
    self := self
    resource_ := resource_
    args := []__bindgen_gde.TypePtr {
        &resource_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_format_saver__recognize_path :: proc "contextless" (
    self: Resource_Format_Saver,
    resource_: Resource,
    path_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_recognize_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 710996192)
    }
    self := self
    resource_ := resource_
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &resource_,
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
resource_format_saver_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ResourceFormatSaver", true)
}

@(private = "file")
__class_name: String_Name