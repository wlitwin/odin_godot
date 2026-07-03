package godot

import __bindgen_gde "godot:gdext"

Multiplayer_Api_Extension_Constants :: enum {
}



multiplayer_api_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

multiplayer_api_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_multiplayer_api_extension :: proc "contextless" () -> Multiplayer_Api_Extension {
    return cast(Multiplayer_Api_Extension)__bindgen_gde.classdb_construct_object(multiplayer_api_extension_name_ref())
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

multiplayer_api_extension__poll :: proc "contextless" (
    self: Multiplayer_Api_Extension,
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

multiplayer_api_extension__set_multiplayer_peer :: proc "contextless" (
    self: Multiplayer_Api_Extension,
    multiplayer_peer_: Multiplayer_Peer,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_multiplayer_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3694835298)
    }
    self := self
    multiplayer_peer_ := multiplayer_peer_
    args := []__bindgen_gde.TypePtr {
        &multiplayer_peer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_api_extension__get_multiplayer_peer :: proc "contextless" (
    self: Multiplayer_Api_Extension,
) -> (ret: Multiplayer_Peer) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_multiplayer_peer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3223692825)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_api_extension__get_unique_id :: proc "contextless" (
    self: Multiplayer_Api_Extension,
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

multiplayer_api_extension__get_peer_ids :: proc "contextless" (
    self: Multiplayer_Api_Extension,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_peer_ids", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1930428628)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_api_extension__rpc :: proc "contextless" (
    self: Multiplayer_Api_Extension,
    peer_: Int,
    object_: Object,
    method_: String_Name,
    args_: Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_rpc", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3673574758)
    }
    self := self
    peer_ := peer_
    object_ := object_
    method_ := method_
    args_ := args_
    args := []__bindgen_gde.TypePtr {
        &peer_,
        &object_,
        &method_,
        &args_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_api_extension__get_remote_sender_id :: proc "contextless" (
    self: Multiplayer_Api_Extension,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_remote_sender_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_api_extension__object_configuration_add :: proc "contextless" (
    self: Multiplayer_Api_Extension,
    object_: Object,
    configuration_: Variant,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_object_configuration_add", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1171879464)
    }
    self := self
    object_ := object_
    configuration_ := configuration_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &configuration_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_api_extension__object_configuration_remove :: proc "contextless" (
    self: Multiplayer_Api_Extension,
    object_: Object,
    configuration_: Variant,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_object_configuration_remove", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1171879464)
    }
    self := self
    object_ := object_
    configuration_ := configuration_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &configuration_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
multiplayer_api_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("MultiplayerAPIExtension", true)
}

@(private = "file")
__class_name: String_Name