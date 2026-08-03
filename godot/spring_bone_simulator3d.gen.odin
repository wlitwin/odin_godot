package godot

import __bindgen_gde "godot:gdext"

Spring_Bone_Simulator3d_Constants :: enum {
}
Spring_Bone_Simulator3d_Center_From :: enum int {
    Center_From_World_Origin = 0,
    Center_From_Node = 1,
    Center_From_Bone = 2,
}



spring_bone_simulator3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

spring_bone_simulator3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_spring_bone_simulator3d :: proc "contextless" () -> Spring_Bone_Simulator3d {
    return cast(Spring_Bone_Simulator3d)__bindgen_gde.classdb_construct_object(spring_bone_simulator3d_name_ref())
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

spring_bone_simulator3d_set_root_bone_name :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_get_root_bone_name :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_set_root_bone :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_get_root_bone :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_set_end_bone_name :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_get_end_bone_name :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_set_end_bone :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_get_end_bone :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_set_extend_end_bone :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_is_end_bone_extended :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_set_end_bone_direction :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_get_end_bone_direction :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_set_end_bone_length :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    length_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_end_bone_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    index_ := index_
    length_ := length_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &length_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_end_bone_length :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_end_bone_length", true)
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

spring_bone_simulator3d_set_center_from :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    center_from_: Spring_Bone_Simulator3d_Center_From,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_center_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2551505749)
    }
    self := self
    index_ := index_
    center_from_ := center_from_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &center_from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_center_from :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: Spring_Bone_Simulator3d_Center_From) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2721930813)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

spring_bone_simulator3d_set_center_node :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    node_path_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_center_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2761262315)
    }
    self := self
    index_ := index_
    node_path_ := node_path_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &node_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_center_node :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center_node", true)
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

spring_bone_simulator3d_set_center_bone_name :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    bone_name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_center_bone_name", true)
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

spring_bone_simulator3d_get_center_bone_name :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center_bone_name", true)
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

spring_bone_simulator3d_set_center_bone :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    bone_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_center_bone", true)
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

spring_bone_simulator3d_get_center_bone :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center_bone", true)
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

spring_bone_simulator3d_set_radius :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    radius_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    index_ := index_
    radius_ := radius_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_radius :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_radius", true)
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

spring_bone_simulator3d_set_rotation_axis :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    axis_: Skeleton_Modifier3d_Rotation_Axis,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rotation_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1539703856)
    }
    self := self
    index_ := index_
    axis_ := axis_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &axis_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_rotation_axis :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: Skeleton_Modifier3d_Rotation_Axis) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rotation_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2844851118)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

spring_bone_simulator3d_set_rotation_axis_vector :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    vector_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rotation_axis_vector", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1530502735)
    }
    self := self
    index_ := index_
    vector_ := vector_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &vector_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_rotation_axis_vector :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rotation_axis_vector", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 711720468)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

spring_bone_simulator3d_set_radius_damping_curve :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    curve_: Curve,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_radius_damping_curve", true)
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

spring_bone_simulator3d_get_radius_damping_curve :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: Curve) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_radius_damping_curve", true)
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

spring_bone_simulator3d_set_stiffness :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    stiffness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stiffness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    index_ := index_
    stiffness_ := stiffness_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &stiffness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_stiffness :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stiffness", true)
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

spring_bone_simulator3d_set_stiffness_damping_curve :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    curve_: Curve,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stiffness_damping_curve", true)
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

spring_bone_simulator3d_get_stiffness_damping_curve :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: Curve) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stiffness_damping_curve", true)
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

spring_bone_simulator3d_set_drag :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    drag_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_drag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    index_ := index_
    drag_ := drag_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &drag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_drag :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_drag", true)
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

spring_bone_simulator3d_set_drag_damping_curve :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    curve_: Curve,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_drag_damping_curve", true)
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

spring_bone_simulator3d_get_drag_damping_curve :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: Curve) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_drag_damping_curve", true)
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

spring_bone_simulator3d_set_gravity :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    gravity_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    index_ := index_
    gravity_ := gravity_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &gravity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_gravity :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gravity", true)
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

spring_bone_simulator3d_set_gravity_damping_curve :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    curve_: Curve,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gravity_damping_curve", true)
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

spring_bone_simulator3d_get_gravity_damping_curve :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: Curve) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gravity_damping_curve", true)
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

