package godot

import __bindgen_gde "godot:gdext"

Skeleton_Modification2d_Jiggle_Constants :: enum {
}



skeleton_modification2d_jiggle_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

skeleton_modification2d_jiggle_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_skeleton_modification2d_jiggle :: proc "contextless" () -> Skeleton_Modification2d_Jiggle {
    return cast(Skeleton_Modification2d_Jiggle)__bindgen_gde.classdb_construct_object(skeleton_modification2d_jiggle_name_ref())
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

skeleton_modification2d_jiggle_set_target_node :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    target_nodepath_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_target_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1348162250)
    }
    self := self
    target_nodepath_ := target_nodepath_
    args := []__bindgen_gde.TypePtr {
        &target_nodepath_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_target_node :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_target_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4075236667)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_jiggle_data_chain_length :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    length_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_jiggle_data_chain_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    length_ := length_
    args := []__bindgen_gde.TypePtr {
        &length_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_jiggle_data_chain_length :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_jiggle_data_chain_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_stiffness :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    stiffness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stiffness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    stiffness_ := stiffness_
    args := []__bindgen_gde.TypePtr {
        &stiffness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_stiffness :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stiffness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_mass :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    mass_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    mass_ := mass_
    args := []__bindgen_gde.TypePtr {
        &mass_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_mass :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_damping :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    damping_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_damping", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    damping_ := damping_
    args := []__bindgen_gde.TypePtr {
        &damping_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_damping :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_damping", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_use_gravity :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    use_gravity_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    use_gravity_ := use_gravity_
    args := []__bindgen_gde.TypePtr {
        &use_gravity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_use_gravity :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_use_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_gravity :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    gravity_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    gravity_ := gravity_
    args := []__bindgen_gde.TypePtr {
        &gravity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_gravity :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_use_colliders :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    use_colliders_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_colliders", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    use_colliders_ := use_colliders_
    args := []__bindgen_gde.TypePtr {
        &use_colliders_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_use_colliders :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_use_colliders", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_collision_mask :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    collision_mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    collision_mask_ := collision_mask_
    args := []__bindgen_gde.TypePtr {
        &collision_mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_collision_mask :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_jiggle_joint_bone2d_node :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
    bone2d_node_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_jiggle_joint_bone2d_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2761262315)
    }
    self := self
    joint_idx_ := joint_idx_
    bone2d_node_ := bone2d_node_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
        &bone2d_node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_jiggle_joint_bone2d_node :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_jiggle_joint_bone2d_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 408788394)
    }
    self := self
    joint_idx_ := joint_idx_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_jiggle_joint_bone_index :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
    bone_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_jiggle_joint_bone_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    joint_idx_ := joint_idx_
    bone_idx_ := bone_idx_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
        &bone_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_jiggle_joint_bone_index :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_jiggle_joint_bone_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    joint_idx_ := joint_idx_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_jiggle_joint_override :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
    override_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_jiggle_joint_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    joint_idx_ := joint_idx_
    override_ := override_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
        &override_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_jiggle_joint_override :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_jiggle_joint_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    joint_idx_ := joint_idx_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_jiggle_joint_stiffness :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
    stiffness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_jiggle_joint_stiffness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    joint_idx_ := joint_idx_
    stiffness_ := stiffness_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
        &stiffness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_jiggle_joint_stiffness :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_jiggle_joint_stiffness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    joint_idx_ := joint_idx_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_jiggle_joint_mass :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
    mass_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_jiggle_joint_mass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    joint_idx_ := joint_idx_
    mass_ := mass_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
        &mass_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_jiggle_joint_mass :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_jiggle_joint_mass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    joint_idx_ := joint_idx_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_jiggle_joint_damping :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
    damping_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_jiggle_joint_damping", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    joint_idx_ := joint_idx_
    damping_ := damping_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
        &damping_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_jiggle_joint_damping :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_jiggle_joint_damping", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    joint_idx_ := joint_idx_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_jiggle_joint_use_gravity :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
    use_gravity_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_jiggle_joint_use_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    joint_idx_ := joint_idx_
    use_gravity_ := use_gravity_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
        &use_gravity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_jiggle_joint_use_gravity :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_jiggle_joint_use_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    joint_idx_ := joint_idx_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_jiggle_set_jiggle_joint_gravity :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
    gravity_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_jiggle_joint_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 163021252)
    }
    self := self
    joint_idx_ := joint_idx_
    gravity_ := gravity_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
        &gravity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_jiggle_get_jiggle_joint_gravity :: proc "contextless" (
    self: Skeleton_Modification2d_Jiggle,
    joint_idx_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_jiggle_joint_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2299179447)
    }
    self := self
    joint_idx_ := joint_idx_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
skeleton_modification2d_jiggle_get_target_nodepath :: proc "contextless" (self: Skeleton_Modification2d_Jiggle) -> Node_Path {
    return skeleton_modification2d_jiggle_get_target_node(self)
}
skeleton_modification2d_jiggle_set_target_nodepath :: proc "contextless" (self: Skeleton_Modification2d_Jiggle, value: Node_Path) {
    skeleton_modification2d_jiggle_set_target_node(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
skeleton_modification2d_jiggle_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SkeletonModification2DJiggle", true)
}

@(private = "file")
__class_name: String_Name