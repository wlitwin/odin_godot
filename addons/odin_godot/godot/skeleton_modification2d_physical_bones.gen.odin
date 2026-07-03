package godot

import __bindgen_gde "godot:gdext"

Skeleton_Modification2d_Physical_Bones_Constants :: enum {
}



skeleton_modification2d_physical_bones_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

skeleton_modification2d_physical_bones_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_skeleton_modification2d_physical_bones :: proc "contextless" () -> Skeleton_Modification2d_Physical_Bones {
    return cast(Skeleton_Modification2d_Physical_Bones)__bindgen_gde.classdb_construct_object(skeleton_modification2d_physical_bones_name_ref())
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

skeleton_modification2d_physical_bones_set_physical_bone_chain_length :: proc "contextless" (
    self: Skeleton_Modification2d_Physical_Bones,
    length_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_physical_bone_chain_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    length_ := length_
    args := []__bindgen_gde.TypePtr {
        &length_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_physical_bones_get_physical_bone_chain_length :: proc "contextless" (
    self: Skeleton_Modification2d_Physical_Bones,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_physical_bone_chain_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

skeleton_modification2d_physical_bones_set_physical_bone_node :: proc "contextless" (
    self: Skeleton_Modification2d_Physical_Bones,
    joint_idx_: Int,
    physicalbone2d_node_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_physical_bone_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2761262315)
    }
    self := self
    joint_idx_ := joint_idx_
    physicalbone2d_node_ := physicalbone2d_node_
    args := []__bindgen_gde.TypePtr {
        &joint_idx_,
        &physicalbone2d_node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_physical_bones_get_physical_bone_node :: proc "contextless" (
    self: Skeleton_Modification2d_Physical_Bones,
    joint_idx_: Int,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_physical_bone_node", true)
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

skeleton_modification2d_physical_bones_fetch_physical_bones :: proc "contextless" (
    self: Skeleton_Modification2d_Physical_Bones,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("fetch_physical_bones", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_physical_bones_start_simulation :: proc "contextless" (
    self: Skeleton_Modification2d_Physical_Bones,
    bones_: Typed_Array(String_Name),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("start_simulation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2787316981)
    }
    self := self
    bones_ := bones_
    args := []__bindgen_gde.TypePtr {
        &bones_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

skeleton_modification2d_physical_bones_stop_simulation :: proc "contextless" (
    self: Skeleton_Modification2d_Physical_Bones,
    bones_: Typed_Array(String_Name),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("stop_simulation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2787316981)
    }
    self := self
    bones_ := bones_
    args := []__bindgen_gde.TypePtr {
        &bones_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
skeleton_modification2d_physical_bones_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SkeletonModification2DPhysicalBones", true)
}

@(private = "file")
__class_name: String_Name