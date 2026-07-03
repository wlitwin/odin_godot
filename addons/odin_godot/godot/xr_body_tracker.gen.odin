package godot

import __bindgen_gde "godot:gdext"

Xr_Body_Tracker_Constants :: enum {
}
Xr_Body_Tracker_Joint :: enum int {
    Joint_Root = 0,
    Joint_Hips = 1,
    Joint_Spine = 2,
    Joint_Chest = 3,
    Joint_Upper_Chest = 4,
    Joint_Neck = 5,
    Joint_Head = 6,
    Joint_Head_Tip = 7,
    Joint_Left_Shoulder = 8,
    Joint_Left_Upper_Arm = 9,
    Joint_Left_Lower_Arm = 10,
    Joint_Right_Shoulder = 11,
    Joint_Right_Upper_Arm = 12,
    Joint_Right_Lower_Arm = 13,
    Joint_Left_Upper_Leg = 14,
    Joint_Left_Lower_Leg = 15,
    Joint_Left_Foot = 16,
    Joint_Left_Toes = 17,
    Joint_Right_Upper_Leg = 18,
    Joint_Right_Lower_Leg = 19,
    Joint_Right_Foot = 20,
    Joint_Right_Toes = 21,
    Joint_Left_Hand = 22,
    Joint_Left_Palm = 23,
    Joint_Left_Wrist = 24,
    Joint_Left_Thumb_Metacarpal = 25,
    Joint_Left_Thumb_Phalanx_Proximal = 26,
    Joint_Left_Thumb_Phalanx_Distal = 27,
    Joint_Left_Thumb_Tip = 28,
    Joint_Left_Index_Finger_Metacarpal = 29,
    Joint_Left_Index_Finger_Phalanx_Proximal = 30,
    Joint_Left_Index_Finger_Phalanx_Intermediate = 31,
    Joint_Left_Index_Finger_Phalanx_Distal = 32,
    Joint_Left_Index_Finger_Tip = 33,
    Joint_Left_Middle_Finger_Metacarpal = 34,
    Joint_Left_Middle_Finger_Phalanx_Proximal = 35,
    Joint_Left_Middle_Finger_Phalanx_Intermediate = 36,
    Joint_Left_Middle_Finger_Phalanx_Distal = 37,
    Joint_Left_Middle_Finger_Tip = 38,
    Joint_Left_Ring_Finger_Metacarpal = 39,
    Joint_Left_Ring_Finger_Phalanx_Proximal = 40,
    Joint_Left_Ring_Finger_Phalanx_Intermediate = 41,
    Joint_Left_Ring_Finger_Phalanx_Distal = 42,
    Joint_Left_Ring_Finger_Tip = 43,
    Joint_Left_Pinky_Finger_Metacarpal = 44,
    Joint_Left_Pinky_Finger_Phalanx_Proximal = 45,
    Joint_Left_Pinky_Finger_Phalanx_Intermediate = 46,
    Joint_Left_Pinky_Finger_Phalanx_Distal = 47,
    Joint_Left_Pinky_Finger_Tip = 48,
    Joint_Right_Hand = 49,
    Joint_Right_Palm = 50,
    Joint_Right_Wrist = 51,
    Joint_Right_Thumb_Metacarpal = 52,
    Joint_Right_Thumb_Phalanx_Proximal = 53,
    Joint_Right_Thumb_Phalanx_Distal = 54,
    Joint_Right_Thumb_Tip = 55,
    Joint_Right_Index_Finger_Metacarpal = 56,
    Joint_Right_Index_Finger_Phalanx_Proximal = 57,
    Joint_Right_Index_Finger_Phalanx_Intermediate = 58,
    Joint_Right_Index_Finger_Phalanx_Distal = 59,
    Joint_Right_Index_Finger_Tip = 60,
    Joint_Right_Middle_Finger_Metacarpal = 61,
    Joint_Right_Middle_Finger_Phalanx_Proximal = 62,
    Joint_Right_Middle_Finger_Phalanx_Intermediate = 63,
    Joint_Right_Middle_Finger_Phalanx_Distal = 64,
    Joint_Right_Middle_Finger_Tip = 65,
    Joint_Right_Ring_Finger_Metacarpal = 66,
    Joint_Right_Ring_Finger_Phalanx_Proximal = 67,
    Joint_Right_Ring_Finger_Phalanx_Intermediate = 68,
    Joint_Right_Ring_Finger_Phalanx_Distal = 69,
    Joint_Right_Ring_Finger_Tip = 70,
    Joint_Right_Pinky_Finger_Metacarpal = 71,
    Joint_Right_Pinky_Finger_Phalanx_Proximal = 72,
    Joint_Right_Pinky_Finger_Phalanx_Intermediate = 73,
    Joint_Right_Pinky_Finger_Phalanx_Distal = 74,
    Joint_Right_Pinky_Finger_Tip = 75,
    Joint_Lower_Chest = 76,
    Joint_Left_Scapula = 77,
    Joint_Left_Wrist_Twist = 78,
    Joint_Right_Scapula = 79,
    Joint_Right_Wrist_Twist = 80,
    Joint_Left_Foot_Twist = 81,
    Joint_Left_Heel = 82,
    Joint_Left_Middle_Foot = 83,
    Joint_Right_Foot_Twist = 84,
    Joint_Right_Heel = 85,
    Joint_Right_Middle_Foot = 86,
    Joint_Max = 87,
}

