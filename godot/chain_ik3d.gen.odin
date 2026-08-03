package godot

import __bindgen_gde "godot:gdext"

Chain_Ik3d_Constants :: enum {
}



chain_ik3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

chain_ik3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_chain_ik3d :: proc "contextless" () -> Chain_Ik3d {
    return cast(Chain_Ik3d)__bindgen_gde.classdb_construct_object(chain_ik3d_name_ref())
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

chain_ik3d_set_root_bone_name :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_get_root_bone_name :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_set_root_bone :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_get_root_bone :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_set_end_bone_name :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_get_end_bone_name :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_set_end_bone :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_get_end_bone :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_set_extend_end_bone :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_is_end_bone_extended :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_set_end_bone_direction :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_get_end_bone_direction :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_set_end_bone_length :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_get_end_bone_length :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_get_joint_bone_name :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_get_joint_bone :: proc "contextless" (
    self: Chain_Ik3d,
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

chain_ik3d_get_joint_count :: proc "contextless" (
    self: Chain_Ik3d,
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


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
chain_ik3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ChainIK3D", true)
}

@(private = "file")
__class_name: String_Name