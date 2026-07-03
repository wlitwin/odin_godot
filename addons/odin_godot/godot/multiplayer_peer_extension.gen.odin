package godot

import __bindgen_gde "godot:gdext"

Multiplayer_Peer_Extension_Constants :: enum {
}



multiplayer_peer_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

multiplayer_peer_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_multiplayer_peer_extension :: proc "contextless" () -> Multiplayer_Peer_Extension {
    return cast(Multiplayer_Peer_Extension)__bindgen_gde.classdb_construct_object(multiplayer_peer_extension_name_ref())
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

multiplayer_peer_extension__get_packet :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
    r_buffer_: ^^u8,
    r_buffer_size_: ^i32,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_packet", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3099858825)
    }
    self := self
    r_buffer_ := r_buffer_
    r_buffer_size_ := r_buffer_size_
    args := []__bindgen_gde.TypePtr {
        &r_buffer_,
        &r_buffer_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__put_packet :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
    p_buffer_: ^u8,
    p_buffer_size_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_put_packet", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3099858825)
    }
    self := self
    p_buffer_ := p_buffer_
    p_buffer_size_ := p_buffer_size_
    args := []__bindgen_gde.TypePtr {
        &p_buffer_,
        &p_buffer_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__get_available_packet_count :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_available_packet_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__get_max_packet_size :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_max_packet_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__get_packet_script :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_packet_script", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2115431945)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__put_packet_script :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
    p_buffer_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_put_packet_script", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 680677267)
    }
    self := self
    p_buffer_ := p_buffer_
    args := []__bindgen_gde.TypePtr {
        &p_buffer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__get_packet_channel :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_packet_channel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__get_packet_mode :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) -> (ret: Multiplayer_Peer_Transfer_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_packet_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3369852622)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__set_transfer_channel :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
    p_channel_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_transfer_channel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    p_channel_ := p_channel_
    args := []__bindgen_gde.TypePtr {
        &p_channel_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_peer_extension__get_transfer_channel :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_transfer_channel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__set_transfer_mode :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
    p_mode_: Multiplayer_Peer_Transfer_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_transfer_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 950411049)
    }
    self := self
    p_mode_ := p_mode_
    args := []__bindgen_gde.TypePtr {
        &p_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_peer_extension__get_transfer_mode :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) -> (ret: Multiplayer_Peer_Transfer_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_transfer_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3369852622)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__set_target_peer :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
    p_peer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_target_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    p_peer_ := p_peer_
    args := []__bindgen_gde.TypePtr {
        &p_peer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_peer_extension__get_packet_peer :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_packet_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__is_server :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_server", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__poll :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_poll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_peer_extension__close :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_close", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_peer_extension__disconnect_peer :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
    p_peer_: Int,
    p_force_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_disconnect_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    p_peer_ := p_peer_
    p_force_ := p_force_
    args := []__bindgen_gde.TypePtr {
        &p_peer_,
        &p_force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_peer_extension__get_unique_id :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_unique_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__set_refuse_new_connections :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
    p_enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_refuse_new_connections", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    p_enable_ := p_enable_
    args := []__bindgen_gde.TypePtr {
        &p_enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_peer_extension__is_refusing_new_connections :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_refusing_new_connections", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__is_server_relay_supported :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_server_relay_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_peer_extension__get_connection_status :: proc "contextless" (
    self: Multiplayer_Peer_Extension,
) -> (ret: Multiplayer_Peer_Connection_Status) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_connection_status", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2147374275)
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
multiplayer_peer_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("MultiplayerPeerExtension", true)
}

@(private = "file")
__class_name: String_Name