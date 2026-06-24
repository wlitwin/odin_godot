package godot

import __bindgen_gde "godot:gdext"

Skeleton_Modification2dfabrik_Constants :: enum {
}



skeleton_modification2dfabrik_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

skeleton_modification2dfabrik_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_skeleton_modification2dfabrik :: proc "contextless" () -> Skeleton_Modification2dfabrik {
    return cast(Skeleton_Modification2dfabrik)__bindgen_gde.classdb_construct_object(skeleton_modification2dfabrik_name_ref())
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

skeleton_modification2dfabrik_set_target_node :: proc "contextless" (
    self: Skeleton_Modification2dfabrik,
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

skeleton_modification2dfabrik_get_target_node :: proc "contextless" (
    self: Skeleton_Modification2dfabrik,
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

skeleton_modification2dfabrik_set_fabrik_data_chain_length :: proc "contextless" (
    self: Skeleton_Modification2dfabrik,
    length_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fabrik_data_chain_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    length_ := length_
    args := []__bindgen_gde.TypePtr {
        &length_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2dfabrik_get_fabrik_data_chain_length :: proc "contextless" (
    self: Skeleton_Modification2dfabrik,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fabrik_data_chain_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2dfabrik_set_fabrik_joint_bone2d_node :: proc "contextless" (
    self: Skeleton_Modification2dfabrik,
    joint_idx_: Int,
    bone2d_nodepath_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fabrik_joint_bone2d_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2761262315)
    }
    self := self
    joint_idx_ := joint_idx_
    bone2d_nodepath_ := bone2d_nodepath_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
        &bone2d_nodepath_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2dfabrik_get_fabrik_joint_bone2d_node :: proc "contextless" (
    self: Skeleton_Modification2dfabrik,
    joint_idx_: Int,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fabrik_joint_bone2d_node", true)
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

skeleton_modification2dfabrik_set_fabrik_joint_bone_index :: proc "contextless" (
    self: Skeleton_Modification2dfabrik,
    joint_idx_: Int,
    bone_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fabrik_joint_bone_index", true)
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

skeleton_modification2dfabrik_get_fabrik_joint_bone_index :: proc "contextless" (
    self: Skeleton_Modification2dfabrik,
    joint_idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fabrik_joint_bone_index", true)
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

skeleton_modification2dfabrik_set_fabrik_joint_magnet_position :: proc "contextless" (
    self: Skeleton_Modification2dfabrik,
    joint_idx_: Int,
    magnet_position_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fabrik_joint_magnet_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 163021252)
    }
    self := self
    joint_idx_ := joint_idx_
    magnet_position_ := magnet_position_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
        &magnet_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2dfabrik_get_fabrik_joint_magnet_position :: proc "contextless" (
    self: Skeleton_Modification2dfabrik,
    joint_idx_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fabrik_joint_magnet_position", true)
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

skeleton_modification2dfabrik_set_fabrik_joint_use_target_rotation :: proc "contextless" (
    self: Skeleton_Modification2dfabrik,
    joint_idx_: Int,
    use_target_rotation_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fabrik_joint_use_target_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    joint_idx_ := joint_idx_
    use_target_rotation_ := use_target_rotation_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
        &use_target_rotation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2dfabrik_get_fabrik_joint_use_target_rotation :: proc "contextless" (
    self: Skeleton_Modification2dfabrik,
    joint_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fabrik_joint_use_target_rotation", true)
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


// properties
skeleton_modification2dfabrik_get_target_nodepath :: proc "contextless" (self: Skeleton_Modification2dfabrik) -> Node_Path {
    return skeleton_modification2dfabrik_get_target_node(self)
}
skeleton_modification2dfabrik_set_target_nodepath :: proc "contextless" (self: Skeleton_Modification2dfabrik, value: Node_Path) {
    skeleton_modification2dfabrik_set_target_node(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
skeleton_modification2dfabrik_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SkeletonModification2DFABRIK", true)
}

@(private = "file")
__class_name: String_Name