package godot

import __bindgen_gde "godot:gdext"

Resource_Loader_Constants :: enum {
}
Resource_Loader_Thread_Load_Status :: enum int {
    Thread_Load_Invalid_Resource = 0,
    Thread_Load_In_Progress = 1,
    Thread_Load_Failed = 2,
    Thread_Load_Loaded = 3,
}
Resource_Loader_Cache_Mode :: enum int {
    Cache_Mode_Ignore = 0,
    Cache_Mode_Reuse = 1,
    Cache_Mode_Replace = 2,
    Cache_Mode_Ignore_Deep = 3,
    Cache_Mode_Replace_Deep = 4,
}



resource_loader_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

resource_loader_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_resource_loader :: proc "contextless" () -> Resource_Loader {
    return __bindgen_gde.classdb_construct_object(resource_loader_name_ref())
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

resource_loader_load_threaded_request :: proc "contextless" (
    self: Resource_Loader,
    path_: String,
    type_hint_: String,
    use_sub_threads_: Bool,
    cache_mode_: Resource_Loader_Cache_Mode,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_threaded_request", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3614384323)
    }
    self := self
    path_ := path_
    type_hint_ := type_hint_
    use_sub_threads_ := use_sub_threads_
    cache_mode_ := cache_mode_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &type_hint_,
        &use_sub_threads_,
        &cache_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_loader_load_threaded_get_status :: proc "contextless" (
    self: Resource_Loader,
    path_: String,
    progress_: Array,
) -> (ret: Resource_Loader_Thread_Load_Status) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_threaded_get_status", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4137685479)
    }
    self := self
    path_ := path_
    progress_ := progress_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &progress_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_loader_load_threaded_get :: proc "contextless" (
    self: Resource_Loader,
    path_: String,
) -> (ret: Resource) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_threaded_get", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1748875256)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_loader_load :: proc "contextless" (
    self: Resource_Loader,
    path_: String,
    type_hint_: String,
    cache_mode_: Resource_Loader_Cache_Mode,
) -> (ret: Resource) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3358495409)
    }
    self := self
    path_ := path_
    type_hint_ := type_hint_
    cache_mode_ := cache_mode_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &type_hint_,
        &cache_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_loader_get_recognized_extensions_for_type :: proc "contextless" (
    self: Resource_Loader,
    type_: String,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_recognized_extensions_for_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3538744774)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_loader_add_resource_format_loader :: proc "contextless" (
    self: Resource_Loader,
    format_loader_: Resource_Format_Loader,
    at_front_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_resource_format_loader", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2896595483)
    }
    self := self
    format_loader_ := format_loader_
    at_front_ := at_front_
    args := []__bindgen_gde.TypePtr {
        &format_loader_,
        &at_front_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

resource_loader_remove_resource_format_loader :: proc "contextless" (
    self: Resource_Loader,
    format_loader_: Resource_Format_Loader,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_resource_format_loader", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 405397102)
    }
    self := self
    format_loader_ := format_loader_
    args := []__bindgen_gde.TypePtr {
        &format_loader_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

resource_loader_set_abort_on_missing_resources :: proc "contextless" (
    self: Resource_Loader,
    abort_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_abort_on_missing_resources", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    abort_ := abort_
    args := []__bindgen_gde.TypePtr {
        &abort_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

resource_loader_get_dependencies :: proc "contextless" (
    self: Resource_Loader,
    path_: String,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_dependencies", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3538744774)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_loader_has_cached :: proc "contextless" (
    self: Resource_Loader,
    path_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_cached", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2323990056)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_loader_get_cached_ref :: proc "contextless" (
    self: Resource_Loader,
    path_: String,
) -> (ret: Resource) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cached_ref", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1748875256)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_loader_exists :: proc "contextless" (
    self: Resource_Loader,
    path_: String,
    type_hint_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("exists", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4185558881)
    }
    self := self
    path_ := path_
    type_hint_ := type_hint_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &type_hint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

resource_loader_get_resource_uid :: proc "contextless" (
    self: Resource_Loader,
    path_: String,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_resource_uid", true)
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

resource_loader_list_directory :: proc "contextless" (
    self: Resource_Loader,
    directory_path_: String,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("list_directory", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3538744774)
    }
    self := self
    directory_path_ := directory_path_
    args := []__bindgen_gde.TypePtr {
        &directory_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
resource_loader_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ResourceLoader", true)
}

@(private = "file")
__class_name: String_Name