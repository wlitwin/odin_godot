package godot

import __bindgen_gde "godot:gdext"

Animation_Constants :: enum {
}
Animation_Track_Type :: enum int {
    Type_Value = 0,
    Type_Position_3d = 1,
    Type_Rotation_3d = 2,
    Type_Scale_3d = 3,
    Type_Blend_Shape = 4,
    Type_Method = 5,
    Type_Bezier = 6,
    Type_Audio = 7,
    Type_Animation = 8,
}
Animation_Interpolation_Type :: enum int {
    Interpolation_Nearest = 0,
    Interpolation_Linear = 1,
    Interpolation_Cubic = 2,
    Interpolation_Linear_Angle = 3,
    Interpolation_Cubic_Angle = 4,
}
Animation_Update_Mode :: enum int {
    Update_Continuous = 0,
    Update_Discrete = 1,
    Update_Capture = 2,
}
Animation_Loop_Mode :: enum int {
    Loop_None = 0,
    Loop_Linear = 1,
    Loop_Pingpong = 2,
}
Animation_Looped_Flag :: enum int {
    Looped_Flag_None = 0,
    Looped_Flag_End = 1,
    Looped_Flag_Start = 2,
}
Animation_Find_Mode :: enum int {
    Find_Mode_Nearest = 0,
    Find_Mode_Approx = 1,
    Find_Mode_Exact = 2,
}



animation_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

