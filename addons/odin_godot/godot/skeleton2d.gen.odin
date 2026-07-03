package godot

import __bindgen_gde "godot:gdext"

Skeleton2d_Constants :: enum {
}



skeleton2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

skeleton2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_skeleton2d :: proc "contextless" () -> Skeleton2d {
    return __bindgen_gde.classdb_construct_object(skeleton2d_name_ref())
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

skeleton2d_get_bone_count :: proc "contextless" (
    self: Skeleton2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bone_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton2d_get_bone :: proc "contextless" (
    self: Skeleton2d,
    idx_: Int,
) -> (ret: Bone2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bone", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2556267111)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton2d_get_skeleton :: proc "contextless" (
    self: Skeleton2d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skeleton", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2944877500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton2d_set_modification_stack :: proc "contextless" (
    self: Skeleton2d,
    modification_stack_: Skeleton_Modification_Stack2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_modification_stack", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3907307132)
    }
    self := self
    modification_stack_ := modification_stack_
    args := []__bindgen_gde.TypePtr {
        &modification_stack_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton2d_get_modification_stack :: proc "contextless" (
    self: Skeleton2d,
) -> (ret: Skeleton_Modification_Stack2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_modification_stack", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2107508396)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton2d_execute_modifications :: proc "contextless" (
    self: Skeleton2d,
    delta_: f64,
    execution_mode_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("execute_modifications", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1005356550)
    }
    self := self
    delta_ := delta_
    execution_mode_ := execution_mode_
    args := []__bindgen_gde.TypePtr {
        &delta_,
        &execution_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton2d_set_bone_local_pose_override :: proc "contextless" (
    self: Skeleton2d,
    bone_idx_: Int,
    override_pose_: Transform2d,
    strength_: f64,
    persistent_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bone_local_pose_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 555457532)
    }
    self := self
    bone_idx_ := bone_idx_
    override_pose_ := override_pose_
    strength_ := strength_
    persistent_ := persistent_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
        &override_pose_,
        &strength_,
        &persistent_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton2d_get_bone_local_pose_override :: proc "contextless" (
    self: Skeleton2d,
    bone_idx_: Int,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bone_local_pose_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2995540667)
    }
    self := self
    bone_idx_ := bone_idx_
    args := []__bindgen_gde.TypePtr {
        &bone_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
skeleton2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Skeleton2D", true)
}

@(private = "file")
__class_name: String_Name