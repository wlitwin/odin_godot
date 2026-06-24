package godot

import __bindgen_gde "godot:gdext"

Web_Socket_Multiplayer_Peer_Constants :: enum {
}



web_socket_multiplayer_peer_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

web_socket_multiplayer_peer_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_web_socket_multiplayer_peer :: proc "contextless" () -> Web_Socket_Multiplayer_Peer {
    return cast(Web_Socket_Multiplayer_Peer)__bindgen_gde.classdb_construct_object(web_socket_multiplayer_peer_name_ref())
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

web_socket_multiplayer_peer_create_client :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
    url_: String,
    tls_client_options_: Tls_Options,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_client", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1966198364)
    }
    self := self
    url_ := url_
    tls_client_options_ := tls_client_options_
    args := []__bindgen_gde.TypePtr {
        &url_,
        &tls_client_options_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_socket_multiplayer_peer_create_server :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
    port_: Int,
    bind_address_: String,
    tls_server_options_: Tls_Options,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_server", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2400822951)
    }
    self := self
    port_ := port_
    bind_address_ := bind_address_
    tls_server_options_ := tls_server_options_
    args := []__bindgen_gde.TypePtr {
        &port_,
        &bind_address_,
        &tls_server_options_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_socket_multiplayer_peer_get_peer :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
    peer_id_: Int,
) -> (ret: Web_Socket_Peer) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1381378851)
    }
    self := self
    peer_id_ := peer_id_
    args := []__bindgen_gde.TypePtr {
        &peer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_socket_multiplayer_peer_get_peer_address :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
    id_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_peer_address", true)
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

web_socket_multiplayer_peer_get_peer_port :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
    id_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_peer_port", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_socket_multiplayer_peer_get_supported_protocols :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_supported_protocols", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_socket_multiplayer_peer_set_supported_protocols :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
    protocols_: Packed_String_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_supported_protocols", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4015028928)
    }
    self := self
    protocols_ := protocols_
    args := []__bindgen_gde.TypePtr {
        &protocols_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_socket_multiplayer_peer_get_handshake_headers :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_handshake_headers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_socket_multiplayer_peer_set_handshake_headers :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
    protocols_: Packed_String_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_handshake_headers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4015028928)
    }
    self := self
    protocols_ := protocols_
    args := []__bindgen_gde.TypePtr {
        &protocols_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_socket_multiplayer_peer_get_inbound_buffer_size :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_inbound_buffer_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_socket_multiplayer_peer_set_inbound_buffer_size :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
    buffer_size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_inbound_buffer_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    buffer_size_ := buffer_size_
    args := []__bindgen_gde.TypePtr {
        &buffer_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_socket_multiplayer_peer_get_outbound_buffer_size :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_outbound_buffer_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_socket_multiplayer_peer_set_outbound_buffer_size :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
    buffer_size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_outbound_buffer_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    buffer_size_ := buffer_size_
    args := []__bindgen_gde.TypePtr {
        &buffer_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_socket_multiplayer_peer_get_handshake_timeout :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_handshake_timeout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_socket_multiplayer_peer_set_handshake_timeout :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
    timeout_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_handshake_timeout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    timeout_ := timeout_
    args := []__bindgen_gde.TypePtr {
        &timeout_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_socket_multiplayer_peer_set_max_queued_packets :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
    max_queued_packets_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_queued_packets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    max_queued_packets_ := max_queued_packets_
    args := []__bindgen_gde.TypePtr {
        &max_queued_packets_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_socket_multiplayer_peer_get_max_queued_packets :: proc "contextless" (
    self: Web_Socket_Multiplayer_Peer,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_queued_packets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
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
web_socket_multiplayer_peer_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("WebSocketMultiplayerPeer", true)
}

@(private = "file")
__class_name: String_Name