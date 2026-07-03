package godot

import __bindgen_gde "godot:gdext"

Xr_Face_Tracker_Constants :: enum {
}
Xr_Face_Tracker_Blend_Shape_Entry :: enum int {
    Ft_Eye_Look_Out_Right = 0,
    Ft_Eye_Look_In_Right = 1,
    Ft_Eye_Look_Up_Right = 2,
    Ft_Eye_Look_Down_Right = 3,
    Ft_Eye_Look_Out_Left = 4,
    Ft_Eye_Look_In_Left = 5,
    Ft_Eye_Look_Up_Left = 6,
    Ft_Eye_Look_Down_Left = 7,
    Ft_Eye_Closed_Right = 8,
    Ft_Eye_Closed_Left = 9,
    Ft_Eye_Squint_Right = 10,
    Ft_Eye_Squint_Left = 11,
    Ft_Eye_Wide_Right = 12,
    Ft_Eye_Wide_Left = 13,
    Ft_Eye_Dilation_Right = 14,
    Ft_Eye_Dilation_Left = 15,
    Ft_Eye_Constrict_Right = 16,
    Ft_Eye_Constrict_Left = 17,
    Ft_Brow_Pinch_Right = 18,
    Ft_Brow_Pinch_Left = 19,
    Ft_Brow_Lowerer_Right = 20,
    Ft_Brow_Lowerer_Left = 21,
    Ft_Brow_Inner_Up_Right = 22,
    Ft_Brow_Inner_Up_Left = 23,
    Ft_Brow_Outer_Up_Right = 24,
    Ft_Brow_Outer_Up_Left = 25,
    Ft_Nose_Sneer_Right = 26,
    Ft_Nose_Sneer_Left = 27,
    Ft_Nasal_Dilation_Right = 28,
    Ft_Nasal_Dilation_Left = 29,
    Ft_Nasal_Constrict_Right = 30,
    Ft_Nasal_Constrict_Left = 31,
    Ft_Cheek_Squint_Right = 32,
    Ft_Cheek_Squint_Left = 33,
    Ft_Cheek_Puff_Right = 34,
    Ft_Cheek_Puff_Left = 35,
    Ft_Cheek_Suck_Right = 36,
    Ft_Cheek_Suck_Left = 37,
    Ft_Jaw_Open = 38,
    Ft_Mouth_Closed = 39,
    Ft_Jaw_Right = 40,
    Ft_Jaw_Left = 41,
    Ft_Jaw_Forward = 42,
    Ft_Jaw_Backward = 43,
    Ft_Jaw_Clench = 44,
    Ft_Jaw_Mandible_Raise = 45,
    Ft_Lip_Suck_Upper_Right = 46,
    Ft_Lip_Suck_Upper_Left = 47,
    Ft_Lip_Suck_Lower_Right = 48,
    Ft_Lip_Suck_Lower_Left = 49,
    Ft_Lip_Suck_Corner_Right = 50,
    Ft_Lip_Suck_Corner_Left = 51,
    Ft_Lip_Funnel_Upper_Right = 52,
    Ft_Lip_Funnel_Upper_Left = 53,
    Ft_Lip_Funnel_Lower_Right = 54,
    Ft_Lip_Funnel_Lower_Left = 55,
    Ft_Lip_Pucker_Upper_Right = 56,
    Ft_Lip_Pucker_Upper_Left = 57,
    Ft_Lip_Pucker_Lower_Right = 58,
    Ft_Lip_Pucker_Lower_Left = 59,
    Ft_Mouth_Upper_Up_Right = 60,
    Ft_Mouth_Upper_Up_Left = 61,
    Ft_Mouth_Lower_Down_Right = 62,
    Ft_Mouth_Lower_Down_Left = 63,
    Ft_Mouth_Upper_Deepen_Right = 64,
    Ft_Mouth_Upper_Deepen_Left = 65,
    Ft_Mouth_Upper_Right = 66,
    Ft_Mouth_Upper_Left = 67,
    Ft_Mouth_Lower_Right = 68,
    Ft_Mouth_Lower_Left = 69,
    Ft_Mouth_Corner_Pull_Right = 70,
    Ft_Mouth_Corner_Pull_Left = 71,
    Ft_Mouth_Corner_Slant_Right = 72,
    Ft_Mouth_Corner_Slant_Left = 73,
    Ft_Mouth_Frown_Right = 74,
    Ft_Mouth_Frown_Left = 75,
    Ft_Mouth_Stretch_Right = 76,
    Ft_Mouth_Stretch_Left = 77,
    Ft_Mouth_Dimple_Right = 78,
    Ft_Mouth_Dimple_Left = 79,
    Ft_Mouth_Raiser_Upper = 80,
    Ft_Mouth_Raiser_Lower = 81,
    Ft_Mouth_Press_Right = 82,
    Ft_Mouth_Press_Left = 83,
    Ft_Mouth_Tightener_Right = 84,
    Ft_Mouth_Tightener_Left = 85,
    Ft_Tongue_Out = 86,
    Ft_Tongue_Up = 87,
    Ft_Tongue_Down = 88,
    Ft_Tongue_Right = 89,
    Ft_Tongue_Left = 90,
    Ft_Tongue_Roll = 91,
    Ft_Tongue_Blend_Down = 92,
    Ft_Tongue_Curl_Up = 93,
    Ft_Tongue_Squish = 94,
    Ft_Tongue_Flat = 95,
    Ft_Tongue_Twist_Right = 96,
    Ft_Tongue_Twist_Left = 97,
    Ft_Soft_Palate_Close = 98,
    Ft_Throat_Swallow = 99,
    Ft_Neck_Flex_Right = 100,
    Ft_Neck_Flex_Left = 101,
    Ft_Eye_Closed = 102,
    Ft_Eye_Wide = 103,
    Ft_Eye_Squint = 104,
    Ft_Eye_Dilation = 105,
    Ft_Eye_Constrict = 106,
    Ft_Brow_Down_Right = 107,
    Ft_Brow_Down_Left = 108,
    Ft_Brow_Down = 109,
    Ft_Brow_Up_Right = 110,
    Ft_Brow_Up_Left = 111,
    Ft_Brow_Up = 112,
    Ft_Nose_Sneer = 113,
    Ft_Nasal_Dilation = 114,
    Ft_Nasal_Constrict = 115,
    Ft_Cheek_Puff = 116,
    Ft_Cheek_Suck = 117,
    Ft_Cheek_Squint = 118,
    Ft_Lip_Suck_Upper = 119,
    Ft_Lip_Suck_Lower = 120,
    Ft_Lip_Suck = 121,
    Ft_Lip_Funnel_Upper = 122,
    Ft_Lip_Funnel_Lower = 123,
    Ft_Lip_Funnel = 124,
    Ft_Lip_Pucker_Upper = 125,
    Ft_Lip_Pucker_Lower = 126,
    Ft_Lip_Pucker = 127,
    Ft_Mouth_Upper_Up = 128,
    Ft_Mouth_Lower_Down = 129,
    Ft_Mouth_Open = 130,
    Ft_Mouth_Right = 131,
    Ft_Mouth_Left = 132,
    Ft_Mouth_Smile_Right = 133,
    Ft_Mouth_Smile_Left = 134,
    Ft_Mouth_Smile = 135,
    Ft_Mouth_Sad_Right = 136,
    Ft_Mouth_Sad_Left = 137,
    Ft_Mouth_Sad = 138,
    Ft_Mouth_Stretch = 139,
    Ft_Mouth_Dimple = 140,
    Ft_Mouth_Tightener = 141,
    Ft_Mouth_Press = 142,
    Ft_Max = 143,
}



