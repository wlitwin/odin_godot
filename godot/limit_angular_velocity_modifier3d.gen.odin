package godot

import __bindgen_gde "godot:gdext"

Limit_Angular_Velocity_Modifier3d_Constants :: enum {
}



limit_angular_velocity_modifier3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

limit_angular_velocity_modifier3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_limit_angular_velocity_modifier3d :: proc "contextless" () -> Limit_Angular_Velocity_Modifier3d {
    return cast(Limit_Angular_Velocity_Modifier3d)__bindgen_gde.classdb_construct_object(limit_angular_velocity_modifier3d_name_ref())
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

limit_angular_velocity_modifier3d_set_root_bone_name :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
    index_: Int,
    bone_name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_root_bone_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    index_ := index_
    bone_name_ := bone_name_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &bone_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

limit_angular_velocity_modifier3d_get_root_bone_name :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
    index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_root_bone_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

limit_angular_velocity_modifier3d_set_root_bone :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
    index_: Int,
    bone_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_root_bone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    index_ := index_
    bone_ := bone_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &bone_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

limit_angular_velocity_modifier3d_get_root_bone :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_root_bone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

limit_angular_velocity_modifier3d_set_end_bone_name :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
    index_: Int,
    bone_name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_end_bone_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    index_ := index_
    bone_name_ := bone_name_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &bone_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

limit_angular_velocity_modifier3d_get_end_bone_name :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
    index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_end_bone_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

limit_angular_velocity_modifier3d_set_end_bone :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
    index_: Int,
    bone_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_end_bone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    index_ := index_
    bone_ := bone_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &bone_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

limit_angular_velocity_modifier3d_get_end_bone :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_end_bone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

limit_angular_velocity_modifier3d_set_chain_count :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_chain_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

limit_angular_velocity_modifier3d_get_chain_count :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_chain_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

limit_angular_velocity_modifier3d_clear_chains :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_chains", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

limit_angular_velocity_modifier3d_set_max_angular_velocity :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
    angular_velocity_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_angular_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    angular_velocity_ := angular_velocity_
    args := []__bindgen_gde.TypePtr {
        &angular_velocity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

limit_angular_velocity_modifier3d_get_max_angular_velocity :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_angular_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

limit_angular_velocity_modifier3d_set_exclude :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
    exclude_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_exclude", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    exclude_ := exclude_
    args := []__bindgen_gde.TypePtr {
        &exclude_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

limit_angular_velocity_modifier3d_is_exclude :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_exclude", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

limit_angular_velocity_modifier3d_reset :: proc "contextless" (
    self: Limit_Angular_Velocity_Modifier3d,
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


// properties
limit_angular_velocity_modifier3d_get_exclude :: proc "contextless" (self: Limit_Angular_Velocity_Modifier3d) -> Bool {
    return limit_angular_velocity_modifier3d_is_exclude(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
limit_angular_velocity_modifier3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("LimitAngularVelocityModifier3D", true)
}

@(private = "file")
__class_name: String_Name