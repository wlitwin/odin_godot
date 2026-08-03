package godot

import __bindgen_gde "godot:gdext"

Lightmap_Gi_Constants :: enum {
}
Lightmap_Gi_Bake_Quality :: enum int {
    Bake_Quality_Low = 0,
    Bake_Quality_Medium = 1,
    Bake_Quality_High = 2,
    Bake_Quality_Ultra = 3,
}
Lightmap_Gi_Generate_Probes :: enum int {
    Generate_Probes_Disabled = 0,
    Generate_Probes_Subdiv_4 = 1,
    Generate_Probes_Subdiv_8 = 2,
    Generate_Probes_Subdiv_16 = 3,
    Generate_Probes_Subdiv_32 = 4,
}
Lightmap_Gi_Bake_Error :: enum int {
    Bake_Error_Ok = 0,
    Bake_Error_No_Scene_Root = 1,
    Bake_Error_Foreign_Data = 2,
    Bake_Error_No_Lightmapper = 3,
    Bake_Error_No_Save_Path = 4,
    Bake_Error_No_Meshes = 5,
    Bake_Error_Meshes_Invalid = 6,
    Bake_Error_Cant_Create_Image = 7,
    Bake_Error_User_Aborted = 8,
    Bake_Error_Texture_Size_Too_Small = 9,
    Bake_Error_Lightmap_Too_Small = 10,
    Bake_Error_Atlas_Too_Small = 11,
}
Lightmap_Gi_Environment_Mode :: enum int {
    Environment_Mode_Disabled = 0,
    Environment_Mode_Scene = 1,
    Environment_Mode_Custom_Sky = 2,
    Environment_Mode_Custom_Color = 3,
}



lightmap_gi_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

