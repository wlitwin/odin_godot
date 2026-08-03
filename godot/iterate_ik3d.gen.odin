package godot

import __bindgen_gde "godot:gdext"

Iterate_Ik3d_Constants :: enum {
}



iterate_ik3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

iterate_ik3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_iterate_ik3d :: proc "contextless" () -> Iterate_Ik3d {
    return cast(Iterate_Ik3d)__bindgen_gde.classdb_construct_object(iterate_ik3d_name_ref())
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

iterate_ik3d_set_max_iterations :: proc "contextless" (
    self: Iterate_Ik3d,
    max_iterations_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_iterations", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    max_iterations_ := max_iterations_
    args := []__bindgen_gde.TypePtr {
        &max_iterations_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

iterate_ik3d_get_max_iterations :: proc "contextless" (
    self: Iterate_Ik3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_iterations", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

iterate_ik3d_set_min_distance :: proc "contextless" (
    self: Iterate_Ik3d,
    min_distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_min_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    min_distance_ := min_distance_
    args := []__bindgen_gde.TypePtr {
        &min_distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

iterate_ik3d_get_min_distance :: proc "contextless" (
    self: Iterate_Ik3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_min_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

iterate_ik3d_set_angular_delta_limit :: proc "contextless" (
    self: Iterate_Ik3d,
    angular_delta_limit_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_angular_delta_limit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    angular_delta_limit_ := angular_delta_limit_
    args := []__bindgen_gde.TypePtr {
        &angular_delta_limit_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

iterate_ik3d_get_angular_delta_limit :: proc "contextless" (
    self: Iterate_Ik3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_angular_delta_limit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

iterate_ik3d_set_deterministic :: proc "contextless" (
    self: Iterate_Ik3d,
    deterministic_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_deterministic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    deterministic_ := deterministic_
    args := []__bindgen_gde.TypePtr {
        &deterministic_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

iterate_ik3d_is_deterministic :: proc "contextless" (
    self: Iterate_Ik3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_deterministic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

iterate_ik3d_set_target_node :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
    target_node_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_target_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2761262315)
    }
    self := self
    index_ := index_
    target_node_ := target_node_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &target_node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

iterate_ik3d_get_target_node :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_target_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 408788394)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

iterate_ik3d_set_joint_rotation_axis :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
    joint_: Int,
    axis_: Skeleton_Modifier3d_Rotation_Axis,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_rotation_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1391134969)
    }
    self := self
    index_ := index_
    joint_ := joint_
    axis_ := axis_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
        &axis_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

iterate_ik3d_get_joint_rotation_axis :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
    joint_: Int,
) -> (ret: Skeleton_Modifier3d_Rotation_Axis) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_rotation_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3312594080)
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

iterate_ik3d_set_joint_rotation_axis_vector :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
    joint_: Int,
    axis_vector_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_rotation_axis_vector", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2866752138)
    }
    self := self
    index_ := index_
    joint_ := joint_
    axis_vector_ := axis_vector_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
        &axis_vector_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

iterate_ik3d_get_joint_rotation_axis_vector :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
    joint_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_rotation_axis_vector", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1592972041)
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

iterate_ik3d_set_joint_limitation :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
    joint_: Int,
    limitation_: Joint_Limitation3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_limitation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1194636955)
    }
    self := self
    index_ := index_
    joint_ := joint_
    limitation_ := limitation_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
        &limitation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

iterate_ik3d_get_joint_limitation :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
    joint_: Int,
) -> (ret: Joint_Limitation3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_limitation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 91665146)
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

iterate_ik3d_set_joint_limitation_right_axis :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
    joint_: Int,
    direction_: Skeleton_Modifier3d_Secondary_Direction,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_limitation_right_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3838967147)
    }
    self := self
    index_ := index_
    joint_ := joint_
    direction_ := direction_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
        &direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

iterate_ik3d_get_joint_limitation_right_axis :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
    joint_: Int,
) -> (ret: Skeleton_Modifier3d_Secondary_Direction) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_limitation_right_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 623936134)
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

iterate_ik3d_set_joint_limitation_right_axis_vector :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
    joint_: Int,
    vector_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_limitation_right_axis_vector", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2866752138)
    }
    self := self
    index_ := index_
    joint_ := joint_
    vector_ := vector_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
        &vector_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

iterate_ik3d_get_joint_limitation_right_axis_vector :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
    joint_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_limitation_right_axis_vector", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1592972041)
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

iterate_ik3d_set_joint_limitation_rotation_offset :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
    joint_: Int,
    offset_: Quaternion,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_limitation_rotation_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4188936002)
    }
    self := self
    index_ := index_
    joint_ := joint_
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

iterate_ik3d_get_joint_limitation_rotation_offset :: proc "contextless" (
    self: Iterate_Ik3d,
    index_: Int,
    joint_: Int,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_limitation_rotation_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722473700)
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


// properties
iterate_ik3d_get_deterministic :: proc "contextless" (self: Iterate_Ik3d) -> Bool {
    return iterate_ik3d_is_deterministic(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
iterate_ik3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("IterateIK3D", true)
}

@(private = "file")
__class_name: String_Name