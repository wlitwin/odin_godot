package godot

import __bindgen_gde "godot:gdext"

Audio_Server_Constants :: enum {
}
Audio_Server_Speaker_Mode :: enum int {
    Speaker_Mode_Stereo = 0,
    Speaker_Surround_31 = 1,
    Speaker_Surround_51 = 2,
    Speaker_Surround_71 = 3,
}
Audio_Server_Playback_Type :: enum int {
    Playback_Type_Default = 0,
    Playback_Type_Stream = 1,
    Playback_Type_Sample = 2,
    Playback_Type_Max = 3,
}



audio_server_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

audio_server_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_audio_server :: proc "contextless" () -> Audio_Server {
    return cast(Audio_Server)__bindgen_gde.classdb_construct_object(audio_server_name_ref())
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

audio_server_set_bus_count :: proc "contextless" (
    self: Audio_Server,
    amount_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bus_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_get_bus_count :: proc "contextless" (
    self: Audio_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bus_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_remove_bus :: proc "contextless" (
    self: Audio_Server,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_bus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_add_bus :: proc "contextless" (
    self: Audio_Server,
    at_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_bus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    at_position_ := at_position_
    args := []__bindgen_gde.TypePtr {
        &at_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_move_bus :: proc "contextless" (
    self: Audio_Server,
    index_: Int,
    to_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_bus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    index_ := index_
    to_index_ := to_index_
    args := []__bindgen_gde.TypePtr {
        &index_,
        &to_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_set_bus_name :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bus_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    bus_idx_ := bus_idx_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_get_bus_name :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bus_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    bus_idx_ := bus_idx_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_bus_index :: proc "contextless" (
    self: Audio_Server,
    bus_name_: String_Name,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bus_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2458036349)
    }
    self := self
    bus_name_ := bus_name_
    args := []__bindgen_gde.TypePtr {
        &bus_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_bus_channels :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bus_channels", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    bus_idx_ := bus_idx_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_set_bus_volume_db :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    volume_db_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bus_volume_db", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    bus_idx_ := bus_idx_
    volume_db_ := volume_db_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &volume_db_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_get_bus_volume_db :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bus_volume_db", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    bus_idx_ := bus_idx_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_set_bus_volume_linear :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    volume_linear_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bus_volume_linear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    bus_idx_ := bus_idx_
    volume_linear_ := volume_linear_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &volume_linear_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_get_bus_volume_linear :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bus_volume_linear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    bus_idx_ := bus_idx_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_set_bus_send :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    send_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bus_send", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3780747571)
    }
    self := self
    bus_idx_ := bus_idx_
    send_ := send_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &send_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_get_bus_send :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bus_send", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 659327637)
    }
    self := self
    bus_idx_ := bus_idx_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_set_bus_solo :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bus_solo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    bus_idx_ := bus_idx_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_is_bus_solo :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_bus_solo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    bus_idx_ := bus_idx_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_set_bus_mute :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bus_mute", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    bus_idx_ := bus_idx_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_is_bus_mute :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_bus_mute", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    bus_idx_ := bus_idx_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_set_bus_bypass_effects :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bus_bypass_effects", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    bus_idx_ := bus_idx_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_is_bus_bypassing_effects :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_bus_bypassing_effects", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    bus_idx_ := bus_idx_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_add_bus_effect :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    effect_: Audio_Effect,
    at_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_bus_effect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4068819785)
    }
    self := self
    bus_idx_ := bus_idx_
    effect_ := effect_
    at_position_ := at_position_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &effect_,
        &at_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_remove_bus_effect :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    effect_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_bus_effect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    bus_idx_ := bus_idx_
    effect_idx_ := effect_idx_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &effect_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_get_bus_effect_count :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bus_effect_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    bus_idx_ := bus_idx_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_bus_effect :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    effect_idx_: Int,
) -> (ret: Audio_Effect) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bus_effect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 726064442)
    }
    self := self
    bus_idx_ := bus_idx_
    effect_idx_ := effect_idx_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &effect_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_bus_effect_instance :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    effect_idx_: Int,
    channel_: Int,
) -> (ret: Audio_Effect_Instance) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bus_effect_instance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1829771234)
    }
    self := self
    bus_idx_ := bus_idx_
    effect_idx_ := effect_idx_
    channel_ := channel_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &effect_idx_,
        &channel_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_swap_bus_effects :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    effect_idx_: Int,
    by_effect_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("swap_bus_effects", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1649997291)
    }
    self := self
    bus_idx_ := bus_idx_
    effect_idx_ := effect_idx_
    by_effect_idx_ := by_effect_idx_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &effect_idx_,
        &by_effect_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_set_bus_effect_enabled :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    effect_idx_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bus_effect_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1383440665)
    }
    self := self
    bus_idx_ := bus_idx_
    effect_idx_ := effect_idx_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &effect_idx_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_is_bus_effect_enabled :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    effect_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_bus_effect_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2522259332)
    }
    self := self
    bus_idx_ := bus_idx_
    effect_idx_ := effect_idx_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &effect_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_bus_peak_volume_left_db :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    channel_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bus_peak_volume_left_db", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    bus_idx_ := bus_idx_
    channel_ := channel_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &channel_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_bus_peak_volume_right_db :: proc "contextless" (
    self: Audio_Server,
    bus_idx_: Int,
    channel_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bus_peak_volume_right_db", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    bus_idx_ := bus_idx_
    channel_ := channel_
    args := []__bindgen_gde.TypePtr {
        &bus_idx_,
        &channel_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_set_playback_speed_scale :: proc "contextless" (
    self: Audio_Server,
    scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_playback_speed_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_get_playback_speed_scale :: proc "contextless" (
    self: Audio_Server,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_playback_speed_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_lock :: proc "contextless" (
    self: Audio_Server,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("lock", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_unlock :: proc "contextless" (
    self: Audio_Server,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unlock", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_get_speaker_mode :: proc "contextless" (
    self: Audio_Server,
) -> (ret: Audio_Server_Speaker_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_speaker_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2549190337)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_mix_rate :: proc "contextless" (
    self: Audio_Server,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mix_rate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_input_mix_rate :: proc "contextless" (
    self: Audio_Server,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_mix_rate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_driver_name :: proc "contextless" (
    self: Audio_Server,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_driver_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_output_device_list :: proc "contextless" (
    self: Audio_Server,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_output_device_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2981934095)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_output_device :: proc "contextless" (
    self: Audio_Server,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_output_device", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2841200299)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_set_output_device :: proc "contextless" (
    self: Audio_Server,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_output_device", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_get_time_to_next_mix :: proc "contextless" (
    self: Audio_Server,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_time_to_next_mix", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_time_since_last_mix :: proc "contextless" (
    self: Audio_Server,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_time_since_last_mix", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_output_latency :: proc "contextless" (
    self: Audio_Server,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_output_latency", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_input_device_list :: proc "contextless" (
    self: Audio_Server,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_device_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2981934095)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_input_device :: proc "contextless" (
    self: Audio_Server,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_device", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2841200299)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_set_input_device :: proc "contextless" (
    self: Audio_Server,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_input_device", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_set_input_device_active :: proc "contextless" (
    self: Audio_Server,
    active_: Bool,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_input_device_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1413768114)
    }
    self := self
    active_ := active_
    args := []__bindgen_gde.TypePtr {
        &active_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_input_frames_available :: proc "contextless" (
    self: Audio_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_frames_available", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_input_buffer_length_frames :: proc "contextless" (
    self: Audio_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_buffer_length_frames", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_get_input_frames :: proc "contextless" (
    self: Audio_Server,
    frames_: Int,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_frames", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2649534757)
    }
    self := self
    frames_ := frames_
    args := []__bindgen_gde.TypePtr {
        &frames_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_set_bus_layout :: proc "contextless" (
    self: Audio_Server,
    bus_layout_: Audio_Bus_Layout,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bus_layout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3319058824)
    }
    self := self
    bus_layout_ := bus_layout_
    args := []__bindgen_gde.TypePtr {
        &bus_layout_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_generate_bus_layout :: proc "contextless" (
    self: Audio_Server,
) -> (ret: Audio_Bus_Layout) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generate_bus_layout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3769973890)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_set_enable_tagging_used_audio_streams :: proc "contextless" (
    self: Audio_Server,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_enable_tagging_used_audio_streams", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

audio_server_is_stream_registered_as_sample :: proc "contextless" (
    self: Audio_Server,
    stream_: Audio_Stream,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_stream_registered_as_sample", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 500225754)
    }
    self := self
    stream_ := stream_
    args := []__bindgen_gde.TypePtr {
        &stream_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

audio_server_register_stream_as_sample :: proc "contextless" (
    self: Audio_Server,
    stream_: Audio_Stream,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_stream_as_sample", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2210767741)
    }
    self := self
    stream_ := stream_
    args := []__bindgen_gde.TypePtr {
        &stream_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
audio_server_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AudioServer", true)
}

@(private = "file")
__class_name: String_Name