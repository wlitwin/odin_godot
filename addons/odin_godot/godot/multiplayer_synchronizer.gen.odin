package godot

import __bindgen_gde "godot:gdext"

Multiplayer_Synchronizer_Constants :: enum {
}
Multiplayer_Synchronizer_Visibility_Update_Mode :: enum int {
    Visibility_Process_Idle = 0,
    Visibility_Process_Physics = 1,
    Visibility_Process_None = 2,
}



multiplayer_synchronizer_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

multiplayer_synchronizer_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_multiplayer_synchronizer :: proc "contextless" () -> Multiplayer_Synchronizer {
    return __bindgen_gde.classdb_construct_object(multiplayer_synchronizer_name_ref())
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

multiplayer_synchronizer_set_root_path :: proc "contextless" (
    self: Multiplayer_Synchronizer,
    path_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_root_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1348162250)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_synchronizer_get_root_path :: proc "contextless" (
    self: Multiplayer_Synchronizer,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_root_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4075236667)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_synchronizer_set_replication_interval :: proc "contextless" (
    self: Multiplayer_Synchronizer,
    milliseconds_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_replication_interval", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    milliseconds_ := milliseconds_
    args := []__bindgen_gde.TypePtr {
        &milliseconds_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_synchronizer_get_replication_interval :: proc "contextless" (
    self: Multiplayer_Synchronizer,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_replication_interval", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_synchronizer_set_delta_interval :: proc "contextless" (
    self: Multiplayer_Synchronizer,
    milliseconds_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_delta_interval", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    milliseconds_ := milliseconds_
    args := []__bindgen_gde.TypePtr {
        &milliseconds_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_synchronizer_get_delta_interval :: proc "contextless" (
    self: Multiplayer_Synchronizer,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_delta_interval", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_synchronizer_set_replication_config :: proc "contextless" (
    self: Multiplayer_Synchronizer,
    config_: Scene_Replication_Config,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_replication_config", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3889206742)
    }
    self := self
    config_ := config_
    args := []__bindgen_gde.TypePtr {
        &config_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_synchronizer_get_replication_config :: proc "contextless" (
    self: Multiplayer_Synchronizer,
) -> (ret: Scene_Replication_Config) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_replication_config", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3200254614)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_synchronizer_set_visibility_update_mode :: proc "contextless" (
    self: Multiplayer_Synchronizer,
    mode_: Multiplayer_Synchronizer_Visibility_Update_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_update_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3494860300)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_synchronizer_get_visibility_update_mode :: proc "contextless" (
    self: Multiplayer_Synchronizer,
) -> (ret: Multiplayer_Synchronizer_Visibility_Update_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_update_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3352241418)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_synchronizer_update_visibility :: proc "contextless" (
    self: Multiplayer_Synchronizer,
    for_peer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_visibility", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1995695955)
    }
    self := self
    for_peer_ := for_peer_
    args := []__bindgen_gde.TypePtr {
        &for_peer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_synchronizer_set_visibility_public :: proc "contextless" (
    self: Multiplayer_Synchronizer,
    visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_public", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    visible_ := visible_
    args := []__bindgen_gde.TypePtr {
        &visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_synchronizer_is_visibility_public :: proc "contextless" (
    self: Multiplayer_Synchronizer,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_visibility_public", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

multiplayer_synchronizer_add_visibility_filter :: proc "contextless" (
    self: Multiplayer_Synchronizer,
    filter_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_visibility_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1611583062)
    }
    self := self
    filter_ := filter_
    args := []__bindgen_gde.TypePtr {
        &filter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_synchronizer_remove_visibility_filter :: proc "contextless" (
    self: Multiplayer_Synchronizer,
    filter_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_visibility_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1611583062)
    }
    self := self
    filter_ := filter_
    args := []__bindgen_gde.TypePtr {
        &filter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_synchronizer_set_visibility_for :: proc "contextless" (
    self: Multiplayer_Synchronizer,
    peer_: Int,
    visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_for", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    peer_ := peer_
    visible_ := visible_
    args := []__bindgen_gde.TypePtr {
        &peer_,
        &visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

multiplayer_synchronizer_get_visibility_for :: proc "contextless" (
    self: Multiplayer_Synchronizer,
    peer_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_for", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    peer_ := peer_
    args := []__bindgen_gde.TypePtr {
        &peer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
multiplayer_synchronizer_get_public_visibility :: proc "contextless" (self: Multiplayer_Synchronizer) -> Bool {
    return multiplayer_synchronizer_is_visibility_public(self)
}
multiplayer_synchronizer_set_public_visibility :: proc "contextless" (self: Multiplayer_Synchronizer, value: Bool) {
    multiplayer_synchronizer_set_visibility_public(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
multiplayer_synchronizer_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("MultiplayerSynchronizer", true)
}

@(private = "file")
__class_name: String_Name