Xr_Body_Tracker_Body_Flags :: enum i64 {
    Body_Flag_Upper_Body_Supported = 1,
    Body_Flag_Lower_Body_Supported = 2,
    Body_Flag_Hands_Supported = 4,
}
Xr_Body_Tracker_Joint_Flags :: enum i64 {
    Joint_Flag_Orientation_Valid = 1,
    Joint_Flag_Orientation_Tracked = 2,
    Joint_Flag_Position_Valid = 4,
    Joint_Flag_Position_Tracked = 8,
}


xr_body_tracker_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

xr_body_tracker_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_xr_body_tracker :: proc "contextless" () -> Xr_Body_Tracker {
    return cast(Xr_Body_Tracker)__bindgen_gde.classdb_construct_object(xr_body_tracker_name_ref())
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

xr_body_tracker_set_has_tracking_data :: proc "contextless" (
    self: Xr_Body_Tracker,
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

xr_body_tracker_get_has_tracking_data :: proc "contextless" (
    self: Xr_Body_Tracker,
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

xr_body_tracker_set_body_flags :: proc "contextless" (
    self: Xr_Body_Tracker,
    flags_: Xr_Body_Tracker_Body_Flags,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_body_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2103235750)
    }
    self := self
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_body_tracker_get_body_flags :: proc "contextless" (
    self: Xr_Body_Tracker,
) -> (ret: Xr_Body_Tracker_Body_Flags) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_body_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3543166366)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_body_tracker_set_joint_flags :: proc "contextless" (
    self: Xr_Body_Tracker,
    joint_: Xr_Body_Tracker_Joint,
    flags_: Xr_Body_Tracker_Joint_Flags,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 592144999)
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

xr_body_tracker_get_joint_flags :: proc "contextless" (
    self: Xr_Body_Tracker,
    joint_: Xr_Body_Tracker_Joint,
) -> (ret: Xr_Body_Tracker_Joint_Flags) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1030162609)
    }
    self := self
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_body_tracker_set_joint_transform :: proc "contextless" (
    self: Xr_Body_Tracker,
    joint_: Xr_Body_Tracker_Joint,
    transform_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2635424328)
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

xr_body_tracker_get_joint_transform :: proc "contextless" (
    self: Xr_Body_Tracker,
    joint_: Xr_Body_Tracker_Joint,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3474811534)
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
xr_body_tracker_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("XRBodyTracker", true)
}

@(private = "file")
__class_name: String_Name