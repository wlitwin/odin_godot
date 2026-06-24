package godot

import __bindgen_gde "godot:gdext"

Packet_Peer_Dtls_Constants :: enum {
}
Packet_Peer_Dtls_Status :: enum int {
    Status_Disconnected = 0,
    Status_Handshaking = 1,
    Status_Connected = 2,
    Status_Error = 3,
    Status_Error_Hostname_Mismatch = 4,
}



packet_peer_dtls_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

packet_peer_dtls_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_packet_peer_dtls :: proc "contextless" () -> Packet_Peer_Dtls {
    return cast(Packet_Peer_Dtls)__bindgen_gde.classdb_construct_object(packet_peer_dtls_name_ref())
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

packet_peer_dtls_poll :: proc "contextless" (
    self: Packet_Peer_Dtls,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("poll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

packet_peer_dtls_connect_to_peer :: proc "contextless" (
    self: Packet_Peer_Dtls,
    packet_peer_: Packet_Peer_Udp,
    hostname_: String,
    client_options_: Tls_Options,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("connect_to_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2880188099)
    }
    self := self
    packet_peer_ := packet_peer_
    hostname_ := hostname_
    client_options_ := client_options_
    args := []__bindgen_gde.TypePtr {
        &packet_peer_,
        &hostname_,
        &client_options_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

packet_peer_dtls_get_status :: proc "contextless" (
    self: Packet_Peer_Dtls,
) -> (ret: Packet_Peer_Dtls_Status) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_status", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3248654679)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

packet_peer_dtls_disconnect_from_peer :: proc "contextless" (
    self: Packet_Peer_Dtls,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("disconnect_from_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
packet_peer_dtls_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PacketPeerDTLS", true)
}

@(private = "file")
__class_name: String_Name