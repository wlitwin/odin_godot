package godot

import __bindgen_gde "godot:gdext"

Xr_Positional_Tracker_Constants :: enum {
}
Xr_Positional_Tracker_Tracker_Hand :: enum int {
    Tracker_Hand_Unknown = 0,
    Tracker_Hand_Left = 1,
    Tracker_Hand_Right = 2,
    Tracker_Hand_Max = 3,
}



xr_positional_tracker_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

xr_positional_tracker_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_xr_positional_tracker :: proc "contextless" () -> Xr_Positional_Tracker {
    return cast(Xr_Positional_Tracker)__bindgen_gde.classdb_construct_object(xr_positional_tracker_name_ref())
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

xr_positional_tracker_get_tracker_profile :: proc "contextless" (
    self: Xr_Positional_Tracker,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tracker_profile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_positional_tracker_set_tracker_profile :: proc "contextless" (
    self: Xr_Positional_Tracker,
    profile_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tracker_profile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    profile_ := profile_
    args := []__bindgen_gde.TypePtr {
        &profile_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_positional_tracker_get_tracker_hand :: proc "contextless" (
    self: Xr_Positional_Tracker,
) -> (ret: Xr_Positional_Tracker_Tracker_Hand) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tracker_hand", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4181770860)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_positional_tracker_set_tracker_hand :: proc "contextless" (
    self: Xr_Positional_Tracker,
    hand_: Xr_Positional_Tracker_Tracker_Hand,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tracker_hand", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3904108980)
    }
    self := self
    hand_ := hand_
    args := []__bindgen_gde.TypePtr {
        &hand_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_positional_tracker_has_pose :: proc "contextless" (
    self: Xr_Positional_Tracker,
    name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_pose", true)
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

xr_positional_tracker_get_pose :: proc "contextless" (
    self: Xr_Positional_Tracker,
    name_: String_Name,
) -> (ret: Xr_Pose) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4099720006)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_positional_tracker_invalidate_pose :: proc "contextless" (
    self: Xr_Positional_Tracker,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("invalidate_pose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_positional_tracker_set_pose :: proc "contextless" (
    self: Xr_Positional_Tracker,
    name_: String_Name,
    transform_: Transform3d,
    linear_velocity_: Vector3,
    angular_velocity_: Vector3,
    tracking_confidence_: Xr_Pose_Tracking_Confidence,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_pose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3451230163)
    }
    self := self
    name_ := name_
    transform_ := transform_
    linear_velocity_ := linear_velocity_
    angular_velocity_ := angular_velocity_
    tracking_confidence_ := tracking_confidence_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &transform_,
        &linear_velocity_,
        &angular_velocity_,
        &tracking_confidence_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_positional_tracker_get_input :: proc "contextless" (
    self: Xr_Positional_Tracker,
    name_: String_Name,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2760726917)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_positional_tracker_set_input :: proc "contextless" (
    self: Xr_Positional_Tracker,
    name_: String_Name,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_input", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3776071444)
    }
    self := self
    name_ := name_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
xr_positional_tracker_get_profile :: proc "contextless" (self: Xr_Positional_Tracker) -> String {
    return xr_positional_tracker_get_tracker_profile(self)
}
xr_positional_tracker_set_profile :: proc "contextless" (self: Xr_Positional_Tracker, value: String) {
    xr_positional_tracker_set_tracker_profile(self, value)
}
xr_positional_tracker_get_hand :: proc "contextless" (self: Xr_Positional_Tracker) -> Xr_Positional_Tracker_Tracker_Hand {
    return xr_positional_tracker_get_tracker_hand(self)
}
xr_positional_tracker_set_hand :: proc "contextless" (self: Xr_Positional_Tracker, value: Xr_Positional_Tracker_Tracker_Hand) {
    xr_positional_tracker_set_tracker_hand(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
xr_positional_tracker_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("XRPositionalTracker", true)
}

@(private = "file")
__class_name: String_Name