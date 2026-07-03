package godot

import __bindgen_gde "godot:gdext"

Upnp_Device_Constants :: enum {
}
Upnp_Device_Igd_Status :: enum int {
    Igd_Status_Ok = 0,
    Igd_Status_Http_Error = 1,
    Igd_Status_Http_Empty = 2,
    Igd_Status_No_Urls = 3,
    Igd_Status_No_Igd = 4,
    Igd_Status_Disconnected = 5,
    Igd_Status_Unknown_Device = 6,
    Igd_Status_Invalid_Control = 7,
    Igd_Status_Malloc_Error = 8,
    Igd_Status_Unknown_Error = 9,
}



upnp_device_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

upnp_device_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_upnp_device :: proc "contextless" () -> Upnp_Device {
    return cast(Upnp_Device)__bindgen_gde.classdb_construct_object(upnp_device_name_ref())
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

upnp_device_is_valid_gateway :: proc "contextless" (
    self: Upnp_Device,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid_gateway", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_device_query_external_address :: proc "contextless" (
    self: Upnp_Device,
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

upnp_device_add_port_mapping :: proc "contextless" (
    self: Upnp_Device,
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

upnp_device_delete_port_mapping :: proc "contextless" (
    self: Upnp_Device,
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

upnp_device_set_description_url :: proc "contextless" (
    self: Upnp_Device,
    url_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_description_url", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    url_ := url_
    args := []__bindgen_gde.TypePtr {
        &url_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

upnp_device_get_description_url :: proc "contextless" (
    self: Upnp_Device,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_description_url", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_device_set_service_type :: proc "contextless" (
    self: Upnp_Device,
    type_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_service_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

upnp_device_get_service_type :: proc "contextless" (
    self: Upnp_Device,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_service_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_device_set_igd_control_url :: proc "contextless" (
    self: Upnp_Device,
    url_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_igd_control_url", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    url_ := url_
    args := []__bindgen_gde.TypePtr {
        &url_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

upnp_device_get_igd_control_url :: proc "contextless" (
    self: Upnp_Device,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_igd_control_url", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_device_set_igd_service_type :: proc "contextless" (
    self: Upnp_Device,
    type_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_igd_service_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

upnp_device_get_igd_service_type :: proc "contextless" (
    self: Upnp_Device,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_igd_service_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_device_set_igd_our_addr :: proc "contextless" (
    self: Upnp_Device,
    addr_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_igd_our_addr", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    addr_ := addr_
    args := []__bindgen_gde.TypePtr {
        &addr_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

upnp_device_get_igd_our_addr :: proc "contextless" (
    self: Upnp_Device,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_igd_our_addr", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

upnp_device_set_igd_status :: proc "contextless" (
    self: Upnp_Device,
    status_: Upnp_Device_Igd_Status,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_igd_status", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 519504122)
    }
    self := self
    status_ := status_
    args := []__bindgen_gde.TypePtr {
        &status_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

upnp_device_get_igd_status :: proc "contextless" (
    self: Upnp_Device,
) -> (ret: Upnp_Device_Igd_Status) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_igd_status", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 180887011)
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
upnp_device_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("UPNPDevice", true)
}

@(private = "file")
__class_name: String_Name