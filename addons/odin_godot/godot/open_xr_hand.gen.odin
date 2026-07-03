package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Hand_Constants :: enum {
}
Open_Xr_Hand_Hands :: enum int {
    Hand_Left = 0,
    Hand_Right = 1,
    Hand_Max = 2,
}
Open_Xr_Hand_Motion_Range :: enum int {
    Motion_Range_Unobstructed = 0,
    Motion_Range_Conform_To_Controller = 1,
    Motion_Range_Max = 2,
}
Open_Xr_Hand_Skeleton_Rig :: enum int {
    Skeleton_Rig_Openxr = 0,
    Skeleton_Rig_Humanoid = 1,
    Skeleton_Rig_Max = 2,
}
Open_Xr_Hand_Bone_Update :: enum int {
    Bone_Update_Full = 0,
    Bone_Update_Rotation_Only = 1,
    Bone_Update_Max = 2,
}



open_xr_hand_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_hand_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_hand :: proc "contextless" () -> Open_Xr_Hand {
    return __bindgen_gde.classdb_construct_object(open_xr_hand_name_ref())
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

open_xr_hand_set_hand :: proc "contextless" (
    self: Open_Xr_Hand,
    hand_: Open_Xr_Hand_Hands,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hand", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1849328560)
    }
    self := self
    hand_ := hand_
    args := []__bindgen_gde.TypePtr {
        &hand_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_hand_get_hand :: proc "contextless" (
    self: Open_Xr_Hand,
) -> (ret: Open_Xr_Hand_Hands) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2850644561)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_hand_set_hand_skeleton :: proc "contextless" (
    self: Open_Xr_Hand,
    hand_skeleton_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hand_skeleton", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1348162250)
    }
    self := self
    hand_skeleton_ := hand_skeleton_
    args := []__bindgen_gde.TypePtr {
        &hand_skeleton_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_hand_get_hand_skeleton :: proc "contextless" (
    self: Open_Xr_Hand,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_skeleton", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4075236667)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_hand_set_motion_range :: proc "contextless" (
    self: Open_Xr_Hand,
    motion_range_: Open_Xr_Hand_Motion_Range,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_motion_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3326516003)
    }
    self := self
    motion_range_ := motion_range_
    args := []__bindgen_gde.TypePtr {
        &motion_range_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_hand_get_motion_range :: proc "contextless" (
    self: Open_Xr_Hand,
) -> (ret: Open_Xr_Hand_Motion_Range) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_motion_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2191822314)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_hand_set_skeleton_rig :: proc "contextless" (
    self: Open_Xr_Hand,
    skeleton_rig_: Open_Xr_Hand_Skeleton_Rig,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_skeleton_rig", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1528072213)
    }
    self := self
    skeleton_rig_ := skeleton_rig_
    args := []__bindgen_gde.TypePtr {
        &skeleton_rig_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_hand_get_skeleton_rig :: proc "contextless" (
    self: Open_Xr_Hand,
) -> (ret: Open_Xr_Hand_Skeleton_Rig) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skeleton_rig", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 968409338)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_hand_set_bone_update :: proc "contextless" (
    self: Open_Xr_Hand,
    bone_update_: Open_Xr_Hand_Bone_Update,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bone_update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3144625444)
    }
    self := self
    bone_update_ := bone_update_
    args := []__bindgen_gde.TypePtr {
        &bone_update_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_hand_get_bone_update :: proc "contextless" (
    self: Open_Xr_Hand,
) -> (ret: Open_Xr_Hand_Bone_Update) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bone_update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1310695248)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
open_xr_hand_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRHand", true)
}

@(private = "file")
__class_name: String_Name