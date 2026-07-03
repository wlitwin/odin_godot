package godot

import __bindgen_gde "godot:gdext"

Scene_Replication_Config_Constants :: enum {
}
Scene_Replication_Config_Replication_Mode :: enum int {
    Replication_Mode_Never = 0,
    Replication_Mode_Always = 1,
    Replication_Mode_On_Change = 2,
}



scene_replication_config_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

scene_replication_config_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_scene_replication_config :: proc "contextless" () -> Scene_Replication_Config {
    return cast(Scene_Replication_Config)__bindgen_gde.classdb_construct_object(scene_replication_config_name_ref())
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

scene_replication_config_get_properties :: proc "contextless" (
    self: Scene_Replication_Config,
) -> (ret: Typed_Array(Node_Path)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_properties", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_replication_config_add_property :: proc "contextless" (
    self: Scene_Replication_Config,
    path_: Node_Path,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_property", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4094619021)
    }
    self := self
    path_ := path_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_replication_config_has_property :: proc "contextless" (
    self: Scene_Replication_Config,
    path_: Node_Path,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_property", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 861721659)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_replication_config_remove_property :: proc "contextless" (
    self: Scene_Replication_Config,
    path_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_property", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1348162250)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_replication_config_property_get_index :: proc "contextless" (
    self: Scene_Replication_Config,
    path_: Node_Path,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("property_get_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1382022557)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_replication_config_property_get_spawn :: proc "contextless" (
    self: Scene_Replication_Config,
    path_: Node_Path,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("property_get_spawn", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3456846888)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_replication_config_property_set_spawn :: proc "contextless" (
    self: Scene_Replication_Config,
    path_: Node_Path,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("property_set_spawn", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3868023870)
    }
    self := self
    path_ := path_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_replication_config_property_get_replication_mode :: proc "contextless" (
    self: Scene_Replication_Config,
    path_: Node_Path,
) -> (ret: Scene_Replication_Config_Replication_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("property_get_replication_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2870606336)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_replication_config_property_set_replication_mode :: proc "contextless" (
    self: Scene_Replication_Config,
    path_: Node_Path,
    mode_: Scene_Replication_Config_Replication_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("property_set_replication_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3200083865)
    }
    self := self
    path_ := path_
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_replication_config_property_get_sync :: proc "contextless" (
    self: Scene_Replication_Config,
    path_: Node_Path,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("property_get_sync", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3456846888)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_replication_config_property_set_sync :: proc "contextless" (
    self: Scene_Replication_Config,
    path_: Node_Path,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("property_set_sync", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3868023870)
    }
    self := self
    path_ := path_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

scene_replication_config_property_get_watch :: proc "contextless" (
    self: Scene_Replication_Config,
    path_: Node_Path,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("property_get_watch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3456846888)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

scene_replication_config_property_set_watch :: proc "contextless" (
    self: Scene_Replication_Config,
    path_: Node_Path,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("property_set_watch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3868023870)
    }
    self := self
    path_ := path_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
scene_replication_config_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SceneReplicationConfig", true)
}

@(private = "file")
__class_name: String_Name