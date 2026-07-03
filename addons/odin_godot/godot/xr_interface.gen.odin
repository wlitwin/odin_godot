package godot

import __bindgen_gde "godot:gdext"

Xr_Interface_Constants :: enum {
}
Xr_Interface_Capabilities :: enum int {
    Xr_None = 0,
    Xr_Mono = 1,
    Xr_Stereo = 2,
    Xr_Quad = 4,
    Xr_Vr = 8,
    Xr_Ar = 16,
    Xr_External = 32,
}
Xr_Interface_Tracking_Status :: enum int {
    Xr_Normal_Tracking = 0,
    Xr_Excessive_Motion = 1,
    Xr_Insufficient_Features = 2,
    Xr_Unknown_Tracking = 3,
    Xr_Not_Tracking = 4,
}
Xr_Interface_Play_Area_Mode :: enum int {
    Xr_Play_Area_Unknown = 0,
    Xr_Play_Area_3dof = 1,
    Xr_Play_Area_Sitting = 2,
    Xr_Play_Area_Roomscale = 3,
    Xr_Play_Area_Stage = 4,
    Xr_Play_Area_Custom = 2147483647,
}
Xr_Interface_Environment_Blend_Mode :: enum int {
    Xr_Env_Blend_Mode_Opaque = 0,
    Xr_Env_Blend_Mode_Additive = 1,
    Xr_Env_Blend_Mode_Alpha_Blend = 2,
}
Xr_Interface_Vrs_Texture_Format :: enum int {
    Xr_Vrs_Texture_Format_Unified = 0,
    Xr_Vrs_Texture_Format_Fragment_Shading_Rate = 1,
    Xr_Vrs_Texture_Format_Fragment_Density_Map = 2,
}



xr_interface_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

xr_interface_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_xr_interface :: proc "contextless" () -> Xr_Interface {
    return cast(Xr_Interface)__bindgen_gde.classdb_construct_object(xr_interface_name_ref())
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

xr_interface_get_name :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2002593661)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_get_capabilities :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_capabilities", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_is_primary :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_primary", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_set_primary :: proc "contextless" (
    self: Xr_Interface,
    primary_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_primary", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    primary_ := primary_
    args := []__bindgen_gde.TypePtr {
        &primary_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_interface_is_initialized :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_initialized", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_initialize :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("initialize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_uninitialize :: proc "contextless" (
    self: Xr_Interface,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("uninitialize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_interface_get_system_info :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_system_info", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2382534195)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_get_tracking_status :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Xr_Interface_Tracking_Status) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tracking_status", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 167423259)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_get_render_target_size :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_render_target_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1497962370)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_get_view_count :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_view_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_trigger_haptic_pulse :: proc "contextless" (
    self: Xr_Interface,
    action_name_: String,
    tracker_name_: String_Name,
    frequency_: f64,
    amplitude_: f64,
    duration_sec_: f64,
    delay_sec_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("trigger_haptic_pulse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3752640163)
    }
    self := self
    action_name_ := action_name_
    tracker_name_ := tracker_name_
    frequency_ := frequency_
    amplitude_ := amplitude_
    duration_sec_ := duration_sec_
    delay_sec_ := delay_sec_
    args := []__bindgen_gde.TypePtr {
        &action_name_,
        &tracker_name_,
        &frequency_,
        &amplitude_,
        &duration_sec_,
        &delay_sec_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_interface_supports_play_area_mode :: proc "contextless" (
    self: Xr_Interface,
    mode_: Xr_Interface_Play_Area_Mode,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("supports_play_area_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3429955281)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_get_play_area_mode :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Xr_Interface_Play_Area_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_play_area_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1615132885)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_set_play_area_mode :: proc "contextless" (
    self: Xr_Interface,
    mode_: Xr_Interface_Play_Area_Mode,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_play_area_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3429955281)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_get_play_area :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_play_area", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 497664490)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_get_anchor_detection_is_enabled :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_anchor_detection_is_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_set_anchor_detection_is_enabled :: proc "contextless" (
    self: Xr_Interface,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_anchor_detection_is_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_interface_get_camera_feed_id :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_camera_feed_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_is_passthrough_supported :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_passthrough_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_is_passthrough_enabled :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_passthrough_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_start_passthrough :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("start_passthrough", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_stop_passthrough :: proc "contextless" (
    self: Xr_Interface,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("stop_passthrough", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_interface_get_transform_for_view :: proc "contextless" (
    self: Xr_Interface,
    view_: Int,
    cam_transform_: Transform3d,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transform_for_view", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 518934792)
    }
    self := self
    view_ := view_
    cam_transform_ := cam_transform_
    args := []__bindgen_gde.TypePtr {
        &view_,
        &cam_transform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_get_projection_for_view :: proc "contextless" (
    self: Xr_Interface,
    view_: Int,
    aspect_: f64,
    near_: f64,
    far_: f64,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_projection_for_view", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3766090294)
    }
    self := self
    view_ := view_
    aspect_ := aspect_
    near_ := near_
    far_ := far_
    args := []__bindgen_gde.TypePtr {
        &view_,
        &aspect_,
        &near_,
        &far_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_get_supported_environment_blend_modes :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_supported_environment_blend_modes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_set_environment_blend_mode :: proc "contextless" (
    self: Xr_Interface,
    mode_: Xr_Interface_Environment_Blend_Mode,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_environment_blend_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 551152418)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_get_environment_blend_mode :: proc "contextless" (
    self: Xr_Interface,
) -> (ret: Xr_Interface_Environment_Blend_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_environment_blend_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1984334071)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
xr_interface_get_interface_is_primary :: proc "contextless" (self: Xr_Interface) -> Bool {
    return xr_interface_is_primary(self)
}
xr_interface_set_interface_is_primary :: proc "contextless" (self: Xr_Interface, value: Bool) {
    xr_interface_set_primary(self, value)
}
xr_interface_get_xr_play_area_mode :: proc "contextless" (self: Xr_Interface) -> Xr_Interface_Play_Area_Mode {
    return xr_interface_get_play_area_mode(self)
}
xr_interface_set_xr_play_area_mode :: proc "contextless" (self: Xr_Interface, value: Xr_Interface_Play_Area_Mode) {
    xr_interface_set_play_area_mode(self, value)
}
xr_interface_get_ar_is_anchor_detection_enabled :: proc "contextless" (self: Xr_Interface) -> Bool {
    return xr_interface_get_anchor_detection_is_enabled(self)
}
xr_interface_set_ar_is_anchor_detection_enabled :: proc "contextless" (self: Xr_Interface, value: Bool) {
    xr_interface_set_anchor_detection_is_enabled(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
xr_interface_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("XRInterface", true)
}

@(private = "file")
__class_name: String_Name