animation_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_animation :: proc "contextless" () -> Animation {
    return cast(Animation)__bindgen_gde.classdb_construct_object(animation_name_ref())
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

animation_add_track :: proc "contextless" (
    self: Animation,
    type_: Animation_Track_Type,
    at_position_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_track", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3843682357)
    }
    self := self
    type_ := type_
    at_position_ := at_position_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &at_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_remove_track :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_track", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    track_idx_ := track_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_get_track_count :: proc "contextless" (
    self: Animation,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_track_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_get_type :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
) -> (ret: Animation_Track_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_get_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3445944217)
    }
    self := self
    track_idx_ := track_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_get_path :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_get_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 408788394)
    }
    self := self
    track_idx_ := track_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_set_path :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    path_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_set_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2761262315)
    }
    self := self
    track_idx_ := track_idx_
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_find_track :: proc "contextless" (
    self: Animation,
    path_: Node_Path,
    type_: Animation_Track_Type,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_track", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 245376003)
    }
    self := self
    path_ := path_
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_move_up :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_move_up", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    track_idx_ := track_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_track_move_down :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_move_down", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    track_idx_ := track_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_track_move_to :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    to_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_move_to", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    track_idx_ := track_idx_
    to_idx_ := to_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &to_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_track_swap :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    with_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_swap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    track_idx_ := track_idx_
    with_idx_ := with_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &with_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_track_set_imported :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    imported_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_set_imported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    track_idx_ := track_idx_
    imported_ := imported_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &imported_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_track_is_imported :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_is_imported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    track_idx_ := track_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_set_enabled :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_set_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    track_idx_ := track_idx_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_track_is_enabled :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_is_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    track_idx_ := track_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_position_track_insert_key :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_: f64,
    position_: Vector3,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("position_track_insert_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2540608232)
    }
    self := self
    track_idx_ := track_idx_
    time_ := time_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_rotation_track_insert_key :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_: f64,
    rotation_: Quaternion,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotation_track_insert_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4165004800)
    }
    self := self
    track_idx_ := track_idx_
    time_ := time_
    rotation_ := rotation_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_,
        &rotation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_scale_track_insert_key :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_: f64,
    scale_: Vector3,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("scale_track_insert_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2540608232)
    }
    self := self
    track_idx_ := track_idx_
    time_ := time_
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_,
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_blend_shape_track_insert_key :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_: f64,
    amount_: f64,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("blend_shape_track_insert_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1534913637)
    }
    self := self
    track_idx_ := track_idx_
    time_ := time_
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_,
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_position_track_interpolate :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_sec_: f64,
    backward_: Bool,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("position_track_interpolate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3530011197)
    }
    self := self
    track_idx_ := track_idx_
    time_sec_ := time_sec_
    backward_ := backward_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_sec_,
        &backward_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_rotation_track_interpolate :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_sec_: f64,
    backward_: Bool,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotation_track_interpolate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915876792)
    }
    self := self
    track_idx_ := track_idx_
    time_sec_ := time_sec_
    backward_ := backward_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_sec_,
        &backward_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_scale_track_interpolate :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_sec_: f64,
    backward_: Bool,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("scale_track_interpolate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3530011197)
    }
    self := self
    track_idx_ := track_idx_
    time_sec_ := time_sec_
    backward_ := backward_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_sec_,
        &backward_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_blend_shape_track_interpolate :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_sec_: f64,
    backward_: Bool,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("blend_shape_track_interpolate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2482365182)
    }
    self := self
    track_idx_ := track_idx_
    time_sec_ := time_sec_
    backward_ := backward_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_sec_,
        &backward_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_insert_key :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_: f64,
    key_: Variant,
    transition_: f64,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_insert_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 808952278)
    }
    self := self
    track_idx_ := track_idx_
    time_ := time_
    key_ := key_
    transition_ := transition_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_,
        &key_,
        &transition_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_remove_key :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_remove_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_track_remove_key_at_time :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_remove_key_at_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    track_idx_ := track_idx_
    time_ := time_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_track_set_key_value :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_: Int,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_set_key_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2060538656)
    }
    self := self
    track_idx_ := track_idx_
    key_ := key_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_track_set_key_transition :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
    transition_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_set_key_transition", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    transition_ := transition_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
        &transition_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_track_set_key_time :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
    time_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_set_key_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    time_ := time_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
        &time_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_track_get_key_transition :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_get_key_transition", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_get_key_count :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_get_key_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    track_idx_ := track_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_get_key_value :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_get_key_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 678354945)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_get_key_time :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_get_key_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_find_key :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_: f64,
    find_mode_: Animation_Find_Mode,
    limit_: Bool,
    backward_: Bool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_find_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4230953007)
    }
    self := self
    track_idx_ := track_idx_
    time_ := time_
    find_mode_ := find_mode_
    limit_ := limit_
    backward_ := backward_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_,
        &find_mode_,
        &limit_,
        &backward_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_set_interpolation_type :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    interpolation_: Animation_Interpolation_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_set_interpolation_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4112932513)
    }
    self := self
    track_idx_ := track_idx_
    interpolation_ := interpolation_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &interpolation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_track_get_interpolation_type :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
) -> (ret: Animation_Interpolation_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_get_interpolation_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1530756894)
    }
    self := self
    track_idx_ := track_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_set_interpolation_loop_wrap :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    interpolation_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_set_interpolation_loop_wrap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    track_idx_ := track_idx_
    interpolation_ := interpolation_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &interpolation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_track_get_interpolation_loop_wrap :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_get_interpolation_loop_wrap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    track_idx_ := track_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_track_is_compressed :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("track_is_compressed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    track_idx_ := track_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_value_track_set_update_mode :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    mode_: Animation_Update_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("value_track_set_update_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2854058312)
    }
    self := self
    track_idx_ := track_idx_
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_value_track_get_update_mode :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
) -> (ret: Animation_Update_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("value_track_get_update_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1440326473)
    }
    self := self
    track_idx_ := track_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_value_track_interpolate :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_sec_: f64,
    backward_: Bool,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("value_track_interpolate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 747269075)
    }
    self := self
    track_idx_ := track_idx_
    time_sec_ := time_sec_
    backward_ := backward_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_sec_,
        &backward_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_method_track_get_name :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("method_track_get_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 351665558)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_method_track_get_params :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("method_track_get_params", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2345056839)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_bezier_track_insert_key :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_: f64,
    value_: f64,
    in_handle_: Vector2,
    out_handle_: Vector2,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bezier_track_insert_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3656773645)
    }
    self := self
    track_idx_ := track_idx_
    time_ := time_
    value_ := value_
    in_handle_ := in_handle_
    out_handle_ := out_handle_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_,
        &value_,
        &in_handle_,
        &out_handle_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_bezier_track_set_key_value :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bezier_track_set_key_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_bezier_track_set_key_in_handle :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
    in_handle_: Vector2,
    balanced_value_time_ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bezier_track_set_key_in_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1719223284)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    in_handle_ := in_handle_
    balanced_value_time_ratio_ := balanced_value_time_ratio_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
        &in_handle_,
        &balanced_value_time_ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_bezier_track_set_key_out_handle :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
    out_handle_: Vector2,
    balanced_value_time_ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bezier_track_set_key_out_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1719223284)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    out_handle_ := out_handle_
    balanced_value_time_ratio_ := balanced_value_time_ratio_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
        &out_handle_,
        &balanced_value_time_ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_bezier_track_get_key_value :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bezier_track_get_key_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_bezier_track_get_key_in_handle :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bezier_track_get_key_in_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3016396712)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_bezier_track_get_key_out_handle :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bezier_track_get_key_out_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3016396712)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_bezier_track_interpolate :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_: f64,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bezier_track_interpolate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1900462983)
    }
    self := self
    track_idx_ := track_idx_
    time_ := time_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_audio_track_insert_key :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_: f64,
    stream_: Resource,
    start_offset_: f64,
    end_offset_: f64,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("audio_track_insert_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4021027286)
    }
    self := self
    track_idx_ := track_idx_
    time_ := time_
    stream_ := stream_
    start_offset_ := start_offset_
    end_offset_ := end_offset_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_,
        &stream_,
        &start_offset_,
        &end_offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_audio_track_set_key_stream :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
    stream_: Resource,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("audio_track_set_key_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3886397084)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    stream_ := stream_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
        &stream_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_audio_track_set_key_start_offset :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
    offset_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("audio_track_set_key_start_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_audio_track_set_key_end_offset :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
    offset_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("audio_track_set_key_end_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_audio_track_get_key_stream :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
) -> (ret: Resource) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("audio_track_get_key_stream", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 635277205)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_audio_track_get_key_start_offset :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("audio_track_get_key_start_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_audio_track_get_key_end_offset :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("audio_track_get_key_end_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_audio_track_set_use_blend :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("audio_track_set_use_blend", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    track_idx_ := track_idx_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_audio_track_is_use_blend :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("audio_track_is_use_blend", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    track_idx_ := track_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_animation_track_insert_key :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    time_: f64,
    animation_: String_Name,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("animation_track_insert_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 158676774)
    }
    self := self
    track_idx_ := track_idx_
    time_ := time_
    animation_ := animation_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &time_,
        &animation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_animation_track_set_key_animation :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
    animation_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("animation_track_set_key_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 117615382)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    animation_ := animation_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
        &animation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_animation_track_get_key_animation :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    key_idx_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("animation_track_get_key_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 351665558)
    }
    self := self
    track_idx_ := track_idx_
    key_idx_ := key_idx_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &key_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_add_marker :: proc "contextless" (
    self: Animation,
    name_: String_Name,
    time_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_marker", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4135858297)
    }
    self := self
    name_ := name_
    time_ := time_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &time_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_remove_marker :: proc "contextless" (
    self: Animation,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_marker", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_has_marker :: proc "contextless" (
    self: Animation,
    name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_marker", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_get_marker_at_time :: proc "contextless" (
    self: Animation,
    time_: f64,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_marker_at_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4079494655)
    }
    self := self
    time_ := time_
    args := []__bindgen_gde.TypePtr {
        &time_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_get_next_marker :: proc "contextless" (
    self: Animation,
    time_: f64,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_next_marker", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4079494655)
    }
    self := self
    time_ := time_
    args := []__bindgen_gde.TypePtr {
        &time_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_get_prev_marker :: proc "contextless" (
    self: Animation,
    time_: f64,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_prev_marker", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4079494655)
    }
    self := self
    time_ := time_
    args := []__bindgen_gde.TypePtr {
        &time_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_get_marker_time :: proc "contextless" (
    self: Animation,
    name_: String_Name,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_marker_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2349060816)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_get_marker_names :: proc "contextless" (
    self: Animation,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_marker_names", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_get_marker_color :: proc "contextless" (
    self: Animation,
    name_: String_Name,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_marker_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3742943038)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_set_marker_color :: proc "contextless" (
    self: Animation,
    name_: String_Name,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_marker_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4260178595)
    }
    self := self
    name_ := name_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_set_length :: proc "contextless" (
    self: Animation,
    time_sec_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    time_sec_ := time_sec_
    args := []__bindgen_gde.TypePtr {
        &time_sec_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_get_length :: proc "contextless" (
    self: Animation,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_set_loop_mode :: proc "contextless" (
    self: Animation,
    loop_mode_: Animation_Loop_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_loop_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3155355575)
    }
    self := self
    loop_mode_ := loop_mode_
    args := []__bindgen_gde.TypePtr {
        &loop_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_get_loop_mode :: proc "contextless" (
    self: Animation,
) -> (ret: Animation_Loop_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_loop_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1988889481)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_set_step :: proc "contextless" (
    self: Animation,
    size_sec_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_step", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    size_sec_ := size_sec_
    args := []__bindgen_gde.TypePtr {
        &size_sec_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_get_step :: proc "contextless" (
    self: Animation,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_step", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_clear :: proc "contextless" (
    self: Animation,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_copy_track :: proc "contextless" (
    self: Animation,
    track_idx_: Int,
    to_animation_: Animation,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("copy_track", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 148001024)
    }
    self := self
    track_idx_ := track_idx_
    to_animation_ := to_animation_
    args := []__bindgen_gde.TypePtr {
        &track_idx_,
        &to_animation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_optimize :: proc "contextless" (
    self: Animation,
    allowed_velocity_err_: f64,
    allowed_angular_err_: f64,
    precision_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("optimize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3303583852)
    }
    self := self
    allowed_velocity_err_ := allowed_velocity_err_
    allowed_angular_err_ := allowed_angular_err_
    precision_ := precision_
    args := []__bindgen_gde.TypePtr {
        &allowed_velocity_err_,
        &allowed_angular_err_,
        &precision_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_compress :: proc "contextless" (
    self: Animation,
    page_size_: Int,
    fps_: Int,
    split_tolerance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compress", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3608408117)
    }
    self := self
    page_size_ := page_size_
    fps_ := fps_
    split_tolerance_ := split_tolerance_
    args := []__bindgen_gde.TypePtr {
        &page_size_,
        &fps_,
        &split_tolerance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_is_capture_included :: proc "contextless" (
    self: Animation,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_capture_included", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
animation_get_capture_included :: proc "contextless" (self: Animation) -> Bool {
    return animation_is_capture_included(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
animation_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Animation", true)
}

@(private = "file")
__class_name: String_Name