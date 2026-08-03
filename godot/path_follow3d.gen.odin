package godot

import __bindgen_gde "godot:gdext"

Path_Follow3d_Constants :: enum {
}
Path_Follow3d_Rotation_Mode :: enum int {
    Rotation_None = 0,
    Rotation_Y = 1,
    Rotation_Xy = 2,
    Rotation_Xyz = 3,
    Rotation_Oriented = 4,
}



path_follow3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

path_follow3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_path_follow3d :: proc "contextless" () -> Path_Follow3d {
    return cast(Path_Follow3d)__bindgen_gde.classdb_construct_object(path_follow3d_name_ref())
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
path_follow3d_correct_posture :: proc "contextless" (
    transform_: Transform3d,
    rotation_mode_: Path_Follow3d_Rotation_Mode,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("correct_posture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2686588690)
    }
    transform_ := transform_
    rotation_mode_ := rotation_mode_
    args := []__bindgen_gde.TypePtr {
        &transform_,
        &rotation_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}


path_follow3d_set_progress :: proc "contextless" (
    self: Path_Follow3d,
    progress_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_progress", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    progress_ := progress_
    args := []__bindgen_gde.TypePtr {
        &progress_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

path_follow3d_get_progress :: proc "contextless" (
    self: Path_Follow3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_progress", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

path_follow3d_set_h_offset :: proc "contextless" (
    self: Path_Follow3d,
    h_offset_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_h_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    h_offset_ := h_offset_
    args := []__bindgen_gde.TypePtr {
        &h_offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

path_follow3d_get_h_offset :: proc "contextless" (
    self: Path_Follow3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_h_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

path_follow3d_set_v_offset :: proc "contextless" (
    self: Path_Follow3d,
    v_offset_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_v_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    v_offset_ := v_offset_
    args := []__bindgen_gde.TypePtr {
        &v_offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

path_follow3d_get_v_offset :: proc "contextless" (
    self: Path_Follow3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_v_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

path_follow3d_set_progress_ratio :: proc "contextless" (
    self: Path_Follow3d,
    ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_progress_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    ratio_ := ratio_
    args := []__bindgen_gde.TypePtr {
        &ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

path_follow3d_get_progress_ratio :: proc "contextless" (
    self: Path_Follow3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_progress_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

path_follow3d_set_rotation_mode :: proc "contextless" (
    self: Path_Follow3d,
    rotation_mode_: Path_Follow3d_Rotation_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rotation_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1640311967)
    }
    self := self
    rotation_mode_ := rotation_mode_
    args := []__bindgen_gde.TypePtr {
        &rotation_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

path_follow3d_get_rotation_mode :: proc "contextless" (
    self: Path_Follow3d,
) -> (ret: Path_Follow3d_Rotation_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rotation_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814010545)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

path_follow3d_set_cubic_interpolation :: proc "contextless" (
    self: Path_Follow3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cubic_interpolation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

path_follow3d_get_cubic_interpolation :: proc "contextless" (
    self: Path_Follow3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cubic_interpolation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

path_follow3d_set_use_model_front :: proc "contextless" (
    self: Path_Follow3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_model_front", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

path_follow3d_is_using_model_front :: proc "contextless" (
    self: Path_Follow3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_model_front", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

path_follow3d_set_loop :: proc "contextless" (
    self: Path_Follow3d,
    loop_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_loop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    loop_ := loop_
    args := []__bindgen_gde.TypePtr {
        &loop_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

path_follow3d_has_loop :: proc "contextless" (
    self: Path_Follow3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_loop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

path_follow3d_set_tilt_enabled :: proc "contextless" (
    self: Path_Follow3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tilt_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

path_follow3d_is_tilt_enabled :: proc "contextless" (
    self: Path_Follow3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_tilt_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
path_follow3d_get_use_model_front :: proc "contextless" (self: Path_Follow3d) -> Bool {
    return path_follow3d_is_using_model_front(self)
}
path_follow3d_get_cubic_interp :: proc "contextless" (self: Path_Follow3d) -> Bool {
    return path_follow3d_get_cubic_interpolation(self)
}
path_follow3d_set_cubic_interp :: proc "contextless" (self: Path_Follow3d, value: Bool) {
    path_follow3d_set_cubic_interpolation(self, value)
}
path_follow3d_get_loop :: proc "contextless" (self: Path_Follow3d) -> Bool {
    return path_follow3d_has_loop(self)
}
path_follow3d_get_tilt_enabled :: proc "contextless" (self: Path_Follow3d) -> Bool {
    return path_follow3d_is_tilt_enabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
path_follow3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PathFollow3D", true)
}

@(private = "file")
__class_name: String_Name