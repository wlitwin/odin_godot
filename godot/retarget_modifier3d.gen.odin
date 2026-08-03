package godot

import __bindgen_gde "godot:gdext"

Retarget_Modifier3d_Constants :: enum {
}

Retarget_Modifier3d_Transform_Flag :: enum i64 {
    Transform_Flag_Position = 1,
    Transform_Flag_Rotation = 2,
    Transform_Flag_Scale = 4,
    Transform_Flag_All = 7,
}


retarget_modifier3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

retarget_modifier3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_retarget_modifier3d :: proc "contextless" () -> Retarget_Modifier3d {
    return cast(Retarget_Modifier3d)__bindgen_gde.classdb_construct_object(retarget_modifier3d_name_ref())
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

retarget_modifier3d_set_profile :: proc "contextless" (
    self: Retarget_Modifier3d,
    profile_: Skeleton_Profile,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_profile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3870374136)
    }
    self := self
    profile_ := profile_
    args := []__bindgen_gde.TypePtr {
        &profile_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

retarget_modifier3d_get_profile :: proc "contextless" (
    self: Retarget_Modifier3d,
) -> (ret: Skeleton_Profile) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_profile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4291782652)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

retarget_modifier3d_set_use_global_pose :: proc "contextless" (
    self: Retarget_Modifier3d,
    use_global_pose_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_global_pose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    use_global_pose_ := use_global_pose_
    args := []__bindgen_gde.TypePtr {
        &use_global_pose_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

retarget_modifier3d_is_using_global_pose :: proc "contextless" (
    self: Retarget_Modifier3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_global_pose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

retarget_modifier3d_set_enable_flags :: proc "contextless" (
    self: Retarget_Modifier3d,
    enable_flags_: Retarget_Modifier3d_Transform_Flag,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_enable_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2687954213)
    }
    self := self
    enable_flags_ := enable_flags_
    args := []__bindgen_gde.TypePtr {
        &enable_flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

retarget_modifier3d_get_enable_flags :: proc "contextless" (
    self: Retarget_Modifier3d,
) -> (ret: Retarget_Modifier3d_Transform_Flag) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_enable_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 358995420)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

retarget_modifier3d_set_position_enabled :: proc "contextless" (
    self: Retarget_Modifier3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_position_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

retarget_modifier3d_is_position_enabled :: proc "contextless" (
    self: Retarget_Modifier3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_position_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

retarget_modifier3d_set_rotation_enabled :: proc "contextless" (
    self: Retarget_Modifier3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rotation_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

retarget_modifier3d_is_rotation_enabled :: proc "contextless" (
    self: Retarget_Modifier3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_rotation_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

retarget_modifier3d_set_scale_enabled :: proc "contextless" (
    self: Retarget_Modifier3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scale_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

retarget_modifier3d_is_scale_enabled :: proc "contextless" (
    self: Retarget_Modifier3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_scale_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
retarget_modifier3d_get_use_global_pose :: proc "contextless" (self: Retarget_Modifier3d) -> Bool {
    return retarget_modifier3d_is_using_global_pose(self)
}
retarget_modifier3d_get_enable :: proc "contextless" (self: Retarget_Modifier3d) -> Retarget_Modifier3d_Transform_Flag {
    return retarget_modifier3d_get_enable_flags(self)
}
retarget_modifier3d_set_enable :: proc "contextless" (self: Retarget_Modifier3d, value: Retarget_Modifier3d_Transform_Flag) {
    retarget_modifier3d_set_enable_flags(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
retarget_modifier3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("RetargetModifier3D", true)
}

@(private = "file")
__class_name: String_Name