package godot

import __bindgen_gde "godot:gdext"

Text_Server_Manager_Constants :: enum {
}



text_server_manager_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

text_server_manager_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_text_server_manager :: proc "contextless" () -> Text_Server_Manager {
    return cast(Text_Server_Manager)__bindgen_gde.classdb_construct_object(text_server_manager_name_ref())
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

text_server_manager_add_interface :: proc "contextless" (
    self: Text_Server_Manager,
    interface_: Text_Server,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_interface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1799689403)
    }
    self := self
    interface_ := interface_
    args := []__bindgen_gde.TypePtr {
        &interface_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_server_manager_get_interface_count :: proc "contextless" (
    self: Text_Server_Manager,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_interface_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_server_manager_remove_interface :: proc "contextless" (
    self: Text_Server_Manager,
    interface_: Text_Server,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_interface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1799689403)
    }
    self := self
    interface_ := interface_
    args := []__bindgen_gde.TypePtr {
        &interface_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_server_manager_get_interface :: proc "contextless" (
    self: Text_Server_Manager,
    idx_: Int,
) -> (ret: Text_Server) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_interface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1672475555)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_server_manager_get_interfaces :: proc "contextless" (
    self: Text_Server_Manager,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_interfaces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_server_manager_find_interface :: proc "contextless" (
    self: Text_Server_Manager,
    name_: String,
) -> (ret: Text_Server) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_interface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240905781)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_server_manager_set_primary_interface :: proc "contextless" (
    self: Text_Server_Manager,
    index_: Text_Server,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_primary_interface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1799689403)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_server_manager_get_primary_interface :: proc "contextless" (
    self: Text_Server_Manager,
) -> (ret: Text_Server) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_primary_interface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 905850878)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
text_server_manager_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("TextServerManager", true)
}

@(private = "file")
__class_name: String_Name