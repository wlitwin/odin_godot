package godot

import __bindgen_gde "godot:gdext"

E_Net_Packet_Peer_Constants :: enum {
    PACKET_LOSS_SCALE = 65536,
    PACKET_THROTTLE_SCALE = 32,
    FLAG_RELIABLE = 1,
    FLAG_UNSEQUENCED = 2,
    FLAG_UNRELIABLE_FRAGMENT = 8,
}
E_Net_Packet_Peer_Peer_State :: enum int {
    State_Disconnected = 0,
    State_Connecting = 1,
    State_Acknowledging_Connect = 2,
    State_Connection_Pending = 3,
    State_Connection_Succeeded = 4,
    State_Connected = 5,
    State_Disconnect_Later = 6,
    State_Disconnecting = 7,
    State_Acknowledging_Disconnect = 8,
    State_Zombie = 9,
}
E_Net_Packet_Peer_Peer_Statistic :: enum int {
    Peer_Packet_Loss = 0,
    Peer_Packet_Loss_Variance = 1,
    Peer_Packet_Loss_Epoch = 2,
    Peer_Round_Trip_Time = 3,
    Peer_Round_Trip_Time_Variance = 4,
    Peer_Last_Round_Trip_Time = 5,
    Peer_Last_Round_Trip_Time_Variance = 6,
    Peer_Packet_Throttle = 7,
    Peer_Packet_Throttle_Limit = 8,
    Peer_Packet_Throttle_Counter = 9,
    Peer_Packet_Throttle_Epoch = 10,
    Peer_Packet_Throttle_Acceleration = 11,
    Peer_Packet_Throttle_Deceleration = 12,
    Peer_Packet_Throttle_Interval = 13,
}



e_net_packet_peer_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

e_net_packet_peer_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_e_net_packet_peer :: proc "contextless" () -> E_Net_Packet_Peer {
    return cast(E_Net_Packet_Peer)__bindgen_gde.classdb_construct_object(e_net_packet_peer_name_ref())
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

e_net_packet_peer_peer_disconnect :: proc "contextless" (
    self: E_Net_Packet_Peer,
    data_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("peer_disconnect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1995695955)
    }
    self := self
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_packet_peer_peer_disconnect_later :: proc "contextless" (
    self: E_Net_Packet_Peer,
    data_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("peer_disconnect_later", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1995695955)
    }
    self := self
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_packet_peer_peer_disconnect_now :: proc "contextless" (
    self: E_Net_Packet_Peer,
    data_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("peer_disconnect_now", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1995695955)
    }
    self := self
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_packet_peer_ping :: proc "contextless" (
    self: E_Net_Packet_Peer,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ping", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_packet_peer_ping_interval :: proc "contextless" (
    self: E_Net_Packet_Peer,
    ping_interval_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ping_interval", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    ping_interval_ := ping_interval_
    args := []__bindgen_gde.TypePtr {
        &ping_interval_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_packet_peer_reset :: proc "contextless" (
    self: E_Net_Packet_Peer,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_packet_peer_send :: proc "contextless" (
    self: E_Net_Packet_Peer,
    channel_: Int,
    packet_: Packed_Byte_Array,
    flags_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("send", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 120522849)
    }
    self := self
    channel_ := channel_
    packet_ := packet_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &channel_,
        &packet_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_packet_peer_throttle_configure :: proc "contextless" (
    self: E_Net_Packet_Peer,
    interval_: Int,
    acceleration_: Int,
    deceleration_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("throttle_configure", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1649997291)
    }
    self := self
    interval_ := interval_
    acceleration_ := acceleration_
    deceleration_ := deceleration_
    args := []__bindgen_gde.TypePtr {
        &interval_,
        &acceleration_,
        &deceleration_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_packet_peer_set_timeout :: proc "contextless" (
    self: E_Net_Packet_Peer,
    timeout_: Int,
    timeout_min_: Int,
    timeout_max_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_timeout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1649997291)
    }
    self := self
    timeout_ := timeout_
    timeout_min_ := timeout_min_
    timeout_max_ := timeout_max_
    args := []__bindgen_gde.TypePtr {
        &timeout_,
        &timeout_min_,
        &timeout_max_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_packet_peer_get_packet_flags :: proc "contextless" (
    self: E_Net_Packet_Peer,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_packet_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_packet_peer_get_remote_address :: proc "contextless" (
    self: E_Net_Packet_Peer,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_remote_address", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_packet_peer_get_remote_port :: proc "contextless" (
    self: E_Net_Packet_Peer,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_remote_port", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_packet_peer_get_statistic :: proc "contextless" (
    self: E_Net_Packet_Peer,
    statistic_: E_Net_Packet_Peer_Peer_Statistic,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_statistic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1642578323)
    }
    self := self
    statistic_ := statistic_
    args := []__bindgen_gde.TypePtr {
        &statistic_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_packet_peer_get_state :: proc "contextless" (
    self: E_Net_Packet_Peer,
) -> (ret: E_Net_Packet_Peer_Peer_State) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 711068532)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_packet_peer_get_channels :: proc "contextless" (
    self: E_Net_Packet_Peer,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_channels", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_packet_peer_is_active :: proc "contextless" (
    self: E_Net_Packet_Peer,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
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
e_net_packet_peer_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ENetPacketPeer", true)
}

@(private = "file")
__class_name: String_Name