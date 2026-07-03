package godot

import __bindgen_gde "godot:gdext"

Xr_Interface_Extension_Constants :: enum {
}



xr_interface_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

xr_interface_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_xr_interface_extension :: proc "contextless" () -> Xr_Interface_Extension {
    return cast(Xr_Interface_Extension)__bindgen_gde.classdb_construct_object(xr_interface_extension_name_ref())
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

xr_interface_extension__get_name :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2002593661)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_capabilities :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_capabilities", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__is_initialized :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_initialized", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__initialize :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_initialize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__uninitialize :: proc "contextless" (
    self: Xr_Interface_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_uninitialize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_interface_extension__get_system_info :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_system_info", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__supports_play_area_mode :: proc "contextless" (
    self: Xr_Interface_Extension,
    mode_: Xr_Interface_Play_Area_Mode,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_supports_play_area_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2693703033)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_play_area_mode :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Xr_Interface_Play_Area_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_play_area_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1615132885)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__set_play_area_mode :: proc "contextless" (
    self: Xr_Interface_Extension,
    mode_: Xr_Interface_Play_Area_Mode,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_play_area_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2693703033)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_play_area :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_play_area", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 497664490)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_render_target_size :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_render_target_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1497962370)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_view_count :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_view_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_camera_transform :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_camera_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4183770049)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_transform_for_view :: proc "contextless" (
    self: Xr_Interface_Extension,
    view_: Int,
    cam_transform_: Transform3d,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_transform_for_view", true)
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

xr_interface_extension__get_projection_for_view :: proc "contextless" (
    self: Xr_Interface_Extension,
    view_: Int,
    aspect_: f64,
    z_near_: f64,
    z_far_: f64,
) -> (ret: Packed_Float64_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_projection_for_view", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4067457445)
    }
    self := self
    view_ := view_
    aspect_ := aspect_
    z_near_ := z_near_
    z_far_ := z_far_
    args := []__bindgen_gde.TypePtr {
        &view_,
        &aspect_,
        &z_near_,
        &z_far_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_vrs_texture :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_vrs_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_vrs_texture_format :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Xr_Interface_Vrs_Texture_Format) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_vrs_texture_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1500923256)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__process :: proc "contextless" (
    self: Xr_Interface_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_process", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_interface_extension__pre_render :: proc "contextless" (
    self: Xr_Interface_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_pre_render", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_interface_extension__pre_draw_viewport :: proc "contextless" (
    self: Xr_Interface_Extension,
    render_target_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_pre_draw_viewport", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3521089500)
    }
    self := self
    render_target_ := render_target_
    args := []__bindgen_gde.TypePtr {
        &render_target_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__post_draw_viewport :: proc "contextless" (
    self: Xr_Interface_Extension,
    render_target_: Rid,
    screen_rect_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_post_draw_viewport", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1378122625)
    }
    self := self
    render_target_ := render_target_
    screen_rect_ := screen_rect_
    args := []__bindgen_gde.TypePtr {
        &render_target_,
        &screen_rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_interface_extension__end_frame :: proc "contextless" (
    self: Xr_Interface_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_end_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_interface_extension__get_suggested_tracker_names :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_suggested_tracker_names", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_suggested_pose_names :: proc "contextless" (
    self: Xr_Interface_Extension,
    tracker_name_: String_Name,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_suggested_pose_names", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1761182771)
    }
    self := self
    tracker_name_ := tracker_name_
    args := []__bindgen_gde.TypePtr {
        &tracker_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_tracking_status :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Xr_Interface_Tracking_Status) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_tracking_status", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 167423259)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__trigger_haptic_pulse :: proc "contextless" (
    self: Xr_Interface_Extension,
    action_name_: String,
    tracker_name_: String_Name,
    frequency_: f64,
    amplitude_: f64,
    duration_sec_: f64,
    delay_sec_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_trigger_haptic_pulse", true)
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

xr_interface_extension__get_anchor_detection_is_enabled :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_anchor_detection_is_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__set_anchor_detection_is_enabled :: proc "contextless" (
    self: Xr_Interface_Extension,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_anchor_detection_is_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_interface_extension__get_camera_feed_id :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_camera_feed_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_color_texture :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_color_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_depth_texture :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_depth_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension__get_velocity_texture :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_velocity_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension_get_color_texture :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension_get_depth_texture :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_depth_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension_get_velocity_texture :: proc "contextless" (
    self: Xr_Interface_Extension,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_velocity_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_interface_extension_add_blit :: proc "contextless" (
    self: Xr_Interface_Extension,
    render_target_: Rid,
    src_rect_: Rect2,
    dst_rect_: Rect2i,
    use_layer_: Bool,
    layer_: Int,
    apply_lens_distortion_: Bool,
    eye_center_: Vector2,
    k1_: f64,
    k2_: f64,
    upscale_: f64,
    aspect_ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_blit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 258596971)
    }
    self := self
    render_target_ := render_target_
    src_rect_ := src_rect_
    dst_rect_ := dst_rect_
    use_layer_ := use_layer_
    layer_ := layer_
    apply_lens_distortion_ := apply_lens_distortion_
    eye_center_ := eye_center_
    k1_ := k1_
    k2_ := k2_
    upscale_ := upscale_
    aspect_ratio_ := aspect_ratio_
    args := []__bindgen_gde.TypePtr {
        &render_target_,
        &src_rect_,
        &dst_rect_,
        &use_layer_,
        &layer_,
        &apply_lens_distortion_,
        &eye_center_,
        &k1_,
        &k2_,
        &upscale_,
        &aspect_ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_interface_extension_get_render_target_texture :: proc "contextless" (
    self: Xr_Interface_Extension,
    render_target_: Rid,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_render_target_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 41030802)
    }
    self := self
    render_target_ := render_target_
    args := []__bindgen_gde.TypePtr {
        &render_target_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
xr_interface_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("XRInterfaceExtension", true)
}

@(private = "file")
__class_name: String_Name