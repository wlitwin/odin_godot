package godot

import __bindgen_gde "godot:gdext"

Ip_Constants :: enum {
    RESOLVER_MAX_QUERIES = 256,
    RESOLVER_INVALID_ID = -1,
}
Ip_Resolver_Status :: enum int {
    Resolver_Status_None = 0,
    Resolver_Status_Waiting = 1,
    Resolver_Status_Done = 2,
    Resolver_Status_Error = 3,
}
Ip_Type :: enum int {
    Type_None = 0,
    Type_Ipv4 = 1,
    Type_Ipv6 = 2,
    Type_Any = 3,
}



ip_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

ip_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_ip :: proc "contextless" () -> Ip {
    return __bindgen_gde.classdb_construct_object(ip_name_ref())
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

ip_resolve_hostname :: proc "contextless" (
    self: Ip,
    host_: String,
    ip_type_: Ip_Type,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("resolve_hostname", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4283295457)
    }
    self := self
    host_ := host_
    ip_type_ := ip_type_
    args := []__bindgen_gde.TypePtr {
        &host_,
        &ip_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

ip_resolve_hostname_addresses :: proc "contextless" (
    self: Ip,
    host_: String,
    ip_type_: Ip_Type,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("resolve_hostname_addresses", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 773767525)
    }
    self := self
    host_ := host_
    ip_type_ := ip_type_
    args := []__bindgen_gde.TypePtr {
        &host_,
        &ip_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

ip_resolve_hostname_queue_item :: proc "contextless" (
    self: Ip,
    host_: String,
    ip_type_: Ip_Type,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("resolve_hostname_queue_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1749894742)
    }
    self := self
    host_ := host_
    ip_type_ := ip_type_
    args := []__bindgen_gde.TypePtr {
        &host_,
        &ip_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

ip_get_resolve_item_status :: proc "contextless" (
    self: Ip,
    id_: Int,
) -> (ret: Ip_Resolver_Status) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_resolve_item_status", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3812250196)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

ip_get_resolve_item_address :: proc "contextless" (
    self: Ip,
    id_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_resolve_item_address", true)
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

ip_get_resolve_item_addresses :: proc "contextless" (
    self: Ip,
    id_: Int,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_resolve_item_addresses", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 663333327)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

ip_erase_resolve_item :: proc "contextless" (
    self: Ip,
    id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase_resolve_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

ip_get_local_addresses :: proc "contextless" (
    self: Ip,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_local_addresses", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

ip_get_local_interfaces :: proc "contextless" (
    self: Ip,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_local_interfaces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

ip_clear_cache :: proc "contextless" (
    self: Ip,
    hostname_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_cache", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3005725572)
    }
    self := self
    hostname_ := hostname_
    args := []__bindgen_gde.TypePtr {
        &hostname_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
ip_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("IP", true)
}

@(private = "file")
__class_name: String_Name