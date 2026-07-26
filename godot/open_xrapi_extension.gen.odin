package godot

import __bindgen_gde "godot:gdext"

Open_Xrapi_Extension_Constants :: enum {
}
Open_Xrapi_Extension_Open_Xr_Alpha_Blend_Mode_Support :: enum int {
    Openxr_Alpha_Blend_Mode_Support_None = 0,
    Openxr_Alpha_Blend_Mode_Support_Real = 1,
    Openxr_Alpha_Blend_Mode_Support_Emulating = 2,
}



open_xrapi_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xrapi_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xrapi_extension :: proc "contextless" () -> Open_Xrapi_Extension {
    return cast(Open_Xrapi_Extension)__bindgen_gde.classdb_construct_object(open_xrapi_extension_name_ref())
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
open_xrapi_extension_openxr_is_enabled :: proc "contextless" (
    check_run_in_editor_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("openxr_is_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2703660260)
    }
    check_run_in_editor_ := check_run_in_editor_
    args := []__bindgen_gde.TypePtr {
        &check_run_in_editor_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}


open_xrapi_extension_get_openxr_version :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_openxr_version", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_get_instance :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_instance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_get_system_id :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_system_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_get_session :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_session", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_transform_from_pose :: proc "contextless" (
    self: Open_Xrapi_Extension,
    pose_: rawptr,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("transform_from_pose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2963875352)
    }
    self := self
    pose_ := pose_
    args := []__bindgen_gde.TypePtr {
        &pose_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_xr_result :: proc "contextless" (
    self: Open_Xrapi_Extension,
    result_: Int,
    format_: String,
    args_: Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("xr_result", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3886436197)
    }
    self := self
    result_ := result_
    format_ := format_
    args_ := args_
    args := []__bindgen_gde.TypePtr {
        &result_,
        &format_,
        &args_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_get_instance_proc_addr :: proc "contextless" (
    self: Open_Xrapi_Extension,
    name_: String,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_instance_proc_addr", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1597066294)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_get_error_string :: proc "contextless" (
    self: Open_Xrapi_Extension,
    result_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_error_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 990163283)
    }
    self := self
    result_ := result_
    args := []__bindgen_gde.TypePtr {
        &result_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_get_swapchain_format_name :: proc "contextless" (
    self: Open_Xrapi_Extension,
    swapchain_format_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_swapchain_format_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 990163283)
    }
    self := self
    swapchain_format_ := swapchain_format_
    args := []__bindgen_gde.TypePtr {
        &swapchain_format_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_set_object_name :: proc "contextless" (
    self: Open_Xrapi_Extension,
    object_type_: Int,
    object_handle_: Int,
    object_name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_object_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2285447957)
    }
    self := self
    object_type_ := object_type_
    object_handle_ := object_handle_
    object_name_ := object_name_
    args := []__bindgen_gde.TypePtr {
        &object_type_,
        &object_handle_,
        &object_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_begin_debug_label_region :: proc "contextless" (
    self: Open_Xrapi_Extension,
    label_name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("begin_debug_label_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    label_name_ := label_name_
    args := []__bindgen_gde.TypePtr {
        &label_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_end_debug_label_region :: proc "contextless" (
    self: Open_Xrapi_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("end_debug_label_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_insert_debug_label :: proc "contextless" (
    self: Open_Xrapi_Extension,
    label_name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("insert_debug_label", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    label_name_ := label_name_
    args := []__bindgen_gde.TypePtr {
        &label_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_get_view_count :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_view_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_get_view_configuration :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_view_configuration", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_is_initialized :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_initialized", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_is_running :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_running", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_set_custom_play_space :: proc "contextless" (
    self: Open_Xrapi_Extension,
    space_: rawptr,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_play_space", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    space_ := space_
    args := []__bindgen_gde.TypePtr {
        &space_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_get_play_space :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_play_space", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_get_predicted_display_time :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_predicted_display_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_get_next_frame_time :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_next_frame_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_can_render :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("can_render", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_find_action :: proc "contextless" (
    self: Open_Xrapi_Extension,
    name_: String,
    action_set_: Rid,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_action", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4106179378)
    }
    self := self
    name_ := name_
    action_set_ := action_set_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &action_set_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_action_get_handle :: proc "contextless" (
    self: Open_Xrapi_Extension,
    action_: Rid,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("action_get_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3917799429)
    }
    self := self
    action_ := action_
    args := []__bindgen_gde.TypePtr {
        &action_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_get_hand_tracker :: proc "contextless" (
    self: Open_Xrapi_Extension,
    hand_index_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_tracker", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    hand_index_ := hand_index_
    args := []__bindgen_gde.TypePtr {
        &hand_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_register_composition_layer_provider :: proc "contextless" (
    self: Open_Xrapi_Extension,
    extension_: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_composition_layer_provider", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1477360496)
    }
    self := self
    extension_ := extension_
    args := []__bindgen_gde.TypePtr {
        &extension_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_unregister_composition_layer_provider :: proc "contextless" (
    self: Open_Xrapi_Extension,
    extension_: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unregister_composition_layer_provider", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1477360496)
    }
    self := self
    extension_ := extension_
    args := []__bindgen_gde.TypePtr {
        &extension_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_register_projection_views_extension :: proc "contextless" (
    self: Open_Xrapi_Extension,
    extension_: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_projection_views_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1477360496)
    }
    self := self
    extension_ := extension_
    args := []__bindgen_gde.TypePtr {
        &extension_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_unregister_projection_views_extension :: proc "contextless" (
    self: Open_Xrapi_Extension,
    extension_: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unregister_projection_views_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1477360496)
    }
    self := self
    extension_ := extension_
    args := []__bindgen_gde.TypePtr {
        &extension_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_register_frame_info_extension :: proc "contextless" (
    self: Open_Xrapi_Extension,
    extension_: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_frame_info_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1477360496)
    }
    self := self
    extension_ := extension_
    args := []__bindgen_gde.TypePtr {
        &extension_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_unregister_frame_info_extension :: proc "contextless" (
    self: Open_Xrapi_Extension,
    extension_: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unregister_frame_info_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1477360496)
    }
    self := self
    extension_ := extension_
    args := []__bindgen_gde.TypePtr {
        &extension_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_register_projection_layer_extension :: proc "contextless" (
    self: Open_Xrapi_Extension,
    extension_: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_projection_layer_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1477360496)
    }
    self := self
    extension_ := extension_
    args := []__bindgen_gde.TypePtr {
        &extension_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_unregister_projection_layer_extension :: proc "contextless" (
    self: Open_Xrapi_Extension,
    extension_: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unregister_projection_layer_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1477360496)
    }
    self := self
    extension_ := extension_
    args := []__bindgen_gde.TypePtr {
        &extension_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_get_render_state_z_near :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_render_state_z_near", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_get_render_state_z_far :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_render_state_z_far", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_set_velocity_texture :: proc "contextless" (
    self: Open_Xrapi_Extension,
    render_target_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_velocity_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    render_target_ := render_target_
    args := []__bindgen_gde.TypePtr {
        &render_target_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_set_velocity_depth_texture :: proc "contextless" (
    self: Open_Xrapi_Extension,
    render_target_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_velocity_depth_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    render_target_ := render_target_
    args := []__bindgen_gde.TypePtr {
        &render_target_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_set_velocity_target_size :: proc "contextless" (
    self: Open_Xrapi_Extension,
    target_size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_velocity_target_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    target_size_ := target_size_
    args := []__bindgen_gde.TypePtr {
        &target_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_get_supported_swapchain_formats :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: Packed_Int64_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_supported_swapchain_formats", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3851388692)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_openxr_swapchain_create :: proc "contextless" (
    self: Open_Xrapi_Extension,
    create_flags_: Int,
    usage_flags_: Int,
    swapchain_format_: Int,
    width_: Int,
    height_: Int,
    sample_count_: Int,
    array_size_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("openxr_swapchain_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2162228999)
    }
    self := self
    create_flags_ := create_flags_
    usage_flags_ := usage_flags_
    swapchain_format_ := swapchain_format_
    width_ := width_
    height_ := height_
    sample_count_ := sample_count_
    array_size_ := array_size_
    args := []__bindgen_gde.TypePtr {
        &create_flags_,
        &usage_flags_,
        &swapchain_format_,
        &width_,
        &height_,
        &sample_count_,
        &array_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_openxr_swapchain_free :: proc "contextless" (
    self: Open_Xrapi_Extension,
    swapchain_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("openxr_swapchain_free", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    swapchain_ := swapchain_
    args := []__bindgen_gde.TypePtr {
        &swapchain_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_openxr_swapchain_get_swapchain :: proc "contextless" (
    self: Open_Xrapi_Extension,
    swapchain_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("openxr_swapchain_get_swapchain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    swapchain_ := swapchain_
    args := []__bindgen_gde.TypePtr {
        &swapchain_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_openxr_swapchain_acquire :: proc "contextless" (
    self: Open_Xrapi_Extension,
    swapchain_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("openxr_swapchain_acquire", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    swapchain_ := swapchain_
    args := []__bindgen_gde.TypePtr {
        &swapchain_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_openxr_swapchain_get_image :: proc "contextless" (
    self: Open_Xrapi_Extension,
    swapchain_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("openxr_swapchain_get_image", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 937000113)
    }
    self := self
    swapchain_ := swapchain_
    args := []__bindgen_gde.TypePtr {
        &swapchain_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_openxr_swapchain_release :: proc "contextless" (
    self: Open_Xrapi_Extension,
    swapchain_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("openxr_swapchain_release", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    swapchain_ := swapchain_
    args := []__bindgen_gde.TypePtr {
        &swapchain_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_get_projection_layer :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_projection_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_set_render_region :: proc "contextless" (
    self: Open_Xrapi_Extension,
    render_region_: Rect2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_render_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1763793166)
    }
    self := self
    render_region_ := render_region_
    args := []__bindgen_gde.TypePtr {
        &render_region_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_set_emulate_environment_blend_mode_alpha_blend :: proc "contextless" (
    self: Open_Xrapi_Extension,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emulate_environment_blend_mode_alpha_blend", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xrapi_extension_is_environment_blend_mode_alpha_supported :: proc "contextless" (
    self: Open_Xrapi_Extension,
) -> (ret: Open_Xrapi_Extension_Open_Xr_Alpha_Blend_Mode_Support) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_environment_blend_mode_alpha_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1579290861)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xrapi_extension_update_main_swapchain_size :: proc "contextless" (
    self: Open_Xrapi_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_main_swapchain_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
open_xrapi_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRAPIExtension", true)
}

@(private = "file")
__class_name: String_Name