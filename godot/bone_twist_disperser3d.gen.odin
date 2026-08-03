package godot

import __bindgen_gde "godot:gdext"

Bone_Twist_Disperser3d_Constants :: enum {
}
Bone_Twist_Disperser3d_Disperse_Mode :: enum int {
    Disperse_Mode_Even = 0,
    Disperse_Mode_Weighted = 1,
    Disperse_Mode_Custom = 2,
}



bone_twist_disperser3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

bone_twist_disperser3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_bone_twist_disperser3d :: proc "contextless" () -> Bone_Twist_Disperser3d {
    return cast(Bone_Twist_Disperser3d)__bindgen_gde.classdb_construct_object(bone_twist_disperser3d_name_ref())
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

bone_twist_disperser3d_set_setting_count :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_setting_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

bone_twist_disperser3d_get_setting_count :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_setting_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_twist_disperser3d_clear_settings :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_settings", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

bone_twist_disperser3d_set_mutable_bone_axes :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mutable_bone_axes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

bone_twist_disperser3d_are_bone_axes_mutable :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("are_bone_axes_mutable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_twist_disperser3d_set_root_bone_name :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
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

bone_twist_disperser3d_get_root_bone_name :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
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

bone_twist_disperser3d_set_root_bone :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
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

bone_twist_disperser3d_get_root_bone :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
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

bone_twist_disperser3d_set_end_bone_name :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
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

bone_twist_disperser3d_get_end_bone_name :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
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

bone_twist_disperser3d_set_end_bone :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
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

bone_twist_disperser3d_get_end_bone :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
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

bone_twist_disperser3d_get_reference_bone_name :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_reference_bone_name", true)
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

bone_twist_disperser3d_get_reference_bone :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_reference_bone", true)
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

bone_twist_disperser3d_set_extend_end_bone :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_extend_end_bone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    index_ := index_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

bone_twist_disperser3d_is_end_bone_extended :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_end_bone_extended", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_twist_disperser3d_set_end_bone_direction :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
    bone_direction_: Skeleton_Modifier3d_Bone_Direction,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_end_bone_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2838484201)
    }
    self := self
    index_ := index_
    bone_direction_ := bone_direction_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &bone_direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

bone_twist_disperser3d_get_end_bone_direction :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
) -> (ret: Skeleton_Modifier3d_Bone_Direction) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_end_bone_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1843036459)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_twist_disperser3d_set_twist_from_rest :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_twist_from_rest", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    index_ := index_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

bone_twist_disperser3d_is_twist_from_rest :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_twist_from_rest", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_twist_disperser3d_set_twist_from :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
    from_: Quaternion,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_twist_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2823819782)
    }
    self := self
    index_ := index_
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

bone_twist_disperser3d_get_twist_from :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_twist_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 476865136)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_twist_disperser3d_set_disperse_mode :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
    disperse_mode_: Bone_Twist_Disperser3d_Disperse_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_disperse_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2954194337)
    }
    self := self
    index_ := index_
    disperse_mode_ := disperse_mode_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &disperse_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

bone_twist_disperser3d_get_disperse_mode :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
) -> (ret: Bone_Twist_Disperser3d_Disperse_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_disperse_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1326397005)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_twist_disperser3d_set_weight_position :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
    weight_position_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_weight_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    index_ := index_
    weight_position_ := weight_position_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &weight_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

bone_twist_disperser3d_get_weight_position :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_weight_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_twist_disperser3d_set_damping_curve :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
    curve_: Curve,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_damping_curve", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1447180063)
    }
    self := self
    index_ := index_
    curve_ := curve_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &curve_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

bone_twist_disperser3d_get_damping_curve :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
) -> (ret: Curve) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_damping_curve", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 747537754)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_twist_disperser3d_get_joint_bone_name :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
    joint_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_bone_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1391810591)
    }
    self := self
    index_ := index_
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_twist_disperser3d_get_joint_bone :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
    joint_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_bone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175239445)
    }
    self := self
    index_ := index_
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_twist_disperser3d_get_joint_twist_amount :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
    joint_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_twist_amount", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    index_ := index_
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

bone_twist_disperser3d_set_joint_twist_amount :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
    joint_: Int,
    twist_amount_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_twist_amount", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    index_ := index_
    joint_ := joint_
    twist_amount_ := twist_amount_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
        &twist_amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

bone_twist_disperser3d_get_joint_count :: proc "contextless" (
    self: Bone_Twist_Disperser3d,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_count", true)
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


// properties
bone_twist_disperser3d_get_mutable_bone_axes :: proc "contextless" (self: Bone_Twist_Disperser3d) -> Bool {
    return bone_twist_disperser3d_are_bone_axes_mutable(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
bone_twist_disperser3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("BoneTwistDisperser3D", true)
}

@(private = "file")
__class_name: String_Name