spring_bone_simulator3d_set_gravity_direction :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    gravity_direction_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gravity_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1530502735)
    }
    self := self
    index_ := index_
    gravity_direction_ := gravity_direction_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &gravity_direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_gravity_direction :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gravity_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 711720468)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

spring_bone_simulator3d_set_setting_count :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_get_setting_count :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_clear_settings :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_set_individual_config :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_individual_config", true)
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

spring_bone_simulator3d_is_config_individual :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_config_individual", true)
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

spring_bone_simulator3d_get_joint_bone_name :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_get_joint_bone :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_set_joint_rotation_axis :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_get_joint_rotation_axis :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_set_joint_rotation_axis_vector :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    joint_: Int,
    vector_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_rotation_axis_vector", true)
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

spring_bone_simulator3d_get_joint_rotation_axis_vector :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_set_joint_radius :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    joint_: Int,
    radius_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    index_ := index_
    joint_ := joint_
    radius_ := radius_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
        &radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_joint_radius :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    joint_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_radius", true)
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

spring_bone_simulator3d_set_joint_stiffness :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    joint_: Int,
    stiffness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_stiffness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    index_ := index_
    joint_ := joint_
    stiffness_ := stiffness_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
        &stiffness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_joint_stiffness :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    joint_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_stiffness", true)
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

spring_bone_simulator3d_set_joint_drag :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    joint_: Int,
    drag_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_drag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    index_ := index_
    joint_ := joint_
    drag_ := drag_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
        &drag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_joint_drag :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    joint_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_drag", true)
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

spring_bone_simulator3d_set_joint_gravity :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    joint_: Int,
    gravity_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    index_ := index_
    joint_ := joint_
    gravity_ := gravity_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
        &gravity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_joint_gravity :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    joint_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_gravity", true)
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

spring_bone_simulator3d_set_joint_gravity_direction :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    joint_: Int,
    gravity_direction_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_gravity_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2866752138)
    }
    self := self
    index_ := index_
    joint_ := joint_
    gravity_direction_ := gravity_direction_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &joint_,
        &gravity_direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_joint_gravity_direction :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    joint_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_gravity_direction", true)
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

spring_bone_simulator3d_get_joint_count :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_set_enable_all_child_collisions :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_enable_all_child_collisions", true)
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

spring_bone_simulator3d_are_all_child_collisions_enabled :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("are_all_child_collisions_enabled", true)
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

spring_bone_simulator3d_set_exclude_collision_path :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    collision_: Int,
    node_path_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_exclude_collision_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 132481804)
    }
    self := self
    index_ := index_
    collision_ := collision_
    node_path_ := node_path_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &collision_,
        &node_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_exclude_collision_path :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    collision_: Int,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_exclude_collision_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 464924783)
    }
    self := self
    index_ := index_
    collision_ := collision_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &collision_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

spring_bone_simulator3d_set_exclude_collision_count :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_exclude_collision_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    index_ := index_
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_exclude_collision_count :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_exclude_collision_count", true)
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

spring_bone_simulator3d_clear_exclude_collisions :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_exclude_collisions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_set_collision_path :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    collision_: Int,
    node_path_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 132481804)
    }
    self := self
    index_ := index_
    collision_ := collision_
    node_path_ := node_path_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &collision_,
        &node_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_collision_path :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    collision_: Int,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 464924783)
    }
    self := self
    index_ := index_
    collision_ := collision_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &collision_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

spring_bone_simulator3d_set_collision_count :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    index_ := index_
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_collision_count :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_count", true)
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

spring_bone_simulator3d_clear_collisions :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_collisions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_set_external_force :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
    force_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_external_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

spring_bone_simulator3d_get_external_force :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_external_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

spring_bone_simulator3d_set_mutable_bone_axes :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_are_bone_axes_mutable :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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

spring_bone_simulator3d_reset :: proc "contextless" (
    self: Spring_Bone_Simulator3d,
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
spring_bone_simulator3d_get_mutable_bone_axes :: proc "contextless" (self: Spring_Bone_Simulator3d) -> Bool {
    return spring_bone_simulator3d_are_bone_axes_mutable(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
spring_bone_simulator3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SpringBoneSimulator3D", true)
}

@(private = "file")
__class_name: String_Name