package godot

import __bindgen_gde "godot:gdext"

Skeleton_Modification2d_Two_Bone_Ik_Constants :: enum {
}



skeleton_modification2d_two_bone_ik_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

skeleton_modification2d_two_bone_ik_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_skeleton_modification2d_two_bone_ik :: proc "contextless" () -> Skeleton_Modification2d_Two_Bone_Ik {
    return cast(Skeleton_Modification2d_Two_Bone_Ik)__bindgen_gde.classdb_construct_object(skeleton_modification2d_two_bone_ik_name_ref())
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

skeleton_modification2d_two_bone_ik_set_target_node :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
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

skeleton_modification2d_two_bone_ik_get_target_node :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
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

skeleton_modification2d_two_bone_ik_set_target_minimum_distance :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
    minimum_distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_target_minimum_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    minimum_distance_ := minimum_distance_
    args := []__bindgen_gde.TypePtr {
        &minimum_distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_two_bone_ik_get_target_minimum_distance :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_target_minimum_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_two_bone_ik_set_target_maximum_distance :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
    maximum_distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_target_maximum_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    maximum_distance_ := maximum_distance_
    args := []__bindgen_gde.TypePtr {
        &maximum_distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_two_bone_ik_get_target_maximum_distance :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_target_maximum_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_two_bone_ik_set_flip_bend_direction :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
    flip_direction_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flip_bend_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    flip_direction_ := flip_direction_
    args := []__bindgen_gde.TypePtr {
        &flip_direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_two_bone_ik_get_flip_bend_direction :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_flip_bend_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_two_bone_ik_set_joint_one_bone2d_node :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
    bone2d_node_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_one_bone2d_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1348162250)
    }
    self := self
    bone2d_node_ := bone2d_node_
    args := []__bindgen_gde.TypePtr {
        &bone2d_node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_two_bone_ik_get_joint_one_bone2d_node :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_one_bone2d_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4075236667)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_two_bone_ik_set_joint_one_bone_idx :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
    bone_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_one_bone_idx", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    bone_idx_ := bone_idx_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_two_bone_ik_get_joint_one_bone_idx :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_one_bone_idx", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_two_bone_ik_set_joint_two_bone2d_node :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
    bone2d_node_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_two_bone2d_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1348162250)
    }
    self := self
    bone2d_node_ := bone2d_node_
    args := []__bindgen_gde.TypePtr {
        &bone2d_node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_two_bone_ik_get_joint_two_bone2d_node :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_two_bone2d_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4075236667)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_two_bone_ik_set_joint_two_bone_idx :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
    bone_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_two_bone_idx", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    bone_idx_ := bone_idx_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_two_bone_ik_get_joint_two_bone_idx :: proc "contextless" (
    self: Skeleton_Modification2d_Two_Bone_Ik,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_two_bone_idx", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
skeleton_modification2d_two_bone_ik_get_target_nodepath :: proc "contextless" (self: Skeleton_Modification2d_Two_Bone_Ik) -> Node_Path {
    return skeleton_modification2d_two_bone_ik_get_target_node(self)
}
skeleton_modification2d_two_bone_ik_set_target_nodepath :: proc "contextless" (self: Skeleton_Modification2d_Two_Bone_Ik, value: Node_Path) {
    skeleton_modification2d_two_bone_ik_set_target_node(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
skeleton_modification2d_two_bone_ik_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SkeletonModification2DTwoBoneIK", true)
}

@(private = "file")
__class_name: String_Name