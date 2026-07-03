package godot

import __bindgen_gde "godot:gdext"

Xr_Hand_Tracker_Constants :: enum {
}
Xr_Hand_Tracker_Hand_Tracking_Source :: enum int {
    Hand_Tracking_Source_Unknown = 0,
    Hand_Tracking_Source_Unobstructed = 1,
    Hand_Tracking_Source_Controller = 2,
    Hand_Tracking_Source_Not_Tracked = 3,
    Hand_Tracking_Source_Max = 4,
}
Xr_Hand_Tracker_Hand_Joint :: enum int {
    Hand_Joint_Palm = 0,
    Hand_Joint_Wrist = 1,
    Hand_Joint_Thumb_Metacarpal = 2,
    Hand_Joint_Thumb_Phalanx_Proximal = 3,
    Hand_Joint_Thumb_Phalanx_Distal = 4,
    Hand_Joint_Thumb_Tip = 5,
    Hand_Joint_Index_Finger_Metacarpal = 6,
    Hand_Joint_Index_Finger_Phalanx_Proximal = 7,
    Hand_Joint_Index_Finger_Phalanx_Intermediate = 8,
    Hand_Joint_Index_Finger_Phalanx_Distal = 9,
    Hand_Joint_Index_Finger_Tip = 10,
    Hand_Joint_Middle_Finger_Metacarpal = 11,
    Hand_Joint_Middle_Finger_Phalanx_Proximal = 12,
    Hand_Joint_Middle_Finger_Phalanx_Intermediate = 13,
    Hand_Joint_Middle_Finger_Phalanx_Distal = 14,
    Hand_Joint_Middle_Finger_Tip = 15,
    Hand_Joint_Ring_Finger_Metacarpal = 16,
    Hand_Joint_Ring_Finger_Phalanx_Proximal = 17,
    Hand_Joint_Ring_Finger_Phalanx_Intermediate = 18,
    Hand_Joint_Ring_Finger_Phalanx_Distal = 19,
    Hand_Joint_Ring_Finger_Tip = 20,
    Hand_Joint_Pinky_Finger_Metacarpal = 21,
    Hand_Joint_Pinky_Finger_Phalanx_Proximal = 22,
    Hand_Joint_Pinky_Finger_Phalanx_Intermediate = 23,
    Hand_Joint_Pinky_Finger_Phalanx_Distal = 24,
    Hand_Joint_Pinky_Finger_Tip = 25,
    Hand_Joint_Max = 26,
}

Xr_Hand_Tracker_Hand_Joint_Flags :: enum i64 {
    Hand_Joint_Flag_Orientation_Valid = 1,
    Hand_Joint_Flag_Orientation_Tracked = 2,
    Hand_Joint_Flag_Position_Valid = 4,
    Hand_Joint_Flag_Position_Tracked = 8,
    Hand_Joint_Flag_Linear_Velocity_Valid = 16,
    Hand_Joint_Flag_Angular_Velocity_Valid = 32,
}


xr_hand_tracker_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

xr_hand_tracker_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_xr_hand_tracker :: proc "contextless" () -> Xr_Hand_Tracker {
    return cast(Xr_Hand_Tracker)__bindgen_gde.classdb_construct_object(xr_hand_tracker_name_ref())
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

xr_hand_tracker_set_has_tracking_data :: proc "contextless" (
    self: Xr_Hand_Tracker,
    has_data_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_has_tracking_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    has_data_ := has_data_
    args := []__bindgen_gde.TypePtr {
        &has_data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_hand_tracker_get_has_tracking_data :: proc "contextless" (
    self: Xr_Hand_Tracker,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_has_tracking_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_hand_tracker_set_hand_tracking_source :: proc "contextless" (
    self: Xr_Hand_Tracker,
    source_: Xr_Hand_Tracker_Hand_Tracking_Source,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hand_tracking_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2958308861)
    }
    self := self
    source_ := source_
    args := []__bindgen_gde.TypePtr {
        &source_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_hand_tracker_get_hand_tracking_source :: proc "contextless" (
    self: Xr_Hand_Tracker,
) -> (ret: Xr_Hand_Tracker_Hand_Tracking_Source) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_tracking_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2475045250)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_hand_tracker_set_hand_joint_flags :: proc "contextless" (
    self: Xr_Hand_Tracker,
    joint_: Xr_Hand_Tracker_Hand_Joint,
    flags_: Xr_Hand_Tracker_Hand_Joint_Flags,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hand_joint_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3028437365)
    }
    self := self
    joint_ := joint_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_hand_tracker_get_hand_joint_flags :: proc "contextless" (
    self: Xr_Hand_Tracker,
    joint_: Xr_Hand_Tracker_Hand_Joint,
) -> (ret: Xr_Hand_Tracker_Hand_Joint_Flags) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_joint_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1730972401)
    }
    self := self
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_hand_tracker_set_hand_joint_transform :: proc "contextless" (
    self: Xr_Hand_Tracker,
    joint_: Xr_Hand_Tracker_Hand_Joint,
    transform_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hand_joint_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2529959613)
    }
    self := self
    joint_ := joint_
    transform_ := transform_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &transform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_hand_tracker_get_hand_joint_transform :: proc "contextless" (
    self: Xr_Hand_Tracker,
    joint_: Xr_Hand_Tracker_Hand_Joint,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_joint_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1090840196)
    }
    self := self
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_hand_tracker_set_hand_joint_radius :: proc "contextless" (
    self: Xr_Hand_Tracker,
    joint_: Xr_Hand_Tracker_Hand_Joint,
    radius_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hand_joint_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2723659615)
    }
    self := self
    joint_ := joint_
    radius_ := radius_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_hand_tracker_get_hand_joint_radius :: proc "contextless" (
    self: Xr_Hand_Tracker,
    joint_: Xr_Hand_Tracker_Hand_Joint,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_joint_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3400025734)
    }
    self := self
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_hand_tracker_set_hand_joint_linear_velocity :: proc "contextless" (
    self: Xr_Hand_Tracker,
    joint_: Xr_Hand_Tracker_Hand_Joint,
    linear_velocity_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hand_joint_linear_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1978646737)
    }
    self := self
    joint_ := joint_
    linear_velocity_ := linear_velocity_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &linear_velocity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_hand_tracker_get_hand_joint_linear_velocity :: proc "contextless" (
    self: Xr_Hand_Tracker,
    joint_: Xr_Hand_Tracker_Hand_Joint,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_joint_linear_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 547240792)
    }
    self := self
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_hand_tracker_set_hand_joint_angular_velocity :: proc "contextless" (
    self: Xr_Hand_Tracker,
    joint_: Xr_Hand_Tracker_Hand_Joint,
    angular_velocity_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hand_joint_angular_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1978646737)
    }
    self := self
    joint_ := joint_
    angular_velocity_ := angular_velocity_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &angular_velocity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_hand_tracker_get_hand_joint_angular_velocity :: proc "contextless" (
    self: Xr_Hand_Tracker,
    joint_: Xr_Hand_Tracker_Hand_Joint,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_hand_joint_angular_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 547240792)
    }
    self := self
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
xr_hand_tracker_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("XRHandTracker", true)
}

@(private = "file")
__class_name: String_Name