xr_face_tracker_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

xr_face_tracker_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_xr_face_tracker :: proc "contextless" () -> Xr_Face_Tracker {
    return cast(Xr_Face_Tracker)__bindgen_gde.classdb_construct_object(xr_face_tracker_name_ref())
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

xr_face_tracker_get_blend_shape :: proc "contextless" (
    self: Xr_Face_Tracker,
    blend_shape_: Xr_Face_Tracker_Blend_Shape_Entry,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_blend_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 330010046)
    }
    self := self
    blend_shape_ := blend_shape_
    args := []__bindgen_gde.TypePtr {
        &blend_shape_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_face_tracker_set_blend_shape :: proc "contextless" (
    self: Xr_Face_Tracker,
    blend_shape_: Xr_Face_Tracker_Blend_Shape_Entry,
    weight_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_blend_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2352588791)
    }
    self := self
    blend_shape_ := blend_shape_
    weight_ := weight_
    args := []__bindgen_gde.TypePtr {
        &blend_shape_,
        &weight_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

xr_face_tracker_get_blend_shapes :: proc "contextless" (
    self: Xr_Face_Tracker,
) -> (ret: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_blend_shapes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 675695659)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

xr_face_tracker_set_blend_shapes :: proc "contextless" (
    self: Xr_Face_Tracker,
    weights_: Packed_Float32_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_blend_shapes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2899603908)
    }
    self := self
    weights_ := weights_
    args := []__bindgen_gde.TypePtr {
        &weights_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
xr_face_tracker_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("XRFaceTracker", true)
}

@(private = "file")
__class_name: String_Name