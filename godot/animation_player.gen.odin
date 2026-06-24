package godot

import __bindgen_gde "godot:gdext"

Animation_Player_Constants :: enum {
}
Animation_Player_Animation_Process_Callback :: enum int {
    Animation_Process_Physics = 0,
    Animation_Process_Idle = 1,
    Animation_Process_Manual = 2,
}
Animation_Player_Animation_Method_Call_Mode :: enum int {
    Animation_Method_Call_Deferred = 0,
    Animation_Method_Call_Immediate = 1,
}



animation_player_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

animation_player_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_animation_player :: proc "contextless" () -> Animation_Player {
    return __bindgen_gde.classdb_construct_object(animation_player_name_ref())
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

animation_player_animation_set_next :: proc "contextless" (
    self: Animation_Player,
    animation_from_: String_Name,
    animation_to_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("animation_set_next", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    animation_from_ := animation_from_
    animation_to_ := animation_to_
    args := []__bindgen_gde.TypePtr {
        &animation_from_,
        &animation_to_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_animation_get_next :: proc "contextless" (
    self: Animation_Player,
    animation_from_: String_Name,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("animation_get_next", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1965194235)
    }
    self := self
    animation_from_ := animation_from_
    args := []__bindgen_gde.TypePtr {
        &animation_from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_set_blend_time :: proc "contextless" (
    self: Animation_Player,
    animation_from_: String_Name,
    animation_to_: String_Name,
    sec_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_blend_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3231131886)
    }
    self := self
    animation_from_ := animation_from_
    animation_to_ := animation_to_
    sec_ := sec_
    args := []__bindgen_gde.TypePtr {
        &animation_from_,
        &animation_to_,
        &sec_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_blend_time :: proc "contextless" (
    self: Animation_Player,
    animation_from_: String_Name,
    animation_to_: String_Name,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_blend_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1958752504)
    }
    self := self
    animation_from_ := animation_from_
    animation_to_ := animation_to_
    args := []__bindgen_gde.TypePtr {
        &animation_from_,
        &animation_to_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_set_default_blend_time :: proc "contextless" (
    self: Animation_Player,
    sec_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_default_blend_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    sec_ := sec_
    args := []__bindgen_gde.TypePtr {
        &sec_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_default_blend_time :: proc "contextless" (
    self: Animation_Player,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_default_blend_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_set_auto_capture :: proc "contextless" (
    self: Animation_Player,
    auto_capture_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_capture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    auto_capture_ := auto_capture_
    args := []__bindgen_gde.TypePtr {
        &auto_capture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_is_auto_capture :: proc "contextless" (
    self: Animation_Player,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_auto_capture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_set_auto_capture_duration :: proc "contextless" (
    self: Animation_Player,
    auto_capture_duration_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_capture_duration", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    auto_capture_duration_ := auto_capture_duration_
    args := []__bindgen_gde.TypePtr {
        &auto_capture_duration_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_auto_capture_duration :: proc "contextless" (
    self: Animation_Player,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_auto_capture_duration", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_set_auto_capture_transition_type :: proc "contextless" (
    self: Animation_Player,
    auto_capture_transition_type_: Tween_Transition_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_capture_transition_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1058637742)
    }
    self := self
    auto_capture_transition_type_ := auto_capture_transition_type_
    args := []__bindgen_gde.TypePtr {
        &auto_capture_transition_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_auto_capture_transition_type :: proc "contextless" (
    self: Animation_Player,
) -> (ret: Tween_Transition_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_auto_capture_transition_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3842314528)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_set_auto_capture_ease_type :: proc "contextless" (
    self: Animation_Player,
    auto_capture_ease_type_: Tween_Ease_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_capture_ease_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1208105857)
    }
    self := self
    auto_capture_ease_type_ := auto_capture_ease_type_
    args := []__bindgen_gde.TypePtr {
        &auto_capture_ease_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_auto_capture_ease_type :: proc "contextless" (
    self: Animation_Player,
) -> (ret: Tween_Ease_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_auto_capture_ease_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 631880200)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_play :: proc "contextless" (
    self: Animation_Player,
    name_: String_Name,
    custom_blend_: f64,
    custom_speed_: f64,
    from_end_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("play", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3118260607)
    }
    self := self
    name_ := name_
    custom_blend_ := custom_blend_
    custom_speed_ := custom_speed_
    from_end_ := from_end_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &custom_blend_,
        &custom_speed_,
        &from_end_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_play_section_with_markers :: proc "contextless" (
    self: Animation_Player,
    name_: String_Name,
    start_marker_: String_Name,
    end_marker_: String_Name,
    custom_blend_: f64,
    custom_speed_: f64,
    from_end_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("play_section_with_markers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1421431412)
    }
    self := self
    name_ := name_
    start_marker_ := start_marker_
    end_marker_ := end_marker_
    custom_blend_ := custom_blend_
    custom_speed_ := custom_speed_
    from_end_ := from_end_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &start_marker_,
        &end_marker_,
        &custom_blend_,
        &custom_speed_,
        &from_end_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_play_section :: proc "contextless" (
    self: Animation_Player,
    name_: String_Name,
    start_time_: f64,
    end_time_: f64,
    custom_blend_: f64,
    custom_speed_: f64,
    from_end_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("play_section", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 284774635)
    }
    self := self
    name_ := name_
    start_time_ := start_time_
    end_time_ := end_time_
    custom_blend_ := custom_blend_
    custom_speed_ := custom_speed_
    from_end_ := from_end_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &start_time_,
        &end_time_,
        &custom_blend_,
        &custom_speed_,
        &from_end_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_play_backwards :: proc "contextless" (
    self: Animation_Player,
    name_: String_Name,
    custom_blend_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("play_backwards", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2787282401)
    }
    self := self
    name_ := name_
    custom_blend_ := custom_blend_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &custom_blend_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_play_section_with_markers_backwards :: proc "contextless" (
    self: Animation_Player,
    name_: String_Name,
    start_marker_: String_Name,
    end_marker_: String_Name,
    custom_blend_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("play_section_with_markers_backwards", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 910195100)
    }
    self := self
    name_ := name_
    start_marker_ := start_marker_
    end_marker_ := end_marker_
    custom_blend_ := custom_blend_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &start_marker_,
        &end_marker_,
        &custom_blend_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_play_section_backwards :: proc "contextless" (
    self: Animation_Player,
    name_: String_Name,
    start_time_: f64,
    end_time_: f64,
    custom_blend_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("play_section_backwards", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 831955981)
    }
    self := self
    name_ := name_
    start_time_ := start_time_
    end_time_ := end_time_
    custom_blend_ := custom_blend_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &start_time_,
        &end_time_,
        &custom_blend_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_play_with_capture :: proc "contextless" (
    self: Animation_Player,
    name_: String_Name,
    duration_: f64,
    custom_blend_: f64,
    custom_speed_: f64,
    from_end_: Bool,
    trans_type_: Tween_Transition_Type,
    ease_type_: Tween_Ease_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("play_with_capture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1572969103)
    }
    self := self
    name_ := name_
    duration_ := duration_
    custom_blend_ := custom_blend_
    custom_speed_ := custom_speed_
    from_end_ := from_end_
    trans_type_ := trans_type_
    ease_type_ := ease_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &duration_,
        &custom_blend_,
        &custom_speed_,
        &from_end_,
        &trans_type_,
        &ease_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_pause :: proc "contextless" (
    self: Animation_Player,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pause", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_stop :: proc "contextless" (
    self: Animation_Player,
    keep_state_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("stop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 107499316)
    }
    self := self
    keep_state_ := keep_state_
    args := []__bindgen_gde.TypePtr {
        &keep_state_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_is_playing :: proc "contextless" (
    self: Animation_Player,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_playing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_is_animation_active :: proc "contextless" (
    self: Animation_Player,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_animation_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_set_current_animation :: proc "contextless" (
    self: Animation_Player,
    animation_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_current_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    animation_ := animation_
    args := []__bindgen_gde.TypePtr {
        &animation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_current_animation :: proc "contextless" (
    self: Animation_Player,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2002593661)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_set_assigned_animation :: proc "contextless" (
    self: Animation_Player,
    animation_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_assigned_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    animation_ := animation_
    args := []__bindgen_gde.TypePtr {
        &animation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_assigned_animation :: proc "contextless" (
    self: Animation_Player,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_assigned_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2002593661)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_queue :: proc "contextless" (
    self: Animation_Player,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("queue", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_queue :: proc "contextless" (
    self: Animation_Player,
) -> (ret: Typed_Array(String_Name)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_queue", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_clear_queue :: proc "contextless" (
    self: Animation_Player,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_queue", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_set_speed_scale :: proc "contextless" (
    self: Animation_Player,
    speed_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_speed_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    speed_ := speed_
    args := []__bindgen_gde.TypePtr {
        &speed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_speed_scale :: proc "contextless" (
    self: Animation_Player,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_speed_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_get_playing_speed :: proc "contextless" (
    self: Animation_Player,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_playing_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_set_autoplay :: proc "contextless" (
    self: Animation_Player,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_autoplay", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_autoplay :: proc "contextless" (
    self: Animation_Player,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_autoplay", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2002593661)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_set_movie_quit_on_finish_enabled :: proc "contextless" (
    self: Animation_Player,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_movie_quit_on_finish_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_is_movie_quit_on_finish_enabled :: proc "contextless" (
    self: Animation_Player,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_movie_quit_on_finish_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_get_current_animation_position :: proc "contextless" (
    self: Animation_Player,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_animation_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_get_current_animation_length :: proc "contextless" (
    self: Animation_Player,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_animation_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_set_section_with_markers :: proc "contextless" (
    self: Animation_Player,
    start_marker_: String_Name,
    end_marker_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_section_with_markers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 794792241)
    }
    self := self
    start_marker_ := start_marker_
    end_marker_ := end_marker_
    args := []__bindgen_gde.TypePtr {
        &start_marker_,
        &end_marker_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_set_section :: proc "contextless" (
    self: Animation_Player,
    start_time_: f64,
    end_time_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_section", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3749779719)
    }
    self := self
    start_time_ := start_time_
    end_time_ := end_time_
    args := []__bindgen_gde.TypePtr {
        &start_time_,
        &end_time_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_reset_section :: proc "contextless" (
    self: Animation_Player,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reset_section", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_section_start_time :: proc "contextless" (
    self: Animation_Player,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_section_start_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_get_section_end_time :: proc "contextless" (
    self: Animation_Player,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_section_end_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_has_section :: proc "contextless" (
    self: Animation_Player,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_section", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_seek :: proc "contextless" (
    self: Animation_Player,
    seconds_: f64,
    update_: Bool,
    update_only_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("seek", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1807872683)
    }
    self := self
    seconds_ := seconds_
    update_ := update_
    update_only_ := update_only_
    args := []__bindgen_gde.TypePtr {
        &seconds_,
        &update_,
        &update_only_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_set_process_callback :: proc "contextless" (
    self: Animation_Player,
    mode_: Animation_Player_Animation_Process_Callback,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_process_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1663839457)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_process_callback :: proc "contextless" (
    self: Animation_Player,
) -> (ret: Animation_Player_Animation_Process_Callback) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_process_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4207496604)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_set_method_call_mode :: proc "contextless" (
    self: Animation_Player,
    mode_: Animation_Player_Animation_Method_Call_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_method_call_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3413514846)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_method_call_mode :: proc "contextless" (
    self: Animation_Player,
) -> (ret: Animation_Player_Animation_Method_Call_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_method_call_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3583380054)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_player_set_root :: proc "contextless" (
    self: Animation_Player,
    path_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_root", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1348162250)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_player_get_root :: proc "contextless" (
    self: Animation_Player,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_root", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4075236667)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
animation_player_get_playback_auto_capture :: proc "contextless" (self: Animation_Player) -> Bool {
    return animation_player_is_auto_capture(self)
}
animation_player_set_playback_auto_capture :: proc "contextless" (self: Animation_Player, value: Bool) {
    animation_player_set_auto_capture(self, value)
}
animation_player_get_playback_auto_capture_duration :: proc "contextless" (self: Animation_Player) -> f64 {
    return animation_player_get_auto_capture_duration(self)
}
animation_player_set_playback_auto_capture_duration :: proc "contextless" (self: Animation_Player, value: f64) {
    animation_player_set_auto_capture_duration(self, value)
}
animation_player_get_playback_auto_capture_transition_type :: proc "contextless" (self: Animation_Player) -> Tween_Transition_Type {
    return animation_player_get_auto_capture_transition_type(self)
}
animation_player_set_playback_auto_capture_transition_type :: proc "contextless" (self: Animation_Player, value: Tween_Transition_Type) {
    animation_player_set_auto_capture_transition_type(self, value)
}
animation_player_get_playback_auto_capture_ease_type :: proc "contextless" (self: Animation_Player) -> Tween_Ease_Type {
    return animation_player_get_auto_capture_ease_type(self)
}
animation_player_set_playback_auto_capture_ease_type :: proc "contextless" (self: Animation_Player, value: Tween_Ease_Type) {
    animation_player_set_auto_capture_ease_type(self, value)
}
animation_player_get_playback_default_blend_time :: proc "contextless" (self: Animation_Player) -> f64 {
    return animation_player_get_default_blend_time(self)
}
animation_player_set_playback_default_blend_time :: proc "contextless" (self: Animation_Player, value: f64) {
    animation_player_set_default_blend_time(self, value)
}
animation_player_get_movie_quit_on_finish :: proc "contextless" (self: Animation_Player) -> Bool {
    return animation_player_is_movie_quit_on_finish_enabled(self)
}
animation_player_set_movie_quit_on_finish :: proc "contextless" (self: Animation_Player, value: Bool) {
    animation_player_set_movie_quit_on_finish_enabled(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
animation_player_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AnimationPlayer", true)
}

@(private = "file")
__class_name: String_Name