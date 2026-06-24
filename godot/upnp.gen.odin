package godot

import __bindgen_gde "godot:gdext"

Upnp_Constants :: enum {
}
Upnpupnp_Result :: enum int {
    Upnp_Result_Success = 0,
    Upnp_Result_Not_Authorized = 1,
    Upnp_Result_Port_Mapping_Not_Found = 2,
    Upnp_Result_Inconsistent_Parameters = 3,
    Upnp_Result_No_Such_Entry_In_Array = 4,
    Upnp_Result_Action_Failed = 5,
    Upnp_Result_Src_Ip_Wildcard_Not_Permitted = 6,
    Upnp_Result_Ext_Port_Wildcard_Not_Permitted = 7,
    Upnp_Result_Int_Port_Wildcard_Not_Permitted = 8,
    Upnp_Result_Remote_Host_Must_Be_Wildcard = 9,
    Upnp_Result_Ext_Port_Must_Be_Wildcard = 10,
    Upnp_Result_No_Port_Maps_Available = 11,
    Upnp_Result_Conflict_With_Other_Mechanism = 12,
    Upnp_Result_Conflict_With_Other_Mapping = 13,
    Upnp_Result_Same_Port_Values_Required = 14,
    Upnp_Result_Only_Permanent_Lease_Supported = 15,
    Upnp_Result_Invalid_Gateway = 16,
    Upnp_Result_Invalid_Port = 17,
    Upnp_Result_Invalid_Protocol = 18,
    Upnp_Result_Invalid_Duration = 19,
    Upnp_Result_Invalid_Args = 20,
    Upnp_Result_Invalid_Response = 21,
    Upnp_Result_Invalid_Param = 22,
    Upnp_Result_Http_Error = 23,
    Upnp_Result_Socket_Error = 24,
    Upnp_Result_Mem_Alloc_Error = 25,
    Upnp_Result_No_Gateway = 26,
    Upnp_Result_No_Devices = 27,
    Upnp_Result_Unknown_Error = 28,
}



upnp_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

upnp_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_upnp :: proc "contextless" () -> Upnp {
    return cast(Upnp)__bindgen_gde.classdb_construct_object(upnp_name_ref())
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

upnp_get_device_count :: proc "contextless" (
    self: Upnp,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_device_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_get_device :: proc "contextless" (
    self: Upnp,
    index_: Int,
) -> (ret: Upnp_Device) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_device", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2193290270)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_add_device :: proc "contextless" (
    self: Upnp,
    device_: Upnp_Device,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_device", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 986715920)
    }
    self := self
    device_ := device_
    args := []__bindgen_gde.TypePtr {
        &device_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

upnp_set_device :: proc "contextless" (
    self: Upnp,
    index_: Int,
    device_: Upnp_Device,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_device", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3015133723)
    }
    self := self
    index_ := index_
    device_ := device_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &device_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

upnp_remove_device :: proc "contextless" (
    self: Upnp,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_device", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

upnp_clear_devices :: proc "contextless" (
    self: Upnp,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_devices", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

upnp_get_gateway :: proc "contextless" (
    self: Upnp,
) -> (ret: Upnp_Device) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gateway", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2276800779)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_discover :: proc "contextless" (
    self: Upnp,
    timeout_: Int,
    ttl_: Int,
    device_filter_: String,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("discover", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1575334765)
    }
    self := self
    timeout_ := timeout_
    ttl_ := ttl_
    device_filter_ := device_filter_
    args := []__bindgen_gde.TypePtr {
        &timeout_,
        &ttl_,
        &device_filter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_query_external_address :: proc "contextless" (
    self: Upnp,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("query_external_address", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_add_port_mapping :: proc "contextless" (
    self: Upnp,
    port_: Int,
    port_internal_: Int,
    desc_: String,
    proto_: String,
    duration_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_port_mapping", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 818314583)
    }
    self := self
    port_ := port_
    port_internal_ := port_internal_
    desc_ := desc_
    proto_ := proto_
    duration_ := duration_
    args := []__bindgen_gde.TypePtr {
        &port_,
        &port_internal_,
        &desc_,
        &proto_,
        &duration_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_delete_port_mapping :: proc "contextless" (
    self: Upnp,
    port_: Int,
    proto_: String,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("delete_port_mapping", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444187325)
    }
    self := self
    port_ := port_
    proto_ := proto_
    args := []__bindgen_gde.TypePtr {
        &port_,
        &proto_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_set_discover_multicast_if :: proc "contextless" (
    self: Upnp,
    m_if_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_discover_multicast_if", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    m_if_ := m_if_
    args := []__bindgen_gde.TypePtr {
        &m_if_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

upnp_get_discover_multicast_if :: proc "contextless" (
    self: Upnp,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_discover_multicast_if", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_set_discover_local_port :: proc "contextless" (
    self: Upnp,
    port_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_discover_local_port", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    port_ := port_
    args := []__bindgen_gde.TypePtr {
        &port_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

upnp_get_discover_local_port :: proc "contextless" (
    self: Upnp,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_discover_local_port", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_set_discover_ipv6 :: proc "contextless" (
    self: Upnp,
    ipv6_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_discover_ipv6", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    ipv6_ := ipv6_
    args := []__bindgen_gde.TypePtr {
        &ipv6_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

upnp_is_discover_ipv6 :: proc "contextless" (
    self: Upnp,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_discover_ipv6", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
upnp_get_discover_ipv6 :: proc "contextless" (self: Upnp) -> Bool {
    return upnp_is_discover_ipv6(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
upnp_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("UPNP", true)
}

@(private = "file")
__class_name: String_Name