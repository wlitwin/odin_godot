package godot

import __bindgen_gde "godot:gdext"

Light3d_Constants :: enum {
}
Light3d_Param :: enum int {
    Param_Energy = 0,
    Param_Indirect_Energy = 1,
    Param_Volumetric_Fog_Energy = 2,
    Param_Specular = 3,
    Param_Range = 4,
    Param_Size = 5,
    Param_Attenuation = 6,
    Param_Spot_Angle = 7,
    Param_Spot_Attenuation = 8,
    Param_Shadow_Max_Distance = 9,
    Param_Shadow_Split_1_Offset = 10,
    Param_Shadow_Split_2_Offset = 11,
    Param_Shadow_Split_3_Offset = 12,
    Param_Shadow_Fade_Start = 13,
    Param_Shadow_Normal_Bias = 14,
    Param_Shadow_Bias = 15,
    Param_Shadow_Pancake_Size = 16,
    Param_Shadow_Opacity = 17,
    Param_Shadow_Blur = 18,
    Param_Transmittance_Bias = 19,
    Param_Intensity = 20,
    Param_Max = 21,
}
Light3d_Bake_Mode :: enum int {
    Bake_Disabled = 0,
    Bake_Static = 1,
    Bake_Dynamic = 2,
}



light3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

light3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_light3d :: proc "contextless" () -> Light3d {
    return __bindgen_gde.classdb_construct_object(light3d_name_ref())
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

light3d_set_editor_only :: proc "contextless" (
    self: Light3d,
    editor_only_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_editor_only", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    editor_only_ := editor_only_
    args := []__bindgen_gde.TypePtr {
        &editor_only_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_is_editor_only :: proc "contextless" (
    self: Light3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_editor_only", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_param :: proc "contextless" (
    self: Light3d,
    param_: Light3d_Param,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1722734213)
    }
    self := self
    param_ := param_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &param_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_get_param :: proc "contextless" (
    self: Light3d,
    param_: Light3d_Param,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1844084987)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_shadow :: proc "contextless" (
    self: Light3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadow", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_has_shadow :: proc "contextless" (
    self: Light3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_shadow", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_negative :: proc "contextless" (
    self: Light3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_negative", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_is_negative :: proc "contextless" (
    self: Light3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_negative", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_cull_mask :: proc "contextless" (
    self: Light3d,
    cull_mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cull_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    cull_mask_ := cull_mask_
    args := []__bindgen_gde.TypePtr {
        &cull_mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_get_cull_mask :: proc "contextless" (
    self: Light3d,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cull_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_enable_distance_fade :: proc "contextless" (
    self: Light3d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_enable_distance_fade", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_is_distance_fade_enabled :: proc "contextless" (
    self: Light3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_distance_fade_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_distance_fade_begin :: proc "contextless" (
    self: Light3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_distance_fade_begin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_get_distance_fade_begin :: proc "contextless" (
    self: Light3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_distance_fade_begin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_distance_fade_shadow :: proc "contextless" (
    self: Light3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_distance_fade_shadow", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_get_distance_fade_shadow :: proc "contextless" (
    self: Light3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_distance_fade_shadow", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_distance_fade_length :: proc "contextless" (
    self: Light3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_distance_fade_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_get_distance_fade_length :: proc "contextless" (
    self: Light3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_distance_fade_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_color :: proc "contextless" (
    self: Light3d,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_get_color :: proc "contextless" (
    self: Light3d,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_shadow_reverse_cull_face :: proc "contextless" (
    self: Light3d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadow_reverse_cull_face", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_get_shadow_reverse_cull_face :: proc "contextless" (
    self: Light3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shadow_reverse_cull_face", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_shadow_caster_mask :: proc "contextless" (
    self: Light3d,
    caster_mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadow_caster_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    caster_mask_ := caster_mask_
    args := []__bindgen_gde.TypePtr {
        &caster_mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_get_shadow_caster_mask :: proc "contextless" (
    self: Light3d,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shadow_caster_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_bake_mode :: proc "contextless" (
    self: Light3d,
    bake_mode_: Light3d_Bake_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bake_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 37739303)
    }
    self := self
    bake_mode_ := bake_mode_
    args := []__bindgen_gde.TypePtr {
        &bake_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_get_bake_mode :: proc "contextless" (
    self: Light3d,
) -> (ret: Light3d_Bake_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bake_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 371737608)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_projector :: proc "contextless" (
    self: Light3d,
    projector_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_projector", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    projector_ := projector_
    args := []__bindgen_gde.TypePtr {
        &projector_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_get_projector :: proc "contextless" (
    self: Light3d,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_projector", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_set_temperature :: proc "contextless" (
    self: Light3d,
    temperature_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_temperature", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    temperature_ := temperature_
    args := []__bindgen_gde.TypePtr {
        &temperature_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light3d_get_temperature :: proc "contextless" (
    self: Light3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_temperature", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light3d_get_correlated_color :: proc "contextless" (
    self: Light3d,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_correlated_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
light3d_get_light_intensity_lumens :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_param(self, Light3d_Param(20))
}
light3d_set_light_intensity_lumens :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_param(self, Light3d_Param(20), value)
}
light3d_get_light_intensity_lux :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_param(self, Light3d_Param(20))
}
light3d_set_light_intensity_lux :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_param(self, Light3d_Param(20), value)
}
light3d_get_light_temperature :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_temperature(self)
}
light3d_set_light_temperature :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_temperature(self, value)
}
light3d_get_light_color :: proc "contextless" (self: Light3d) -> Color {
    return light3d_get_color(self)
}
light3d_set_light_color :: proc "contextless" (self: Light3d, value: Color) {
    light3d_set_color(self, value)
}
light3d_get_light_energy :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_param(self, Light3d_Param(0))
}
light3d_set_light_energy :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_param(self, Light3d_Param(0), value)
}
light3d_get_light_indirect_energy :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_param(self, Light3d_Param(1))
}
light3d_set_light_indirect_energy :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_param(self, Light3d_Param(1), value)
}
light3d_get_light_volumetric_fog_energy :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_param(self, Light3d_Param(2))
}
light3d_set_light_volumetric_fog_energy :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_param(self, Light3d_Param(2), value)
}
light3d_get_light_projector :: proc "contextless" (self: Light3d) -> Texture2d {
    return light3d_get_projector(self)
}
light3d_set_light_projector :: proc "contextless" (self: Light3d, value: Texture2d) {
    light3d_set_projector(self, value)
}
light3d_get_light_size :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_param(self, Light3d_Param(5))
}
light3d_set_light_size :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_param(self, Light3d_Param(5), value)
}
light3d_get_light_angular_distance :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_param(self, Light3d_Param(5))
}
light3d_set_light_angular_distance :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_param(self, Light3d_Param(5), value)
}
light3d_get_light_negative :: proc "contextless" (self: Light3d) -> Bool {
    return light3d_is_negative(self)
}
light3d_set_light_negative :: proc "contextless" (self: Light3d, value: Bool) {
    light3d_set_negative(self, value)
}
light3d_get_light_specular :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_param(self, Light3d_Param(3))
}
light3d_set_light_specular :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_param(self, Light3d_Param(3), value)
}
light3d_get_light_bake_mode :: proc "contextless" (self: Light3d) -> Light3d_Bake_Mode {
    return light3d_get_bake_mode(self)
}
light3d_set_light_bake_mode :: proc "contextless" (self: Light3d, value: Light3d_Bake_Mode) {
    light3d_set_bake_mode(self, value)
}
light3d_get_light_cull_mask :: proc "contextless" (self: Light3d) -> u32 {
    return light3d_get_cull_mask(self)
}
light3d_set_light_cull_mask :: proc "contextless" (self: Light3d, value: Int) {
    light3d_set_cull_mask(self, value)
}
light3d_get_shadow_enabled :: proc "contextless" (self: Light3d) -> Bool {
    return light3d_has_shadow(self)
}
light3d_set_shadow_enabled :: proc "contextless" (self: Light3d, value: Bool) {
    light3d_set_shadow(self, value)
}
light3d_get_shadow_bias :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_param(self, Light3d_Param(15))
}
light3d_set_shadow_bias :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_param(self, Light3d_Param(15), value)
}
light3d_get_shadow_normal_bias :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_param(self, Light3d_Param(14))
}
light3d_set_shadow_normal_bias :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_param(self, Light3d_Param(14), value)
}
light3d_get_shadow_transmittance_bias :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_param(self, Light3d_Param(19))
}
light3d_set_shadow_transmittance_bias :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_param(self, Light3d_Param(19), value)
}
light3d_get_shadow_opacity :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_param(self, Light3d_Param(17))
}
light3d_set_shadow_opacity :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_param(self, Light3d_Param(17), value)
}
light3d_get_shadow_blur :: proc "contextless" (self: Light3d) -> f64 {
    return light3d_get_param(self, Light3d_Param(18))
}
light3d_set_shadow_blur :: proc "contextless" (self: Light3d, value: f64) {
    light3d_set_param(self, Light3d_Param(18), value)
}
light3d_get_distance_fade_enabled :: proc "contextless" (self: Light3d) -> Bool {
    return light3d_is_distance_fade_enabled(self)
}
light3d_set_distance_fade_enabled :: proc "contextless" (self: Light3d, value: Bool) {
    light3d_set_enable_distance_fade(self, value)
}
light3d_get_editor_only :: proc "contextless" (self: Light3d) -> Bool {
    return light3d_is_editor_only(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
light3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Light3D", true)
}

@(private = "file")
__class_name: String_Name