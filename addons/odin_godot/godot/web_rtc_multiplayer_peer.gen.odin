package godot

import __bindgen_gde "godot:gdext"

Web_Rtc_Multiplayer_Peer_Constants :: enum {
}



web_rtc_multiplayer_peer_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

web_rtc_multiplayer_peer_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_web_rtc_multiplayer_peer :: proc "contextless" () -> Web_Rtc_Multiplayer_Peer {
    return cast(Web_Rtc_Multiplayer_Peer)__bindgen_gde.classdb_construct_object(web_rtc_multiplayer_peer_name_ref())
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

web_rtc_multiplayer_peer_create_server :: proc "contextless" (
    self: Web_Rtc_Multiplayer_Peer,
    channels_config_: Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_server", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2865356025)
    }
    self := self
    channels_config_ := channels_config_
    args := []__bindgen_gde.TypePtr {
        &channels_config_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_multiplayer_peer_create_client :: proc "contextless" (
    self: Web_Rtc_Multiplayer_Peer,
    peer_id_: Int,
    channels_config_: Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_client", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2641732907)
    }
    self := self
    peer_id_ := peer_id_
    channels_config_ := channels_config_
    args := []__bindgen_gde.TypePtr {
        &peer_id_,
        &channels_config_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_multiplayer_peer_create_mesh :: proc "contextless" (
    self: Web_Rtc_Multiplayer_Peer,
    peer_id_: Int,
    channels_config_: Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2641732907)
    }
    self := self
    peer_id_ := peer_id_
    channels_config_ := channels_config_
    args := []__bindgen_gde.TypePtr {
        &peer_id_,
        &channels_config_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_multiplayer_peer_add_peer :: proc "contextless" (
    self: Web_Rtc_Multiplayer_Peer,
    peer_: Web_Rtc_Peer_Connection,
    peer_id_: Int,
    unreliable_lifetime_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4078953270)
    }
    self := self
    peer_ := peer_
    peer_id_ := peer_id_
    unreliable_lifetime_ := unreliable_lifetime_
    args := []__bindgen_gde.TypePtr {
        &peer_,
        &peer_id_,
        &unreliable_lifetime_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_multiplayer_peer_remove_peer :: proc "contextless" (
    self: Web_Rtc_Multiplayer_Peer,
    peer_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    peer_id_ := peer_id_
    args := []__bindgen_gde.TypePtr {
        &peer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_rtc_multiplayer_peer_has_peer :: proc "contextless" (
    self: Web_Rtc_Multiplayer_Peer,
    peer_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3067735520)
    }
    self := self
    peer_id_ := peer_id_
    args := []__bindgen_gde.TypePtr {
        &peer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_multiplayer_peer_get_peer :: proc "contextless" (
    self: Web_Rtc_Multiplayer_Peer,
    peer_id_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3554694381)
    }
    self := self
    peer_id_ := peer_id_
    args := []__bindgen_gde.TypePtr {
        &peer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_multiplayer_peer_get_peers :: proc "contextless" (
    self: Web_Rtc_Multiplayer_Peer,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_peers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2382534195)
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
web_rtc_multiplayer_peer_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("WebRTCMultiplayerPeer", true)
}

@(private = "file")
__class_name: String_Name