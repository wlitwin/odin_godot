package godot

import __bindgen_gde "godot:gdext"

E_Net_Connection_Constants :: enum {
}
E_Net_Connection_Compression_Mode :: enum int {
    Compress_None = 0,
    Compress_Range_Coder = 1,
    Compress_Fastlz = 2,
    Compress_Zlib = 3,
    Compress_Zstd = 4,
}
E_Net_Connection_Event_Type :: enum int {
    Event_Error = -1,
    Event_None = 0,
    Event_Connect = 1,
    Event_Disconnect = 2,
    Event_Receive = 3,
}
E_Net_Connection_Host_Statistic :: enum int {
    Host_Total_Sent_Data = 0,
    Host_Total_Sent_Packets = 1,
    Host_Total_Received_Data = 2,
    Host_Total_Received_Packets = 3,
}



e_net_connection_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

e_net_connection_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_e_net_connection :: proc "contextless" () -> E_Net_Connection {
    return cast(E_Net_Connection)__bindgen_gde.classdb_construct_object(e_net_connection_name_ref())
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

e_net_connection_create_host_bound :: proc "contextless" (
    self: E_Net_Connection,
    bind_address_: String,
    bind_port_: Int,
    max_peers_: Int,
    max_channels_: Int,
    in_bandwidth_: Int,
    out_bandwidth_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_host_bound", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1515002313)
    }
    self := self
    bind_address_ := bind_address_
    bind_port_ := bind_port_
    max_peers_ := max_peers_
    max_channels_ := max_channels_
    in_bandwidth_ := in_bandwidth_
    out_bandwidth_ := out_bandwidth_
    args := []__bindgen_gde.TypePtr {
        &bind_address_,
        &bind_port_,
        &max_peers_,
        &max_channels_,
        &in_bandwidth_,
        &out_bandwidth_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_connection_create_host :: proc "contextless" (
    self: E_Net_Connection,
    max_peers_: Int,
    max_channels_: Int,
    in_bandwidth_: Int,
    out_bandwidth_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_host", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 117198950)
    }
    self := self
    max_peers_ := max_peers_
    max_channels_ := max_channels_
    in_bandwidth_ := in_bandwidth_
    out_bandwidth_ := out_bandwidth_
    args := []__bindgen_gde.TypePtr {
        &max_peers_,
        &max_channels_,
        &in_bandwidth_,
        &out_bandwidth_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_connection_destroy :: proc "contextless" (
    self: E_Net_Connection,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("destroy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_connection_connect_to_host :: proc "contextless" (
    self: E_Net_Connection,
    address_: String,
    port_: Int,
    channels_: Int,
    data_: Int,
) -> (ret: E_Net_Packet_Peer) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("connect_to_host", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2171300490)
    }
    self := self
    address_ := address_
    port_ := port_
    channels_ := channels_
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &address_,
        &port_,
        &channels_,
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_connection_service :: proc "contextless" (
    self: E_Net_Connection,
    timeout_: Int,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("service", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2402345344)
    }
    self := self
    timeout_ := timeout_
    args := []__bindgen_gde.TypePtr {
        &timeout_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_connection_flush :: proc "contextless" (
    self: E_Net_Connection,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("flush", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_connection_bandwidth_limit :: proc "contextless" (
    self: E_Net_Connection,
    in_bandwidth_: Int,
    out_bandwidth_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bandwidth_limit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2302169788)
    }
    self := self
    in_bandwidth_ := in_bandwidth_
    out_bandwidth_ := out_bandwidth_
    args := []__bindgen_gde.TypePtr {
        &in_bandwidth_,
        &out_bandwidth_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_connection_channel_limit :: proc "contextless" (
    self: E_Net_Connection,
    limit_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("channel_limit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    limit_ := limit_
    args := []__bindgen_gde.TypePtr {
        &limit_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_connection_broadcast :: proc "contextless" (
    self: E_Net_Connection,
    channel_: Int,
    packet_: Packed_Byte_Array,
    flags_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("broadcast", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2772371345)
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
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_connection_compress :: proc "contextless" (
    self: E_Net_Connection,
    mode_: E_Net_Connection_Compression_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compress", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2660215187)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_connection_dtls_server_setup :: proc "contextless" (
    self: E_Net_Connection,
    server_options_: Tls_Options,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("dtls_server_setup", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1262296096)
    }
    self := self
    server_options_ := server_options_
    args := []__bindgen_gde.TypePtr {
        &server_options_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_connection_dtls_client_setup :: proc "contextless" (
    self: E_Net_Connection,
    hostname_: String,
    client_options_: Tls_Options,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("dtls_client_setup", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1966198364)
    }
    self := self
    hostname_ := hostname_
    client_options_ := client_options_
    args := []__bindgen_gde.TypePtr {
        &hostname_,
        &client_options_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_connection_refuse_new_connections :: proc "contextless" (
    self: E_Net_Connection,
    refuse_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("refuse_new_connections", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    refuse_ := refuse_
    args := []__bindgen_gde.TypePtr {
        &refuse_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

e_net_connection_pop_statistic :: proc "contextless" (
    self: E_Net_Connection,
    statistic_: E_Net_Connection_Host_Statistic,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pop_statistic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2166904170)
    }
    self := self
    statistic_ := statistic_
    args := []__bindgen_gde.TypePtr {
        &statistic_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_connection_get_max_channels :: proc "contextless" (
    self: E_Net_Connection,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_channels", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_connection_get_local_port :: proc "contextless" (
    self: E_Net_Connection,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_local_port", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_connection_get_peers :: proc "contextless" (
    self: E_Net_Connection,
) -> (ret: Typed_Array(E_Net_Packet_Peer)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_peers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

e_net_connection_socket_send :: proc "contextless" (
    self: E_Net_Connection,
    destination_address_: String,
    destination_port_: Int,
    packet_: Packed_Byte_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("socket_send", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1100646812)
    }
    self := self
    destination_address_ := destination_address_
    destination_port_ := destination_port_
    packet_ := packet_
    args := []__bindgen_gde.TypePtr {
        &destination_address_,
        &destination_port_,
        &packet_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
e_net_connection_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ENetConnection", true)
}

@(private = "file")
__class_name: String_Name