package godot

import __bindgen_gde "godot:gdext"

Web_Rtc_Peer_Connection_Extension_Constants :: enum {
}



web_rtc_peer_connection_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

web_rtc_peer_connection_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_web_rtc_peer_connection_extension :: proc "contextless" () -> Web_Rtc_Peer_Connection_Extension {
    return cast(Web_Rtc_Peer_Connection_Extension)__bindgen_gde.classdb_construct_object(web_rtc_peer_connection_extension_name_ref())
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

web_rtc_peer_connection_extension__get_connection_state :: proc "contextless" (
    self: Web_Rtc_Peer_Connection_Extension,
) -> (ret: Web_Rtc_Peer_Connection_Connection_State) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_connection_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2275710506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_extension__get_gathering_state :: proc "contextless" (
    self: Web_Rtc_Peer_Connection_Extension,
) -> (ret: Web_Rtc_Peer_Connection_Gathering_State) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_gathering_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4262591401)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_extension__get_signaling_state :: proc "contextless" (
    self: Web_Rtc_Peer_Connection_Extension,
) -> (ret: Web_Rtc_Peer_Connection_Signaling_State) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_signaling_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3342956226)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_extension__initialize :: proc "contextless" (
    self: Web_Rtc_Peer_Connection_Extension,
    config_: Dictionary,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_initialize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1494659981)
    }
    self := self
    config_ := config_
    args := []__bindgen_gde.TypePtr {
        &config_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_extension__create_data_channel :: proc "contextless" (
    self: Web_Rtc_Peer_Connection_Extension,
    label_: String,
    config_: Dictionary,
) -> (ret: Web_Rtc_Data_Channel) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_create_data_channel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4111292546)
    }
    self := self
    label_ := label_
    config_ := config_
    args := []__bindgen_gde.TypePtr {
        &label_,
        &config_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_extension__create_offer :: proc "contextless" (
    self: Web_Rtc_Peer_Connection_Extension,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_create_offer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_extension__set_remote_description :: proc "contextless" (
    self: Web_Rtc_Peer_Connection_Extension,
    type_: String,
    sdp_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_remote_description", true)
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

web_rtc_peer_connection_extension__set_local_description :: proc "contextless" (
    self: Web_Rtc_Peer_Connection_Extension,
    type_: String,
    sdp_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_local_description", true)
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

web_rtc_peer_connection_extension__add_ice_candidate :: proc "contextless" (
    self: Web_Rtc_Peer_Connection_Extension,
    sdp_mid_name_: String,
    sdp_mline_index_: Int,
    sdp_name_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_add_ice_candidate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3958950400)
    }
    self := self
    sdp_mid_name_ := sdp_mid_name_
    sdp_mline_index_ := sdp_mline_index_
    sdp_name_ := sdp_name_
    args := []__bindgen_gde.TypePtr {
        &sdp_mid_name_,
        &sdp_mline_index_,
        &sdp_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_extension__poll :: proc "contextless" (
    self: Web_Rtc_Peer_Connection_Extension,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_poll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_rtc_peer_connection_extension__close :: proc "contextless" (
    self: Web_Rtc_Peer_Connection_Extension,
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


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
web_rtc_peer_connection_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("WebRTCPeerConnectionExtension", true)
}

@(private = "file")
__class_name: String_Name