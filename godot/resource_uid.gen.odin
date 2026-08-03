package godot

import __bindgen_gde "godot:gdext"

Resource_Uid_Constants :: enum {
    INVALID_ID = -1,
}



resource_uid_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

resource_uid_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_resource_uid :: proc "contextless" () -> Resource_Uid {
    return cast(Resource_Uid)__bindgen_gde.classdb_construct_object(resource_uid_name_ref())
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
resource_uid_uid_to_path :: proc "contextless" (
    uid_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("uid_to_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1703090593)
    }
    uid_ := uid_
    args := []__bindgen_gde.TypePtr {
        &uid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}

resource_uid_path_to_uid :: proc "contextless" (
    path_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("path_to_uid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1703090593)
    }
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}

resource_uid_ensure_path :: proc "contextless" (
    path_or_uid_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ensure_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1703090593)
    }
    path_or_uid_ := path_or_uid_
    args := []__bindgen_gde.TypePtr {
        &path_or_uid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}


resource_uid_id_to_text :: proc "contextless" (
    self: Resource_Uid,
    id_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("id_to_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_uid_text_to_id :: proc "contextless" (
    self: Resource_Uid,
    text_id_: String,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("text_to_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1321353865)
    }
    self := self
    text_id_ := text_id_
    args := []__bindgen_gde.TypePtr {
        &text_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_uid_create_id :: proc "contextless" (
    self: Resource_Uid,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_uid_create_id_for_path :: proc "contextless" (
    self: Resource_Uid,
    path_: String,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_id_for_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1597066294)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_uid_has_id :: proc "contextless" (
    self: Resource_Uid,
    id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_uid_add_id :: proc "contextless" (
    self: Resource_Uid,
    id_: Int,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    id_ := id_
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

resource_uid_set_id :: proc "contextless" (
    self: Resource_Uid,
    id_: Int,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    id_ := id_
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

resource_uid_get_id_path :: proc "contextless" (
    self: Resource_Uid,
    id_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_id_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_uid_remove_id :: proc "contextless" (
    self: Resource_Uid,
    id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
resource_uid_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ResourceUID", true)
}

@(private = "file")
__class_name: String_Name