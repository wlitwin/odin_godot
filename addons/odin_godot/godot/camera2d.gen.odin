package godot

import __bindgen_gde "godot:gdext"

Camera2d_Constants :: enum {
}
Camera2d_Anchor_Mode :: enum int {
    Anchor_Mode_Fixed_Top_Left = 0,
    Anchor_Mode_Drag_Center = 1,
}
Camera2d_Camera2d_Process_Callback :: enum int {
    Camera2d_Process_Physics = 0,
    Camera2d_Process_Idle = 1,
}



camera2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

camera2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_camera2d :: proc "contextless" () -> Camera2d {
    return __bindgen_gde.classdb_construct_object(camera2d_name_ref())
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

camera2d_set_offset :: proc "contextless" (
    self: Camera2d,
    offset_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_get_offset :: proc "contextless" (
    self: Camera2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_anchor_mode :: proc "contextless" (
    self: Camera2d,
    anchor_mode_: Camera2d_Anchor_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_anchor_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2050398218)
    }
    self := self
    anchor_mode_ := anchor_mode_
    args := []__bindgen_gde.TypePtr {
        &anchor_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_get_anchor_mode :: proc "contextless" (
    self: Camera2d,
) -> (ret: Camera2d_Anchor_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_anchor_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 155978067)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_ignore_rotation :: proc "contextless" (
    self: Camera2d,
    ignore_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_ignore_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    ignore_ := ignore_
    args := []__bindgen_gde.TypePtr {
        &ignore_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_is_ignoring_rotation :: proc "contextless" (
    self: Camera2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_ignoring_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_process_callback :: proc "contextless" (
    self: Camera2d,
    mode_: Camera2d_Camera2d_Process_Callback,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_process_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4201947462)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_get_process_callback :: proc "contextless" (
    self: Camera2d,
) -> (ret: Camera2d_Camera2d_Process_Callback) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_process_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2325344499)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_enabled :: proc "contextless" (
    self: Camera2d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_is_enabled :: proc "contextless" (
    self: Camera2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_make_current :: proc "contextless" (
    self: Camera2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_current", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_is_current :: proc "contextless" (
    self: Camera2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_current", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_limit_enabled :: proc "contextless" (
    self: Camera2d,
    limit_enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_limit_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    limit_enabled_ := limit_enabled_
    args := []__bindgen_gde.TypePtr {
        &limit_enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_is_limit_enabled :: proc "contextless" (
    self: Camera2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_limit_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_limit :: proc "contextless" (
    self: Camera2d,
    margin_: Side,
    limit_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_limit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 437707142)
    }
    self := self
    margin_ := margin_
    limit_ := limit_
    args := []__bindgen_gde.TypePtr {
        &margin_,
        &limit_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_get_limit :: proc "contextless" (
    self: Camera2d,
    margin_: Side,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_limit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1983885014)
    }
    self := self
    margin_ := margin_
    args := []__bindgen_gde.TypePtr {
        &margin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_limit_smoothing_enabled :: proc "contextless" (
    self: Camera2d,
    limit_smoothing_enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_limit_smoothing_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    limit_smoothing_enabled_ := limit_smoothing_enabled_
    args := []__bindgen_gde.TypePtr {
        &limit_smoothing_enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_is_limit_smoothing_enabled :: proc "contextless" (
    self: Camera2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_limit_smoothing_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_drag_vertical_enabled :: proc "contextless" (
    self: Camera2d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_drag_vertical_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_is_drag_vertical_enabled :: proc "contextless" (
    self: Camera2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_drag_vertical_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_drag_horizontal_enabled :: proc "contextless" (
    self: Camera2d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_drag_horizontal_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_is_drag_horizontal_enabled :: proc "contextless" (
    self: Camera2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_drag_horizontal_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_drag_vertical_offset :: proc "contextless" (
    self: Camera2d,
    offset_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_drag_vertical_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_get_drag_vertical_offset :: proc "contextless" (
    self: Camera2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_drag_vertical_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_drag_horizontal_offset :: proc "contextless" (
    self: Camera2d,
    offset_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_drag_horizontal_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_get_drag_horizontal_offset :: proc "contextless" (
    self: Camera2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_drag_horizontal_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_drag_margin :: proc "contextless" (
    self: Camera2d,
    margin_: Side,
    drag_margin_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_drag_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4290182280)
    }
    self := self
    margin_ := margin_
    drag_margin_ := drag_margin_
    args := []__bindgen_gde.TypePtr {
        &margin_,
        &drag_margin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_get_drag_margin :: proc "contextless" (
    self: Camera2d,
    margin_: Side,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_drag_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2869120046)
    }
    self := self
    margin_ := margin_
    args := []__bindgen_gde.TypePtr {
        &margin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_get_target_position :: proc "contextless" (
    self: Camera2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_target_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_get_screen_center_position :: proc "contextless" (
    self: Camera2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_screen_center_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_get_screen_rotation :: proc "contextless" (
    self: Camera2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_screen_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_zoom :: proc "contextless" (
    self: Camera2d,
    zoom_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_zoom", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    zoom_ := zoom_
    args := []__bindgen_gde.TypePtr {
        &zoom_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_get_zoom :: proc "contextless" (
    self: Camera2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_zoom", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_custom_viewport :: proc "contextless" (
    self: Camera2d,
    viewport_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_viewport", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    viewport_ := viewport_
    args := []__bindgen_gde.TypePtr {
        &viewport_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_get_custom_viewport :: proc "contextless" (
    self: Camera2d,
) -> (ret: Node) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_viewport", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3160264692)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_position_smoothing_speed :: proc "contextless" (
    self: Camera2d,
    position_smoothing_speed_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_position_smoothing_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    position_smoothing_speed_ := position_smoothing_speed_
    args := []__bindgen_gde.TypePtr {
        &position_smoothing_speed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_get_position_smoothing_speed :: proc "contextless" (
    self: Camera2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_position_smoothing_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_position_smoothing_enabled :: proc "contextless" (
    self: Camera2d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_position_smoothing_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_is_position_smoothing_enabled :: proc "contextless" (
    self: Camera2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_position_smoothing_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_rotation_smoothing_enabled :: proc "contextless" (
    self: Camera2d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rotation_smoothing_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_is_rotation_smoothing_enabled :: proc "contextless" (
    self: Camera2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_rotation_smoothing_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_rotation_smoothing_speed :: proc "contextless" (
    self: Camera2d,
    speed_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rotation_smoothing_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    speed_ := speed_
    args := []__bindgen_gde.TypePtr {
        &speed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_get_rotation_smoothing_speed :: proc "contextless" (
    self: Camera2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rotation_smoothing_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_force_update_scroll :: proc "contextless" (
    self: Camera2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("force_update_scroll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_reset_smoothing :: proc "contextless" (
    self: Camera2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reset_smoothing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_align :: proc "contextless" (
    self: Camera2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("align", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_set_screen_drawing_enabled :: proc "contextless" (
    self: Camera2d,
    screen_drawing_enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_screen_drawing_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    screen_drawing_enabled_ := screen_drawing_enabled_
    args := []__bindgen_gde.TypePtr {
        &screen_drawing_enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_is_screen_drawing_enabled :: proc "contextless" (
    self: Camera2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_screen_drawing_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_limit_drawing_enabled :: proc "contextless" (
    self: Camera2d,
    limit_drawing_enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_limit_drawing_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    limit_drawing_enabled_ := limit_drawing_enabled_
    args := []__bindgen_gde.TypePtr {
        &limit_drawing_enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_is_limit_drawing_enabled :: proc "contextless" (
    self: Camera2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_limit_drawing_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera2d_set_margin_drawing_enabled :: proc "contextless" (
    self: Camera2d,
    margin_drawing_enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_margin_drawing_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    margin_drawing_enabled_ := margin_drawing_enabled_
    args := []__bindgen_gde.TypePtr {
        &margin_drawing_enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera2d_is_margin_drawing_enabled :: proc "contextless" (
    self: Camera2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_margin_drawing_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
camera2d_get_ignore_rotation :: proc "contextless" (self: Camera2d) -> Bool {
    return camera2d_is_ignoring_rotation(self)
}
camera2d_get_enabled :: proc "contextless" (self: Camera2d) -> Bool {
    return camera2d_is_enabled(self)
}
camera2d_get_limit_enabled :: proc "contextless" (self: Camera2d) -> Bool {
    return camera2d_is_limit_enabled(self)
}
camera2d_get_limit_left :: proc "contextless" (self: Camera2d) -> i32 {
    return camera2d_get_limit(self, Side(0))
}
camera2d_set_limit_left :: proc "contextless" (self: Camera2d, value: Int) {
    camera2d_set_limit(self, Side(0), value)
}
camera2d_get_limit_top :: proc "contextless" (self: Camera2d) -> i32 {
    return camera2d_get_limit(self, Side(1))
}
camera2d_set_limit_top :: proc "contextless" (self: Camera2d, value: Int) {
    camera2d_set_limit(self, Side(1), value)
}
camera2d_get_limit_right :: proc "contextless" (self: Camera2d) -> i32 {
    return camera2d_get_limit(self, Side(2))
}
camera2d_set_limit_right :: proc "contextless" (self: Camera2d, value: Int) {
    camera2d_set_limit(self, Side(2), value)
}
camera2d_get_limit_bottom :: proc "contextless" (self: Camera2d) -> i32 {
    return camera2d_get_limit(self, Side(3))
}
camera2d_set_limit_bottom :: proc "contextless" (self: Camera2d, value: Int) {
    camera2d_set_limit(self, Side(3), value)
}
camera2d_get_limit_smoothed :: proc "contextless" (self: Camera2d) -> Bool {
    return camera2d_is_limit_smoothing_enabled(self)
}
camera2d_set_limit_smoothed :: proc "contextless" (self: Camera2d, value: Bool) {
    camera2d_set_limit_smoothing_enabled(self, value)
}
camera2d_get_position_smoothing_enabled :: proc "contextless" (self: Camera2d) -> Bool {
    return camera2d_is_position_smoothing_enabled(self)
}
camera2d_get_rotation_smoothing_enabled :: proc "contextless" (self: Camera2d) -> Bool {
    return camera2d_is_rotation_smoothing_enabled(self)
}
camera2d_get_drag_horizontal_enabled :: proc "contextless" (self: Camera2d) -> Bool {
    return camera2d_is_drag_horizontal_enabled(self)
}
camera2d_get_drag_vertical_enabled :: proc "contextless" (self: Camera2d) -> Bool {
    return camera2d_is_drag_vertical_enabled(self)
}
camera2d_get_drag_left_margin :: proc "contextless" (self: Camera2d) -> f64 {
    return camera2d_get_drag_margin(self, Side(0))
}
camera2d_set_drag_left_margin :: proc "contextless" (self: Camera2d, value: f64) {
    camera2d_set_drag_margin(self, Side(0), value)
}
camera2d_get_drag_top_margin :: proc "contextless" (self: Camera2d) -> f64 {
    return camera2d_get_drag_margin(self, Side(1))
}
camera2d_set_drag_top_margin :: proc "contextless" (self: Camera2d, value: f64) {
    camera2d_set_drag_margin(self, Side(1), value)
}
camera2d_get_drag_right_margin :: proc "contextless" (self: Camera2d) -> f64 {
    return camera2d_get_drag_margin(self, Side(2))
}
camera2d_set_drag_right_margin :: proc "contextless" (self: Camera2d, value: f64) {
    camera2d_set_drag_margin(self, Side(2), value)
}
camera2d_get_drag_bottom_margin :: proc "contextless" (self: Camera2d) -> f64 {
    return camera2d_get_drag_margin(self, Side(3))
}
camera2d_set_drag_bottom_margin :: proc "contextless" (self: Camera2d, value: f64) {
    camera2d_set_drag_margin(self, Side(3), value)
}
camera2d_get_editor_draw_screen :: proc "contextless" (self: Camera2d) -> Bool {
    return camera2d_is_screen_drawing_enabled(self)
}
camera2d_set_editor_draw_screen :: proc "contextless" (self: Camera2d, value: Bool) {
    camera2d_set_screen_drawing_enabled(self, value)
}
camera2d_get_editor_draw_limits :: proc "contextless" (self: Camera2d) -> Bool {
    return camera2d_is_limit_drawing_enabled(self)
}
camera2d_set_editor_draw_limits :: proc "contextless" (self: Camera2d, value: Bool) {
    camera2d_set_limit_drawing_enabled(self, value)
}
camera2d_get_editor_draw_drag_margin :: proc "contextless" (self: Camera2d) -> Bool {
    return camera2d_is_margin_drawing_enabled(self)
}
camera2d_set_editor_draw_drag_margin :: proc "contextless" (self: Camera2d, value: Bool) {
    camera2d_set_margin_drawing_enabled(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
camera2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Camera2D", true)
}

@(private = "file")
__class_name: String_Name