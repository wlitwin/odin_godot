package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Interface_Constants :: enum {
}
Open_Xr_Interface_Session_State :: enum int {
    Session_State_Unknown = 0,
    Session_State_Idle = 1,
    Session_State_Ready = 2,
    Session_State_Synchronized = 3,
    Session_State_Visible = 4,
    Session_State_Focused = 5,
    Session_State_Stopping = 6,
    Session_State_Loss_Pending = 7,
    Session_State_Exiting = 8,
}
Open_Xr_Interface_Hand :: enum int {
    Hand_Left = 0,
    Hand_Right = 1,
    Hand_Max = 2,
}
Open_Xr_Interface_Hand_Motion_Range :: enum int {
    Hand_Motion_Range_Unobstructed = 0,
    Hand_Motion_Range_Conform_To_Controller = 1,
    Hand_Motion_Range_Max = 2,
}
Open_Xr_Interface_Hand_Tracked_Source :: enum int {
    Hand_Tracked_Source_Unknown = 0,
    Hand_Tracked_Source_Unobstructed = 1,
    Hand_Tracked_Source_Controller = 2,
    Hand_Tracked_Source_Max = 3,
}
Open_Xr_Interface_Hand_Joints :: enum int {
    Hand_Joint_Palm = 0,
    Hand_Joint_Wrist = 1,
    Hand_Joint_Thumb_Metacarpal = 2,
    Hand_Joint_Thumb_Proximal = 3,
    Hand_Joint_Thumb_Distal = 4,
    Hand_Joint_Thumb_Tip = 5,
    Hand_Joint_Index_Metacarpal = 6,
    Hand_Joint_Index_Proximal = 7,
    Hand_Joint_Index_Intermediate = 8,
    Hand_Joint_Index_Distal = 9,
    Hand_Joint_Index_Tip = 10,
    Hand_Joint_Middle_Metacarpal = 11,
    Hand_Joint_Middle_Proximal = 12,
    Hand_Joint_Middle_Intermediate = 13,
    Hand_Joint_Middle_Distal = 14,
    Hand_Joint_Middle_Tip = 15,
    Hand_Joint_Ring_Metacarpal = 16,
    Hand_Joint_Ring_Proximal = 17,
    Hand_Joint_Ring_Intermediate = 18,
    Hand_Joint_Ring_Distal = 19,
    Hand_Joint_Ring_Tip = 20,
    Hand_Joint_Little_Metacarpal = 21,
    Hand_Joint_Little_Proximal = 22,
    Hand_Joint_Little_Intermediate = 23,
    Hand_Joint_Little_Distal = 24,
    Hand_Joint_Little_Tip = 25,
    Hand_Joint_Max = 26,
}
Open_Xr_Interface_Perf_Settings_Level :: enum int {
    Perf_Settings_Level_Power_Savings = 0,
    Perf_Settings_Level_Sustained_Low = 1,
    Perf_Settings_Level_Sustained_High = 2,
    Perf_Settings_Level_Boost = 3,
}
Open_Xr_Interface_Perf_Settings_Sub_Domain :: enum int {
    Perf_Settings_Sub_Domain_Compositing = 0,
    Perf_Settings_Sub_Domain_Rendering = 1,
    Perf_Settings_Sub_Domain_Thermal = 2,
}
Open_Xr_Interface_Perf_Settings_Notification_Level :: enum int {
    Perf_Settings_Notif_Level_Normal = 0,
    Perf_Settings_Notif_Level_Warning = 1,
    Perf_Settings_Notif_Level_Impaired = 2,
}

Open_Xr_Interface_Hand_Joint_Flags :: enum i64 {
    Hand_Joint_None = 0,
    Hand_Joint_Orientation_Valid = 1,
    Hand_Joint_Orientation_Tracked = 2,
    Hand_Joint_Position_Valid = 4,
    Hand_Joint_Position_Tracked = 8,
    Hand_Joint_Linear_Velocity_Valid = 16,
    Hand_Joint_Angular_Velocity_Valid = 32,
}


