package godot

import __bindgen_gde "godot:gdext"

Copy_Transform_Modifier3d_Constants :: enum {
}

Copy_Transform_Modifier3d_Transform_Flag :: enum i64 {
    Transform_Flag_Position = 1,
    Transform_Flag_Rotation = 2,
    Transform_Flag_Scale = 4,
    Transform_Flag_All = 7,
}
Copy_Transform_Modifier3d_Axis_Flag :: enum i64 {
    Axis_Flag_X = 1,
    Axis_Flag_Y = 2,
    Axis_Flag_Z = 4,
    Axis_Flag_All = 7,
}


copy_transform_modifier3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

copy_transform_modifier3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_copy_transform_modifier3d :: proc "contextless" () -> Copy_Transform_Modifier3d {
    return cast(Copy_Transform_Modifier3d)__bindgen_gde.classdb_construct_object(copy_transform_modifier3d_name_ref())
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

copy_transform_modifier3d_set_copy_flags :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    copy_flags_: Copy_Transform_Modifier3d_Transform_Flag,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_copy_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2252507859)
    }
    self := self
    index_ := index_
    copy_flags_ := copy_flags_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &copy_flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

copy_transform_modifier3d_get_copy_flags :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Copy_Transform_Modifier3d_Transform_Flag) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_copy_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1685185931)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

copy_transform_modifier3d_set_axis_flags :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    axis_flags_: Copy_Transform_Modifier3d_Axis_Flag,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_axis_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2044211897)
    }
    self := self
    index_ := index_
    axis_flags_ := axis_flags_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &axis_flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

copy_transform_modifier3d_get_axis_flags :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Copy_Transform_Modifier3d_Axis_Flag) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_axis_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 992162046)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

copy_transform_modifier3d_set_invert_flags :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    axis_flags_: Copy_Transform_Modifier3d_Axis_Flag,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_invert_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2044211897)
    }
    self := self
    index_ := index_
    axis_flags_ := axis_flags_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &axis_flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

copy_transform_modifier3d_get_invert_flags :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Copy_Transform_Modifier3d_Axis_Flag) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_invert_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 992162046)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

copy_transform_modifier3d_set_copy_position :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_copy_position", true)
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

copy_transform_modifier3d_is_position_copying :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_position_copying", true)
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

copy_transform_modifier3d_set_copy_rotation :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_copy_rotation", true)
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

copy_transform_modifier3d_is_rotation_copying :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_rotation_copying", true)
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

copy_transform_modifier3d_set_copy_scale :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_copy_scale", true)
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

copy_transform_modifier3d_is_scale_copying :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_scale_copying", true)
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

copy_transform_modifier3d_set_axis_x_enabled :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_axis_x_enabled", true)
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

copy_transform_modifier3d_is_axis_x_enabled :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_axis_x_enabled", true)
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

copy_transform_modifier3d_set_axis_y_enabled :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_axis_y_enabled", true)
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

copy_transform_modifier3d_is_axis_y_enabled :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_axis_y_enabled", true)
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

copy_transform_modifier3d_set_axis_z_enabled :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_axis_z_enabled", true)
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

copy_transform_modifier3d_is_axis_z_enabled :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_axis_z_enabled", true)
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

copy_transform_modifier3d_set_axis_x_inverted :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_axis_x_inverted", true)
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

copy_transform_modifier3d_is_axis_x_inverted :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_axis_x_inverted", true)
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

copy_transform_modifier3d_set_axis_y_inverted :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_axis_y_inverted", true)
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

copy_transform_modifier3d_is_axis_y_inverted :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_axis_y_inverted", true)
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

copy_transform_modifier3d_set_axis_z_inverted :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_axis_z_inverted", true)
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

copy_transform_modifier3d_is_axis_z_inverted :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_axis_z_inverted", true)
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

copy_transform_modifier3d_set_relative :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_relative", true)
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

copy_transform_modifier3d_is_relative :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_relative", true)
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

copy_transform_modifier3d_set_additive :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_additive", true)
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

copy_transform_modifier3d_is_additive :: proc "contextless" (
    self: Copy_Transform_Modifier3d,
    index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_additive", true)
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


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
copy_transform_modifier3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("CopyTransformModifier3D", true)
}

@(private = "file")
__class_name: String_Name