package godot

import __bindgen_gde "godot:gdext"

Convert_Transform_Modifier3d_Constants :: enum {
}
Convert_Transform_Modifier3d_Transform_Mode :: enum int {
    Transform_Mode_Position = 0,
    Transform_Mode_Rotation = 1,
    Transform_Mode_Scale = 2,
}



convert_transform_modifier3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

convert_transform_modifier3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_convert_transform_modifier3d :: proc "contextless" () -> Convert_Transform_Modifier3d {
    return __bindgen_gde.classdb_construct_object(convert_transform_modifier3d_name_ref())
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

convert_transform_modifier3d_set_apply_transform_mode :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
    transform_mode_: Convert_Transform_Modifier3d_Transform_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_apply_transform_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1386463405)
    }
    self := self
    index_ := index_
    transform_mode_ := transform_mode_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &transform_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

convert_transform_modifier3d_get_apply_transform_mode :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
) -> (ret: Convert_Transform_Modifier3d_Transform_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_apply_transform_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3234663511)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

convert_transform_modifier3d_set_apply_axis :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
    axis_: Vector3_Vector3_Axis,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_apply_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 776736805)
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

convert_transform_modifier3d_get_apply_axis :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
) -> (ret: Vector3_Vector3_Axis) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_apply_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4131134770)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

convert_transform_modifier3d_set_apply_range_min :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
    range_min_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_apply_range_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    index_ := index_
    range_min_ := range_min_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &range_min_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

convert_transform_modifier3d_get_apply_range_min :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_apply_range_min", true)
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

convert_transform_modifier3d_set_apply_range_max :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
    range_max_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_apply_range_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    index_ := index_
    range_max_ := range_max_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &range_max_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

convert_transform_modifier3d_get_apply_range_max :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_apply_range_max", true)
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

convert_transform_modifier3d_set_reference_transform_mode :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
    transform_mode_: Convert_Transform_Modifier3d_Transform_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_reference_transform_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1386463405)
    }
    self := self
    index_ := index_
    transform_mode_ := transform_mode_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &transform_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

convert_transform_modifier3d_get_reference_transform_mode :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
) -> (ret: Convert_Transform_Modifier3d_Transform_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_reference_transform_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3234663511)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

convert_transform_modifier3d_set_reference_axis :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
    axis_: Vector3_Vector3_Axis,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_reference_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 776736805)
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

convert_transform_modifier3d_get_reference_axis :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
) -> (ret: Vector3_Vector3_Axis) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_reference_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4131134770)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

convert_transform_modifier3d_set_reference_range_min :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
    range_min_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_reference_range_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    index_ := index_
    range_min_ := range_min_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &range_min_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

convert_transform_modifier3d_get_reference_range_min :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_reference_range_min", true)
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

convert_transform_modifier3d_set_reference_range_max :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
    range_max_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_reference_range_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    index_ := index_
    range_max_ := range_max_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &range_max_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

convert_transform_modifier3d_get_reference_range_max :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
    index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_reference_range_max", true)
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

convert_transform_modifier3d_set_relative :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
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

convert_transform_modifier3d_is_relative :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
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

convert_transform_modifier3d_set_additive :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
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

convert_transform_modifier3d_is_additive :: proc "contextless" (
    self: Convert_Transform_Modifier3d,
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
convert_transform_modifier3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ConvertTransformModifier3D", true)
}

@(private = "file")
__class_name: String_Name