open_xr_interface_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_interface_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_interface :: proc "contextless" () -> Open_Xr_Interface {
    return cast(Open_Xr_Interface)__bindgen_gde.classdb_construct_object(open_xr_interface_name_ref())
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

open_xr_interface_get_session_state :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: Open_Xr_Interface_Session_State) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_session_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 896364779)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_is_user_presence_supported :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_user_presence_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_is_user_present :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_user_present", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_get_display_refresh_rate :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_display_refresh_rate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_set_display_refresh_rate :: proc "contextless" (
    self: Open_Xr_Interface,
    refresh_rate_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_display_refresh_rate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    refresh_rate_ := refresh_rate_
    args := []__bindgen_gde.TypePtr {
        &refresh_rate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interface_get_render_target_size_multiplier :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_render_target_size_multiplier", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_set_render_target_size_multiplier :: proc "contextless" (
    self: Open_Xr_Interface,
    multiplier_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_render_target_size_multiplier", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    multiplier_ := multiplier_
    args := []__bindgen_gde.TypePtr {
        &multiplier_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interface_is_foveation_supported :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_foveation_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_get_foveation_level :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_foveation_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_set_foveation_level :: proc "contextless" (
    self: Open_Xr_Interface,
    foveation_level_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_foveation_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    foveation_level_ := foveation_level_
    args := []__bindgen_gde.TypePtr {
        &foveation_level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interface_get_foveation_dynamic :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_foveation_dynamic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_set_foveation_dynamic :: proc "contextless" (
    self: Open_Xr_Interface,
    foveation_dynamic_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_foveation_dynamic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    foveation_dynamic_ := foveation_dynamic_
    args := []__bindgen_gde.TypePtr {
        &foveation_dynamic_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interface_get_foveation_with_subsampled_images :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_foveation_with_subsampled_images", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_set_foveation_with_subsampled_images :: proc "contextless" (
    self: Open_Xr_Interface,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_foveation_with_subsampled_images", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interface_is_action_set_active :: proc "contextless" (
    self: Open_Xr_Interface,
    name_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_action_set_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_set_action_set_active :: proc "contextless" (
    self: Open_Xr_Interface,
    name_: String,
    active_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_action_set_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2678287736)
    }
    self := self
    name_ := name_
    active_ := active_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &active_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interface_get_action_sets :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_action_sets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_get_available_display_refresh_rates :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_available_display_refresh_rates", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_set_motion_range :: proc "contextless" (
    self: Open_Xr_Interface,
    hand_: Open_Xr_Interface_Hand,
    motion_range_: Open_Xr_Interface_Hand_Motion_Range,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_motion_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 855158159)
    }
    self := self
    hand_ := hand_
    motion_range_ := motion_range_
    args := []__bindgen_gde.TypePtr {
        &hand_,
        &motion_range_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interface_get_motion_range :: proc "contextless" (
    self: Open_Xr_Interface,
    hand_: Open_Xr_Interface_Hand,
) -> (ret: Open_Xr_Interface_Hand_Motion_Range) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_motion_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3955838114)
    }
    self := self
    hand_ := hand_
    args := []__bindgen_gde.TypePtr {
        &hand_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_get_hand_tracking_source :: proc "contextless" (
    self: Open_Xr_Interface,
    hand_: Open_Xr_Interface_Hand,
) -> (ret: Open_Xr_Interface_Hand_Tracked_Source) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_tracking_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4092421202)
    }
    self := self
    hand_ := hand_
    args := []__bindgen_gde.TypePtr {
        &hand_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_get_hand_joint_flags :: proc "contextless" (
    self: Open_Xr_Interface,
    hand_: Open_Xr_Interface_Hand,
    joint_: Open_Xr_Interface_Hand_Joints,
) -> (ret: Open_Xr_Interface_Hand_Joint_Flags) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_joint_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 720567706)
    }
    self := self
    hand_ := hand_
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &hand_,
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_get_hand_joint_rotation :: proc "contextless" (
    self: Open_Xr_Interface,
    hand_: Open_Xr_Interface_Hand,
    joint_: Open_Xr_Interface_Hand_Joints,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_joint_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1974618321)
    }
    self := self
    hand_ := hand_
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &hand_,
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_get_hand_joint_position :: proc "contextless" (
    self: Open_Xr_Interface,
    hand_: Open_Xr_Interface_Hand,
    joint_: Open_Xr_Interface_Hand_Joints,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_joint_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3529194242)
    }
    self := self
    hand_ := hand_
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &hand_,
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_get_hand_joint_radius :: proc "contextless" (
    self: Open_Xr_Interface,
    hand_: Open_Xr_Interface_Hand,
    joint_: Open_Xr_Interface_Hand_Joints,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_joint_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 901522724)
    }
    self := self
    hand_ := hand_
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &hand_,
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_get_hand_joint_linear_velocity :: proc "contextless" (
    self: Open_Xr_Interface,
    hand_: Open_Xr_Interface_Hand,
    joint_: Open_Xr_Interface_Hand_Joints,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_joint_linear_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3529194242)
    }
    self := self
    hand_ := hand_
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &hand_,
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_get_hand_joint_angular_velocity :: proc "contextless" (
    self: Open_Xr_Interface,
    hand_: Open_Xr_Interface_Hand,
    joint_: Open_Xr_Interface_Hand_Joints,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_joint_angular_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3529194242)
    }
    self := self
    hand_ := hand_
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &hand_,
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_is_hand_tracking_supported :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_hand_tracking_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_is_hand_interaction_supported :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_hand_interaction_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_is_eye_gaze_interaction_supported :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_eye_gaze_interaction_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_get_vrs_min_radius :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vrs_min_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_set_vrs_min_radius :: proc "contextless" (
    self: Open_Xr_Interface,
    radius_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vrs_min_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    radius_ := radius_
    args := []__bindgen_gde.TypePtr {
        &radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interface_get_vrs_strength :: proc "contextless" (
    self: Open_Xr_Interface,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vrs_strength", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_interface_set_vrs_strength :: proc "contextless" (
    self: Open_Xr_Interface,
    strength_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vrs_strength", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    strength_ := strength_
    args := []__bindgen_gde.TypePtr {
        &strength_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interface_set_cpu_level :: proc "contextless" (
    self: Open_Xr_Interface,
    level_: Open_Xr_Interface_Perf_Settings_Level,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cpu_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2940842095)
    }
    self := self
    level_ := level_
    args := []__bindgen_gde.TypePtr {
        &level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_interface_set_gpu_level :: proc "contextless" (
    self: Open_Xr_Interface,
    level_: Open_Xr_Interface_Perf_Settings_Level,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gpu_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2940842095)
    }
    self := self
    level_ := level_
    args := []__bindgen_gde.TypePtr {
        &level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
open_xr_interface_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRInterface", true)
}

@(private = "file")
__class_name: String_Name