lightmap_gi_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_lightmap_gi :: proc "contextless" () -> Lightmap_Gi {
    return cast(Lightmap_Gi)__bindgen_gde.classdb_construct_object(lightmap_gi_name_ref())
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

lightmap_gi_set_light_data :: proc "contextless" (
    self: Lightmap_Gi,
    data_: Lightmap_Gi_Data,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_light_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1790597277)
    }
    self := self
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_light_data :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: Lightmap_Gi_Data) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_light_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 290354153)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_bake_quality :: proc "contextless" (
    self: Lightmap_Gi,
    bake_quality_: Lightmap_Gi_Bake_Quality,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bake_quality", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1192215803)
    }
    self := self
    bake_quality_ := bake_quality_
    args := []__bindgen_gde.TypePtr {
        &bake_quality_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_bake_quality :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: Lightmap_Gi_Bake_Quality) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bake_quality", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 688832735)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_bounces :: proc "contextless" (
    self: Lightmap_Gi,
    bounces_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bounces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    bounces_ := bounces_
    args := []__bindgen_gde.TypePtr {
        &bounces_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_bounces :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bounces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_bounce_indirect_energy :: proc "contextless" (
    self: Lightmap_Gi,
    bounce_indirect_energy_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bounce_indirect_energy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    bounce_indirect_energy_ := bounce_indirect_energy_
    args := []__bindgen_gde.TypePtr {
        &bounce_indirect_energy_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_bounce_indirect_energy :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bounce_indirect_energy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_generate_probes :: proc "contextless" (
    self: Lightmap_Gi,
    subdivision_: Lightmap_Gi_Generate_Probes,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_generate_probes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 549981046)
    }
    self := self
    subdivision_ := subdivision_
    args := []__bindgen_gde.TypePtr {
        &subdivision_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_generate_probes :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: Lightmap_Gi_Generate_Probes) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_generate_probes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3930596226)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_bias :: proc "contextless" (
    self: Lightmap_Gi,
    bias_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    bias_ := bias_
    args := []__bindgen_gde.TypePtr {
        &bias_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_bias :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_environment_mode :: proc "contextless" (
    self: Lightmap_Gi,
    mode_: Lightmap_Gi_Environment_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_environment_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2282650285)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_environment_mode :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: Lightmap_Gi_Environment_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_environment_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4128646479)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_environment_custom_sky :: proc "contextless" (
    self: Lightmap_Gi,
    sky_: Sky,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_environment_custom_sky", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3336722921)
    }
    self := self
    sky_ := sky_
    args := []__bindgen_gde.TypePtr {
        &sky_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_environment_custom_sky :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: Sky) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_environment_custom_sky", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1177136966)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_environment_custom_color :: proc "contextless" (
    self: Lightmap_Gi,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_environment_custom_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_environment_custom_color :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_environment_custom_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_environment_custom_energy :: proc "contextless" (
    self: Lightmap_Gi,
    energy_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_environment_custom_energy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    energy_ := energy_
    args := []__bindgen_gde.TypePtr {
        &energy_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_environment_custom_energy :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_environment_custom_energy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_texel_scale :: proc "contextless" (
    self: Lightmap_Gi,
    texel_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texel_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    texel_scale_ := texel_scale_
    args := []__bindgen_gde.TypePtr {
        &texel_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_texel_scale :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texel_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_max_texture_size :: proc "contextless" (
    self: Lightmap_Gi,
    max_texture_size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_texture_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    max_texture_size_ := max_texture_size_
    args := []__bindgen_gde.TypePtr {
        &max_texture_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_max_texture_size :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_texture_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_supersampling_enabled :: proc "contextless" (
    self: Lightmap_Gi,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_supersampling_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_is_supersampling_enabled :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_supersampling_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_supersampling_factor :: proc "contextless" (
    self: Lightmap_Gi,
    factor_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_supersampling_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    factor_ := factor_
    args := []__bindgen_gde.TypePtr {
        &factor_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_supersampling_factor :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_supersampling_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_use_denoiser :: proc "contextless" (
    self: Lightmap_Gi,
    use_denoiser_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_denoiser", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    use_denoiser_ := use_denoiser_
    args := []__bindgen_gde.TypePtr {
        &use_denoiser_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_is_using_denoiser :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_denoiser", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_denoiser_strength :: proc "contextless" (
    self: Lightmap_Gi,
    denoiser_strength_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_denoiser_strength", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    denoiser_strength_ := denoiser_strength_
    args := []__bindgen_gde.TypePtr {
        &denoiser_strength_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_denoiser_strength :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_denoiser_strength", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_denoiser_range :: proc "contextless" (
    self: Lightmap_Gi,
    denoiser_range_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_denoiser_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    denoiser_range_ := denoiser_range_
    args := []__bindgen_gde.TypePtr {
        &denoiser_range_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_denoiser_range :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_denoiser_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_interior :: proc "contextless" (
    self: Lightmap_Gi,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_interior", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_is_interior :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_interior", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_directional :: proc "contextless" (
    self: Lightmap_Gi,
    directional_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_directional", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    directional_ := directional_
    args := []__bindgen_gde.TypePtr {
        &directional_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_is_directional :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_directional", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_shadowmask_mode :: proc "contextless" (
    self: Lightmap_Gi,
    mode_: Lightmap_Gi_Data_Shadowmask_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadowmask_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3451066572)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_shadowmask_mode :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: Lightmap_Gi_Data_Shadowmask_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shadowmask_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 785478560)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_use_texture_for_bounces :: proc "contextless" (
    self: Lightmap_Gi,
    use_texture_for_bounces_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_texture_for_bounces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    use_texture_for_bounces_ := use_texture_for_bounces_
    args := []__bindgen_gde.TypePtr {
        &use_texture_for_bounces_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_is_using_texture_for_bounces :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_texture_for_bounces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

lightmap_gi_set_camera_attributes :: proc "contextless" (
    self: Lightmap_Gi,
    camera_attributes_: Camera_Attributes,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_camera_attributes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2817810567)
    }
    self := self
    camera_attributes_ := camera_attributes_
    args := []__bindgen_gde.TypePtr {
        &camera_attributes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

lightmap_gi_get_camera_attributes :: proc "contextless" (
    self: Lightmap_Gi,
) -> (ret: Camera_Attributes) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_camera_attributes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3921283215)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
lightmap_gi_get_quality :: proc "contextless" (self: Lightmap_Gi) -> Lightmap_Gi_Bake_Quality {
    return lightmap_gi_get_bake_quality(self)
}
lightmap_gi_set_quality :: proc "contextless" (self: Lightmap_Gi, value: Lightmap_Gi_Bake_Quality) {
    lightmap_gi_set_bake_quality(self, value)
}
lightmap_gi_get_supersampling :: proc "contextless" (self: Lightmap_Gi) -> Bool {
    return lightmap_gi_is_supersampling_enabled(self)
}
lightmap_gi_set_supersampling :: proc "contextless" (self: Lightmap_Gi, value: Bool) {
    lightmap_gi_set_supersampling_enabled(self, value)
}
lightmap_gi_get_directional :: proc "contextless" (self: Lightmap_Gi) -> Bool {
    return lightmap_gi_is_directional(self)
}
lightmap_gi_get_use_texture_for_bounces :: proc "contextless" (self: Lightmap_Gi) -> Bool {
    return lightmap_gi_is_using_texture_for_bounces(self)
}
lightmap_gi_get_interior :: proc "contextless" (self: Lightmap_Gi) -> Bool {
    return lightmap_gi_is_interior(self)
}
lightmap_gi_get_use_denoiser :: proc "contextless" (self: Lightmap_Gi) -> Bool {
    return lightmap_gi_is_using_denoiser(self)
}
lightmap_gi_get_generate_probes_subdiv :: proc "contextless" (self: Lightmap_Gi) -> Lightmap_Gi_Generate_Probes {
    return lightmap_gi_get_generate_probes(self)
}
lightmap_gi_set_generate_probes_subdiv :: proc "contextless" (self: Lightmap_Gi, value: Lightmap_Gi_Generate_Probes) {
    lightmap_gi_set_generate_probes(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
lightmap_gi_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("LightmapGI", true)
}

@(private = "file")
__class_name: String_Name