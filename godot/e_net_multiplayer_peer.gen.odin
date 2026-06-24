package godot

import __bindgen_gde "godot:gdext"

E_Net_Multiplayer_Peer_Constants :: enum {
}



e_net_multiplayer_peer_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

e_net_multiplayer_peer_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_e_net_multiplayer_peer :: proc "contextless" () -> E_Net_Multiplayer_Peer {
    return cast(E_Net_Multiplayer_Peer)__bindgen_gde.classdb_construct_object(e_net_multiplayer_peer_name_ref())
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

e_net_multiplayer_peer_create_server :: proc "contextless" (
    self: E_Net_Multiplayer_Peer,
    port_: Int,
    max_clients_: Int,
    max_channels_: Int,
    in_bandwidth_: Int,
    out_bandwidth_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_server", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2917761309)
    }
    self := self
    port_ := port_
    max_clients_ := max_clients_
    max_channels_ := max_channels_
    in_bandwidth_ := in_bandwidth_
    out_bandwidth_ := out_bandwidth_
    args := []__bindgen_gde.TypePtr {
        &port_,
        &max_clients_,
        &max_channels_,
        &in_bandwidth_,
        &out_bandwidth_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_multiplayer_peer_create_client :: proc "contextless" (
    self: E_Net_Multiplayer_Peer,
    address_: String,
    port_: Int,
    channel_count_: Int,
    in_bandwidth_: Int,
    out_bandwidth_: Int,
    local_port_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_client", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2327163476)
    }
    self := self
    address_ := address_
    port_ := port_
    channel_count_ := channel_count_
    in_bandwidth_ := in_bandwidth_
    out_bandwidth_ := out_bandwidth_
    local_port_ := local_port_
    args := []__bindgen_gde.TypePtr {
        &address_,
        &port_,
        &channel_count_,
        &in_bandwidth_,
        &out_bandwidth_,
        &local_port_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_multiplayer_peer_create_mesh :: proc "contextless" (
    self: E_Net_Multiplayer_Peer,
    unique_id_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844576869)
    }
    self := self
    unique_id_ := unique_id_
    args := []__bindgen_gde.TypePtr {
        &unique_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_multiplayer_peer_add_mesh_peer :: proc "contextless" (
    self: E_Net_Multiplayer_Peer,
    peer_id_: Int,
    host_: E_Net_Connection,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_mesh_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1293458335)
    }
    self := self
    peer_id_ := peer_id_
    host_ := host_
    args := []__bindgen_gde.TypePtr {
        &peer_id_,
        &host_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_multiplayer_peer_set_bind_ip :: proc "contextless" (
    self: E_Net_Multiplayer_Peer,
    ip_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bind_ip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    ip_ := ip_
    args := []__bindgen_gde.TypePtr {
        &ip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_multiplayer_peer_get_host :: proc "contextless" (
    self: E_Net_Multiplayer_Peer,
) -> (ret: E_Net_Connection) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_host", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4103238886)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_multiplayer_peer_get_peer :: proc "contextless" (
    self: E_Net_Multiplayer_Peer,
    id_: Int,
) -> (ret: E_Net_Packet_Peer) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3793311544)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
e_net_multiplayer_peer_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ENetMultiplayerPeer", true)
}

@(private = "file")
__class_name: String_Name