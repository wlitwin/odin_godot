package godot

import __bindgen_gde "godot:gdext"

Web_Rtc_Peer_Connection_Constants :: enum {
}
Web_Rtc_Peer_Connection_Connection_State :: enum int {
    State_New = 0,
    State_Connecting = 1,
    State_Connected = 2,
    State_Disconnected = 3,
    State_Failed = 4,
    State_Closed = 5,
}
Web_Rtc_Peer_Connection_Gathering_State :: enum int {
    Gathering_State_New = 0,
    Gathering_State_Gathering = 1,
    Gathering_State_Complete = 2,
}
Web_Rtc_Peer_Connection_Signaling_State :: enum int {
    Signaling_State_Stable = 0,
    Signaling_State_Have_Local_Offer = 1,
    Signaling_State_Have_Remote_Offer = 2,
    Signaling_State_Have_Local_Pranswer = 3,
    Signaling_State_Have_Remote_Pranswer = 4,
    Signaling_State_Closed = 5,
}



web_rtc_peer_connection_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

web_rtc_peer_connection_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_web_rtc_peer_connection :: proc "contextless" () -> Web_Rtc_Peer_Connection {
    return cast(Web_Rtc_Peer_Connection)__bindgen_gde.classdb_construct_object(web_rtc_peer_connection_name_ref())
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
web_rtc_peer_connection_set_default_extension :: proc "contextless" (
    extension_class_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_default_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    extension_class_ := extension_class_
    args := []__bindgen_gde.TypePtr {
        &extension_class_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), nil)
}


web_rtc_peer_connection_initialize :: proc "contextless" (
    self: Web_Rtc_Peer_Connection,
    configuration_: Dictionary,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("initialize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2625064318)
    }
    self := self
    configuration_ := configuration_
    args := []__bindgen_gde.TypePtr {
        &configuration_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_create_data_channel :: proc "contextless" (
    self: Web_Rtc_Peer_Connection,
    label_: String,
    options_: Dictionary,
) -> (ret: Web_Rtc_Data_Channel) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_data_channel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1288557393)
    }
    self := self
    label_ := label_
    options_ := options_
    args := []__bindgen_gde.TypePtr {
        &label_,
        &options_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_create_offer :: proc "contextless" (
    self: Web_Rtc_Peer_Connection,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_offer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_set_local_description :: proc "contextless" (
    self: Web_Rtc_Peer_Connection,
    type_: String,
    sdp_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_local_description", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 852856452)
    }
    self := self
    type_ := type_
    sdp_ := sdp_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &sdp_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_set_remote_description :: proc "contextless" (
    self: Web_Rtc_Peer_Connection,
    type_: String,
    sdp_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_remote_description", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 852856452)
    }
    self := self
    type_ := type_
    sdp_ := sdp_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &sdp_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_add_ice_candidate :: proc "contextless" (
    self: Web_Rtc_Peer_Connection,
    media_: String,
    index_: Int,
    name_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_ice_candidate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3958950400)
    }
    self := self
    media_ := media_
    index_ := index_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &media_,
        &index_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_poll :: proc "contextless" (
    self: Web_Rtc_Peer_Connection,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("poll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_close :: proc "contextless" (
    self: Web_Rtc_Peer_Connection,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("close", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_rtc_peer_connection_get_connection_state :: proc "contextless" (
    self: Web_Rtc_Peer_Connection,
) -> (ret: Web_Rtc_Peer_Connection_Connection_State) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_connection_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2275710506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_get_gathering_state :: proc "contextless" (
    self: Web_Rtc_Peer_Connection,
) -> (ret: Web_Rtc_Peer_Connection_Gathering_State) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gathering_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4262591401)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_get_signaling_state :: proc "contextless" (
    self: Web_Rtc_Peer_Connection,
) -> (ret: Web_Rtc_Peer_Connection_Signaling_State) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_signaling_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3342956226)
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
web_rtc_peer_connection_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("WebRTCPeerConnection", true)
}

@(private = "file")
__class_name: String_Name