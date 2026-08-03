package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Extension_Wrapper_Constants :: enum {
}



open_xr_extension_wrapper_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_extension_wrapper_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_extension_wrapper :: proc "contextless" () -> Open_Xr_Extension_Wrapper {
    return cast(Open_Xr_Extension_Wrapper)__bindgen_gde.classdb_construct_object(open_xr_extension_wrapper_name_ref())
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

open_xr_extension_wrapper__get_requested_extensions :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    xr_version_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_requested_extensions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3554694381)
    }
    self := self
    xr_version_ := xr_version_
    args := []__bindgen_gde.TypePtr {
        &xr_version_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__set_system_properties_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_system_properties_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__set_instance_create_info_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    xr_version_: Int,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_instance_create_info_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 50157827)
    }
    self := self
    xr_version_ := xr_version_
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &xr_version_,
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__set_session_create_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_session_create_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__set_swapchain_create_info_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_swapchain_create_info_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__set_hand_joint_locations_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    hand_index_: Int,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_hand_joint_locations_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 50157827)
    }
    self := self
    hand_index_ := hand_index_
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &hand_index_,
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__set_projection_views_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    view_index_: Int,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_projection_views_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 50157827)
    }
    self := self
    view_index_ := view_index_
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &view_index_,
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__set_frame_wait_info_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_frame_wait_info_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__set_frame_end_info_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_frame_end_info_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__set_projection_layer_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_projection_layer_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__set_view_locate_info_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_view_locate_info_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__set_reference_space_create_info_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    reference_space_type_: Int,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_reference_space_create_info_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 50157827)
    }
    self := self
    reference_space_type_ := reference_space_type_
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &reference_space_type_,
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__prepare_view_configuration :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    view_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_prepare_view_configuration", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    view_count_ := view_count_
    args := []__bindgen_gde.TypePtr {
        &view_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__set_view_configuration_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    view_: Int,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_view_configuration_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 50157827)
    }
    self := self
    view_ := view_
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &view_,
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__print_view_configuration_info :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    view_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_print_view_configuration_info", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 998575451)
    }
    self := self
    view_ := view_
    args := []__bindgen_gde.TypePtr {
        &view_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__get_composition_layer_count :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_composition_layer_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__get_composition_layer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    index_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_composition_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__get_composition_layer_order :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_composition_layer_order", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__get_suggested_tracker_names :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_suggested_tracker_names", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2981934095)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__on_register_metadata :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    interaction_profile_metadata_: Open_Xr_Interaction_Profile_Metadata,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_register_metadata", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 309044627)
    }
    self := self
    interaction_profile_metadata_ := interaction_profile_metadata_
    args := []__bindgen_gde.TypePtr {
        &interaction_profile_metadata_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_before_instance_created :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_before_instance_created", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_instance_created :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    instance_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_instance_created", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    instance_ := instance_
    args := []__bindgen_gde.TypePtr {
        &instance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_instance_destroyed :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_instance_destroyed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_session_created :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    session_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_session_created", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    session_ := session_
    args := []__bindgen_gde.TypePtr {
        &session_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_process :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_process", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_sync_actions :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_sync_actions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_pre_render :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_pre_render", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_main_swapchains_created :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_main_swapchains_created", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_pre_draw_viewport :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    viewport_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_pre_draw_viewport", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    viewport_ := viewport_
    args := []__bindgen_gde.TypePtr {
        &viewport_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_post_draw_viewport :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    viewport_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_post_draw_viewport", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    viewport_ := viewport_
    args := []__bindgen_gde.TypePtr {
        &viewport_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_session_destroyed :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_session_destroyed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_state_idle :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_state_idle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_state_ready :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_state_ready", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_state_synchronized :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_state_synchronized", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_state_visible :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_state_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_state_focused :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_state_focused", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_state_stopping :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_state_stopping", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_state_loss_pending :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_state_loss_pending", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_state_exiting :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_state_exiting", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__on_event_polled :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    event_: rawptr,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_event_polled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3067735520)
    }
    self := self
    event_ := event_
    args := []__bindgen_gde.TypePtr {
        &event_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__set_viewport_composition_layer_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    layer_: rawptr,
    property_values_: Dictionary,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_viewport_composition_layer_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2250464348)
    }
    self := self
    layer_ := layer_
    property_values_ := property_values_
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &property_values_,
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__get_viewport_composition_layer_extension_properties :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_viewport_composition_layer_extension_properties", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__get_viewport_composition_layer_extension_property_defaults :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_viewport_composition_layer_extension_property_defaults", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2382534195)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper__on_viewport_composition_layer_destroyed :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    layer_: rawptr,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_on_viewport_composition_layer_destroyed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_extension_wrapper__set_android_surface_swapchain_create_info_and_get_next_pointer :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
    property_values_: Dictionary,
    next_pointer_: rawptr,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_android_surface_swapchain_create_info_and_get_next_pointer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3726637545)
    }
    self := self
    property_values_ := property_values_
    next_pointer_ := next_pointer_
    args := []__bindgen_gde.TypePtr {
        &property_values_,
        &next_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper_get_openxr_api :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) -> (ret: Open_Xrapi_Extension) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_openxr_api", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1637791613)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_extension_wrapper_register_extension_wrapper :: proc "contextless" (
    self: Open_Xr_Extension_Wrapper,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_extension_wrapper", true)
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
open_xr_extension_wrapper_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRExtensionWrapper", true)
}

@(private = "file")
__class_name: String_Name