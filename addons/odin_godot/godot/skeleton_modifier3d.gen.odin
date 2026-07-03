package godot

import __bindgen_gde "godot:gdext"

Skeleton_Modifier3d_Constants :: enum {
}
Skeleton_Modifier3d_Bone_Axis :: enum int {
    Bone_Axis_Plus_X = 0,
    Bone_Axis_Minus_X = 1,
    Bone_Axis_Plus_Y = 2,
    Bone_Axis_Minus_Y = 3,
    Bone_Axis_Plus_Z = 4,
    Bone_Axis_Minus_Z = 5,
}
Skeleton_Modifier3d_Bone_Direction :: enum int {
    Bone_Direction_Plus_X = 0,
    Bone_Direction_Minus_X = 1,
    Bone_Direction_Plus_Y = 2,
    Bone_Direction_Minus_Y = 3,
    Bone_Direction_Plus_Z = 4,
    Bone_Direction_Minus_Z = 5,
    Bone_Direction_From_Parent = 6,
}
Skeleton_Modifier3d_Secondary_Direction :: enum int {
    Secondary_Direction_None = 0,
    Secondary_Direction_Plus_X = 1,
    Secondary_Direction_Minus_X = 2,
    Secondary_Direction_Plus_Y = 3,
    Secondary_Direction_Minus_Y = 4,
    Secondary_Direction_Plus_Z = 5,
    Secondary_Direction_Minus_Z = 6,
    Secondary_Direction_Custom = 7,
}
Skeleton_Modifier3d_Rotation_Axis :: enum int {
    Rotation_Axis_X = 0,
    Rotation_Axis_Y = 1,
    Rotation_Axis_Z = 2,
    Rotation_Axis_All = 3,
    Rotation_Axis_Custom = 4,
}



skeleton_modifier3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

skeleton_modifier3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_skeleton_modifier3d :: proc "contextless" () -> Skeleton_Modifier3d {
    return __bindgen_gde.classdb_construct_object(skeleton_modifier3d_name_ref())
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

skeleton_modifier3d__process_modification_with_delta :: proc "contextless" (
    self: Skeleton_Modifier3d,
    delta_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_process_modification_with_delta", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    delta_ := delta_
    args := []__bindgen_gde.TypePtr {
        &delta_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modifier3d__process_modification :: proc "contextless" (
    self: Skeleton_Modifier3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_process_modification", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modifier3d__skeleton_changed :: proc "contextless" (
    self: Skeleton_Modifier3d,
    old_skeleton_: Skeleton3d,
    new_skeleton_: Skeleton3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_skeleton_changed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2926744397)
    }
    self := self
    old_skeleton_ := old_skeleton_
    new_skeleton_ := new_skeleton_
    args := []__bindgen_gde.TypePtr {
        &old_skeleton_,
        &new_skeleton_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modifier3d__validate_bone_names :: proc "contextless" (
    self: Skeleton_Modifier3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_validate_bone_names", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modifier3d_get_skeleton :: proc "contextless" (
    self: Skeleton_Modifier3d,
) -> (ret: Skeleton3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skeleton", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1488626673)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modifier3d_set_active :: proc "contextless" (
    self: Skeleton_Modifier3d,
    active_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    active_ := active_
    args := []__bindgen_gde.TypePtr {
        &active_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modifier3d_is_active :: proc "contextless" (
    self: Skeleton_Modifier3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modifier3d_set_influence :: proc "contextless" (
    self: Skeleton_Modifier3d,
    influence_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_influence", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    influence_ := influence_
    args := []__bindgen_gde.TypePtr {
        &influence_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modifier3d_get_influence :: proc "contextless" (
    self: Skeleton_Modifier3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_influence", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
skeleton_modifier3d_get_active :: proc "contextless" (self: Skeleton_Modifier3d) -> Bool {
    return skeleton_modifier3d_is_active(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
skeleton_modifier3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SkeletonModifier3D", true)
}

@(private = "file")
__class_name: String_Name