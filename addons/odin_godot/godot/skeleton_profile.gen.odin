package godot

import __bindgen_gde "godot:gdext"

Skeleton_Profile_Constants :: enum {
}
Skeleton_Profile_Tail_Direction :: enum int {
    Tail_Direction_Average_Children = 0,
    Tail_Direction_Specific_Child = 1,
    Tail_Direction_End = 2,
}



skeleton_profile_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

skeleton_profile_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_skeleton_profile :: proc "contextless" () -> Skeleton_Profile {
    return cast(Skeleton_Profile)__bindgen_gde.classdb_construct_object(skeleton_profile_name_ref())
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

skeleton_profile_set_root_bone :: proc "contextless" (
    self: Skeleton_Profile,
    bone_name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_root_bone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    bone_name_ := bone_name_
    args := []__bindgen_gde.TypePtr {
        &bone_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_profile_get_root_bone :: proc "contextless" (
    self: Skeleton_Profile,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_root_bone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2737447660)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_set_scale_base_bone :: proc "contextless" (
    self: Skeleton_Profile,
    bone_name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scale_base_bone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    bone_name_ := bone_name_
    args := []__bindgen_gde.TypePtr {
        &bone_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_profile_get_scale_base_bone :: proc "contextless" (
    self: Skeleton_Profile,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scale_base_bone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2737447660)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_set_group_size :: proc "contextless" (
    self: Skeleton_Profile,
    size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_group_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_profile_get_group_size :: proc "contextless" (
    self: Skeleton_Profile,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_group_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_get_group_name :: proc "contextless" (
    self: Skeleton_Profile,
    group_idx_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_group_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 659327637)
    }
    self := self
    group_idx_ := group_idx_
    args := []__bindgen_gde.TypePtr {
        &group_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_set_group_name :: proc "contextless" (
    self: Skeleton_Profile,
    group_idx_: Int,
    group_name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_group_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3780747571)
    }
    self := self
    group_idx_ := group_idx_
    group_name_ := group_name_
    args := []__bindgen_gde.TypePtr {
        &group_idx_,
        &group_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_profile_get_texture :: proc "contextless" (
    self: Skeleton_Profile,
    group_idx_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3536238170)
    }
    self := self
    group_idx_ := group_idx_
    args := []__bindgen_gde.TypePtr {
        &group_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_set_texture :: proc "contextless" (
    self: Skeleton_Profile,
    group_idx_: Int,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 666127730)
    }
    self := self
    group_idx_ := group_idx_
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &group_idx_,
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_profile_set_bone_size :: proc "contextless" (
    self: Skeleton_Profile,
    size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bone_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_profile_get_bone_size :: proc "contextless" (
    self: Skeleton_Profile,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bone_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_find_bone :: proc "contextless" (
    self: Skeleton_Profile,
    bone_name_: String_Name,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_bone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2458036349)
    }
    self := self
    bone_name_ := bone_name_
    args := []__bindgen_gde.TypePtr {
        &bone_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_get_bone_name :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bone_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 659327637)
    }
    self := self
    bone_idx_ := bone_idx_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_set_bone_name :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
    bone_name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bone_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3780747571)
    }
    self := self
    bone_idx_ := bone_idx_
    bone_name_ := bone_name_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
        &bone_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_profile_get_bone_parent :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bone_parent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 659327637)
    }
    self := self
    bone_idx_ := bone_idx_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_set_bone_parent :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
    bone_parent_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bone_parent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3780747571)
    }
    self := self
    bone_idx_ := bone_idx_
    bone_parent_ := bone_parent_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
        &bone_parent_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_profile_get_tail_direction :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
) -> (ret: Skeleton_Profile_Tail_Direction) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tail_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2675997574)
    }
    self := self
    bone_idx_ := bone_idx_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_set_tail_direction :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
    tail_direction_: Skeleton_Profile_Tail_Direction,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tail_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1231951015)
    }
    self := self
    bone_idx_ := bone_idx_
    tail_direction_ := tail_direction_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
        &tail_direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_profile_get_bone_tail :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bone_tail", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 659327637)
    }
    self := self
    bone_idx_ := bone_idx_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_set_bone_tail :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
    bone_tail_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bone_tail", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3780747571)
    }
    self := self
    bone_idx_ := bone_idx_
    bone_tail_ := bone_tail_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
        &bone_tail_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_profile_get_reference_pose :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_reference_pose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1965739696)
    }
    self := self
    bone_idx_ := bone_idx_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_set_reference_pose :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
    bone_name_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_reference_pose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3616898986)
    }
    self := self
    bone_idx_ := bone_idx_
    bone_name_ := bone_name_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
        &bone_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_profile_get_handle_offset :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_handle_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2299179447)
    }
    self := self
    bone_idx_ := bone_idx_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_set_handle_offset :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
    handle_offset_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_handle_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 163021252)
    }
    self := self
    bone_idx_ := bone_idx_
    handle_offset_ := handle_offset_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
        &handle_offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_profile_get_group :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 659327637)
    }
    self := self
    bone_idx_ := bone_idx_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_set_group :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
    group_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3780747571)
    }
    self := self
    bone_idx_ := bone_idx_
    group_ := group_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
        &group_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_profile_is_required :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_required", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    bone_idx_ := bone_idx_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_profile_set_required :: proc "contextless" (
    self: Skeleton_Profile,
    bone_idx_: Int,
    required_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_required", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    bone_idx_ := bone_idx_
    required_ := required_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
        &required_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
skeleton_profile_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SkeletonProfile", true)
}

@(private = "file")
__class_name: String_Name