package godot

import __bindgen_gde "godot:gdext"

Base_Material3d_Constants :: enum {
}
Base_Material3d_Texture_Param :: enum int {
    Texture_Albedo = 0,
    Texture_Metallic = 1,
    Texture_Roughness = 2,
    Texture_Emission = 3,
    Texture_Normal = 4,
    Texture_Bent_Normal = 18,
    Texture_Rim = 5,
    Texture_Clearcoat = 6,
    Texture_Flowmap = 7,
    Texture_Ambient_Occlusion = 8,
    Texture_Heightmap = 9,
    Texture_Subsurface_Scattering = 10,
    Texture_Subsurface_Transmittance = 11,
    Texture_Backlight = 12,
    Texture_Refraction = 13,
    Texture_Detail_Mask = 14,
    Texture_Detail_Albedo = 15,
    Texture_Detail_Normal = 16,
    Texture_Orm = 17,
    Texture_Max = 19,
}
Base_Material3d_Texture_Filter :: enum int {
    Texture_Filter_Nearest = 0,
    Texture_Filter_Linear = 1,
    Texture_Filter_Nearest_With_Mipmaps = 2,
    Texture_Filter_Linear_With_Mipmaps = 3,
    Texture_Filter_Nearest_With_Mipmaps_Anisotropic = 4,
    Texture_Filter_Linear_With_Mipmaps_Anisotropic = 5,
    Texture_Filter_Max = 6,
}
Base_Material3d_Detail_Uv :: enum int {
    Detail_Uv_1 = 0,
    Detail_Uv_2 = 1,
}
Base_Material3d_Transparency :: enum int {
    Transparency_Disabled = 0,
    Transparency_Alpha = 1,
    Transparency_Alpha_Scissor = 2,
    Transparency_Alpha_Hash = 3,
    Transparency_Alpha_Depth_Pre_Pass = 4,
    Transparency_Max = 5,
}
Base_Material3d_Shading_Mode :: enum int {
    Shading_Mode_Unshaded = 0,
    Shading_Mode_Per_Pixel = 1,
    Shading_Mode_Per_Vertex = 2,
    Shading_Mode_Max = 3,
}
Base_Material3d_Feature :: enum int {
    Feature_Emission = 0,
    Feature_Normal_Mapping = 1,
    Feature_Rim = 2,
    Feature_Clearcoat = 3,
    Feature_Anisotropy = 4,
    Feature_Ambient_Occlusion = 5,
    Feature_Height_Mapping = 6,
    Feature_Subsurface_Scattering = 7,
    Feature_Subsurface_Transmittance = 8,
    Feature_Backlight = 9,
    Feature_Refraction = 10,
    Feature_Detail = 11,
    Feature_Bent_Normal_Mapping = 12,
    Feature_Max = 13,
}
Base_Material3d_Blend_Mode :: enum int {
    Blend_Mode_Mix = 0,
    Blend_Mode_Add = 1,
    Blend_Mode_Sub = 2,
    Blend_Mode_Mul = 3,
    Blend_Mode_Premult_Alpha = 4,
}
Base_Material3d_Alpha_Anti_Aliasing :: enum int {
    Alpha_Antialiasing_Off = 0,
    Alpha_Antialiasing_Alpha_To_Coverage = 1,
    Alpha_Antialiasing_Alpha_To_Coverage_And_To_One = 2,
}
Base_Material3d_Depth_Draw_Mode :: enum int {
    Depth_Draw_Opaque_Only = 0,
    Depth_Draw_Always = 1,
    Depth_Draw_Disabled = 2,
}
Base_Material3d_Depth_Test :: enum int {
    Depth_Test_Default = 0,
    Depth_Test_Inverted = 1,
}
Base_Material3d_Cull_Mode :: enum int {
    Cull_Back = 0,
    Cull_Front = 1,
    Cull_Disabled = 2,
}
Base_Material3d_Flags :: enum int {
    Flag_Disable_Depth_Test = 0,
    Flag_Albedo_From_Vertex_Color = 1,
    Flag_Srgb_Vertex_Color = 2,
    Flag_Use_Point_Size = 3,
    Flag_Fixed_Size = 4,
    Flag_Billboard_Keep_Scale = 5,
    Flag_Uv1_Use_Triplanar = 6,
    Flag_Uv2_Use_Triplanar = 7,
    Flag_Uv1_Use_World_Triplanar = 8,
    Flag_Uv2_Use_World_Triplanar = 9,
    Flag_Ao_On_Uv2 = 10,
    Flag_Emission_On_Uv2 = 11,
    Flag_Albedo_Texture_Force_Srgb = 12,
    Flag_Dont_Receive_Shadows = 13,
    Flag_Disable_Ambient_Light = 14,
    Flag_Use_Shadow_To_Opacity = 15,
    Flag_Use_Texture_Repeat = 16,
    Flag_Invert_Heightmap = 17,
    Flag_Subsurface_Mode_Skin = 18,
    Flag_Particle_Trails_Mode = 19,
    Flag_Albedo_Texture_Msdf = 20,
    Flag_Disable_Fog = 21,
    Flag_Disable_Specular_Occlusion = 22,
    Flag_Use_Z_Clip_Scale = 23,
    Flag_Use_Fov_Override = 24,
    Flag_Max = 25,
}
Base_Material3d_Diffuse_Mode :: enum int {
    Diffuse_Burley = 0,
    Diffuse_Lambert = 1,
    Diffuse_Lambert_Wrap = 2,
    Diffuse_Toon = 3,
}
Base_Material3d_Specular_Mode :: enum int {
    Specular_Schlick_Ggx = 0,
    Specular_Toon = 1,
    Specular_Disabled = 2,
}
Base_Material3d_Billboard_Mode :: enum int {
    Billboard_Disabled = 0,
    Billboard_Enabled = 1,
    Billboard_Fixed_Y = 2,
    Billboard_Particles = 3,
}
Base_Material3d_Texture_Channel :: enum int {
    Texture_Channel_Red = 0,
    Texture_Channel_Green = 1,
    Texture_Channel_Blue = 2,
    Texture_Channel_Alpha = 3,
    Texture_Channel_Grayscale = 4,
}
Base_Material3d_Emission_Operator :: enum int {
    Emission_Op_Add = 0,
    Emission_Op_Multiply = 1,
}
Base_Material3d_Distance_Fade_Mode :: enum int {
    Distance_Fade_Disabled = 0,
    Distance_Fade_Pixel_Alpha = 1,
    Distance_Fade_Pixel_Dither = 2,
    Distance_Fade_Object_Dither = 3,
}
Base_Material3d_Stencil_Mode :: enum int {
    Stencil_Mode_Disabled = 0,
    Stencil_Mode_Outline = 1,
    Stencil_Mode_Xray = 2,
    Stencil_Mode_Custom = 3,
}
Base_Material3d_Stencil_Flags :: enum int {
    Stencil_Flag_Read = 1,
    Stencil_Flag_Write = 2,
    Stencil_Flag_Write_Depth_Fail = 4,
}
Base_Material3d_Stencil_Compare :: enum int {
    Stencil_Compare_Always = 0,
    Stencil_Compare_Less = 1,
    Stencil_Compare_Equal = 2,
    Stencil_Compare_Less_Or_Equal = 3,
    Stencil_Compare_Greater = 4,
    Stencil_Compare_Not_Equal = 5,
    Stencil_Compare_Greater_Or_Equal = 6,
}



base_material3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

base_material3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_base_material3d :: proc "contextless" () -> Base_Material3d {
    return cast(Base_Material3d)__bindgen_gde.classdb_construct_object(base_material3d_name_ref())
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

base_material3d_set_albedo :: proc "contextless" (
    self: Base_Material3d,
    albedo_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_albedo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    albedo_ := albedo_
    args := []__bindgen_gde.TypePtr {
        &albedo_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_albedo :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_albedo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_transparency :: proc "contextless" (
    self: Base_Material3d,
    transparency_: Base_Material3d_Transparency,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transparency", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3435651667)
    }
    self := self
    transparency_ := transparency_
    args := []__bindgen_gde.TypePtr {
        &transparency_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_transparency :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Transparency) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transparency", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 990903061)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_alpha_antialiasing :: proc "contextless" (
    self: Base_Material3d,
    alpha_aa_: Base_Material3d_Alpha_Anti_Aliasing,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alpha_antialiasing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3212649852)
    }
    self := self
    alpha_aa_ := alpha_aa_
    args := []__bindgen_gde.TypePtr {
        &alpha_aa_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_alpha_antialiasing :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Alpha_Anti_Aliasing) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alpha_antialiasing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2889939400)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_alpha_antialiasing_edge :: proc "contextless" (
    self: Base_Material3d,
    edge_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alpha_antialiasing_edge", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    edge_ := edge_
    args := []__bindgen_gde.TypePtr {
        &edge_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_alpha_antialiasing_edge :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alpha_antialiasing_edge", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_shading_mode :: proc "contextless" (
    self: Base_Material3d,
    shading_mode_: Base_Material3d_Shading_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shading_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3368750322)
    }
    self := self
    shading_mode_ := shading_mode_
    args := []__bindgen_gde.TypePtr {
        &shading_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_shading_mode :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Shading_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shading_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2132070559)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_specular :: proc "contextless" (
    self: Base_Material3d,
    specular_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_specular", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    specular_ := specular_
    args := []__bindgen_gde.TypePtr {
        &specular_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_specular :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_specular", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_metallic :: proc "contextless" (
    self: Base_Material3d,
    metallic_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_metallic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    metallic_ := metallic_
    args := []__bindgen_gde.TypePtr {
        &metallic_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_metallic :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_metallic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_roughness :: proc "contextless" (
    self: Base_Material3d,
    roughness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_roughness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    roughness_ := roughness_
    args := []__bindgen_gde.TypePtr {
        &roughness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_roughness :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_roughness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_emission :: proc "contextless" (
    self: Base_Material3d,
    emission_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    emission_ := emission_
    args := []__bindgen_gde.TypePtr {
        &emission_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_emission :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_emission_energy_multiplier :: proc "contextless" (
    self: Base_Material3d,
    emission_energy_multiplier_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_energy_multiplier", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    emission_energy_multiplier_ := emission_energy_multiplier_
    args := []__bindgen_gde.TypePtr {
        &emission_energy_multiplier_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_emission_energy_multiplier :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_energy_multiplier", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_emission_intensity :: proc "contextless" (
    self: Base_Material3d,
    emission_energy_multiplier_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_intensity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    emission_energy_multiplier_ := emission_energy_multiplier_
    args := []__bindgen_gde.TypePtr {
        &emission_energy_multiplier_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_emission_intensity :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_intensity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_normal_scale :: proc "contextless" (
    self: Base_Material3d,
    normal_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_normal_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    normal_scale_ := normal_scale_
    args := []__bindgen_gde.TypePtr {
        &normal_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_normal_scale :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_normal_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_rim :: proc "contextless" (
    self: Base_Material3d,
    rim_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rim", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    rim_ := rim_
    args := []__bindgen_gde.TypePtr {
        &rim_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_rim :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rim", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_rim_tint :: proc "contextless" (
    self: Base_Material3d,
    rim_tint_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rim_tint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    rim_tint_ := rim_tint_
    args := []__bindgen_gde.TypePtr {
        &rim_tint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_rim_tint :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rim_tint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_clearcoat :: proc "contextless" (
    self: Base_Material3d,
    clearcoat_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_clearcoat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    clearcoat_ := clearcoat_
    args := []__bindgen_gde.TypePtr {
        &clearcoat_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_clearcoat :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_clearcoat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_clearcoat_roughness :: proc "contextless" (
    self: Base_Material3d,
    clearcoat_roughness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_clearcoat_roughness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    clearcoat_roughness_ := clearcoat_roughness_
    args := []__bindgen_gde.TypePtr {
        &clearcoat_roughness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_clearcoat_roughness :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_clearcoat_roughness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_anisotropy :: proc "contextless" (
    self: Base_Material3d,
    anisotropy_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_anisotropy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    anisotropy_ := anisotropy_
    args := []__bindgen_gde.TypePtr {
        &anisotropy_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_anisotropy :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_anisotropy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_heightmap_scale :: proc "contextless" (
    self: Base_Material3d,
    heightmap_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_heightmap_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    heightmap_scale_ := heightmap_scale_
    args := []__bindgen_gde.TypePtr {
        &heightmap_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_heightmap_scale :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_heightmap_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_subsurface_scattering_strength :: proc "contextless" (
    self: Base_Material3d,
    strength_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_subsurface_scattering_strength", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    strength_ := strength_
    args := []__bindgen_gde.TypePtr {
        &strength_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_subsurface_scattering_strength :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_subsurface_scattering_strength", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_transmittance_color :: proc "contextless" (
    self: Base_Material3d,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transmittance_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_transmittance_color :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transmittance_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_transmittance_depth :: proc "contextless" (
    self: Base_Material3d,
    depth_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transmittance_depth", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    depth_ := depth_
    args := []__bindgen_gde.TypePtr {
        &depth_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_transmittance_depth :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transmittance_depth", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_transmittance_boost :: proc "contextless" (
    self: Base_Material3d,
    boost_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transmittance_boost", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    boost_ := boost_
    args := []__bindgen_gde.TypePtr {
        &boost_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_transmittance_boost :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transmittance_boost", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_backlight :: proc "contextless" (
    self: Base_Material3d,
    backlight_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_backlight", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    backlight_ := backlight_
    args := []__bindgen_gde.TypePtr {
        &backlight_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_backlight :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_backlight", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_refraction :: proc "contextless" (
    self: Base_Material3d,
    refraction_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_refraction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    refraction_ := refraction_
    args := []__bindgen_gde.TypePtr {
        &refraction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_refraction :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_refraction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_point_size :: proc "contextless" (
    self: Base_Material3d,
    point_size_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_point_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    point_size_ := point_size_
    args := []__bindgen_gde.TypePtr {
        &point_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_point_size :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_detail_uv :: proc "contextless" (
    self: Base_Material3d,
    detail_uv_: Base_Material3d_Detail_Uv,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_detail_uv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 456801921)
    }
    self := self
    detail_uv_ := detail_uv_
    args := []__bindgen_gde.TypePtr {
        &detail_uv_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_detail_uv :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Detail_Uv) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_detail_uv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2306920512)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_blend_mode :: proc "contextless" (
    self: Base_Material3d,
    blend_mode_: Base_Material3d_Blend_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_blend_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2830186259)
    }
    self := self
    blend_mode_ := blend_mode_
    args := []__bindgen_gde.TypePtr {
        &blend_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_blend_mode :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Blend_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_blend_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4022690962)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_depth_draw_mode :: proc "contextless" (
    self: Base_Material3d,
    depth_draw_mode_: Base_Material3d_Depth_Draw_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_depth_draw_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1456584748)
    }
    self := self
    depth_draw_mode_ := depth_draw_mode_
    args := []__bindgen_gde.TypePtr {
        &depth_draw_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_depth_draw_mode :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Depth_Draw_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_depth_draw_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2578197639)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_depth_test :: proc "contextless" (
    self: Base_Material3d,
    depth_test_: Base_Material3d_Depth_Test,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_depth_test", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3918692338)
    }
    self := self
    depth_test_ := depth_test_
    args := []__bindgen_gde.TypePtr {
        &depth_test_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_depth_test :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Depth_Test) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_depth_test", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3434785811)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_cull_mode :: proc "contextless" (
    self: Base_Material3d,
    cull_mode_: Base_Material3d_Cull_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cull_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2338909218)
    }
    self := self
    cull_mode_ := cull_mode_
    args := []__bindgen_gde.TypePtr {
        &cull_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_cull_mode :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Cull_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cull_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1941499586)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_diffuse_mode :: proc "contextless" (
    self: Base_Material3d,
    diffuse_mode_: Base_Material3d_Diffuse_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_diffuse_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1045299638)
    }
    self := self
    diffuse_mode_ := diffuse_mode_
    args := []__bindgen_gde.TypePtr {
        &diffuse_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_diffuse_mode :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Diffuse_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_diffuse_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3973617136)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_specular_mode :: proc "contextless" (
    self: Base_Material3d,
    specular_mode_: Base_Material3d_Specular_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_specular_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 584737147)
    }
    self := self
    specular_mode_ := specular_mode_
    args := []__bindgen_gde.TypePtr {
        &specular_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_specular_mode :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Specular_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_specular_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2569953298)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_flag :: proc "contextless" (
    self: Base_Material3d,
    flag_: Base_Material3d_Flags,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3070159527)
    }
    self := self
    flag_ := flag_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &flag_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_flag :: proc "contextless" (
    self: Base_Material3d,
    flag_: Base_Material3d_Flags,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410065)
    }
    self := self
    flag_ := flag_
    args := []__bindgen_gde.TypePtr {
        &flag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_texture_filter :: proc "contextless" (
    self: Base_Material3d,
    mode_: Base_Material3d_Texture_Filter,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 22904437)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_texture_filter :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Texture_Filter) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3289213076)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_feature :: proc "contextless" (
    self: Base_Material3d,
    feature_: Base_Material3d_Feature,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_feature", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2819288693)
    }
    self := self
    feature_ := feature_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &feature_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_feature :: proc "contextless" (
    self: Base_Material3d,
    feature_: Base_Material3d_Feature,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_feature", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1965241794)
    }
    self := self
    feature_ := feature_
    args := []__bindgen_gde.TypePtr {
        &feature_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_texture :: proc "contextless" (
    self: Base_Material3d,
    param_: Base_Material3d_Texture_Param,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 464208135)
    }
    self := self
    param_ := param_
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &param_,
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_texture :: proc "contextless" (
    self: Base_Material3d,
    param_: Base_Material3d_Texture_Param,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 329605813)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_detail_blend_mode :: proc "contextless" (
    self: Base_Material3d,
    detail_blend_mode_: Base_Material3d_Blend_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_detail_blend_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2830186259)
    }
    self := self
    detail_blend_mode_ := detail_blend_mode_
    args := []__bindgen_gde.TypePtr {
        &detail_blend_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_detail_blend_mode :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Blend_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_detail_blend_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4022690962)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_uv1_scale :: proc "contextless" (
    self: Base_Material3d,
    scale_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_uv1_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_uv1_scale :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_uv1_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_uv1_offset :: proc "contextless" (
    self: Base_Material3d,
    offset_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_uv1_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_uv1_offset :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_uv1_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_uv1_triplanar_blend_sharpness :: proc "contextless" (
    self: Base_Material3d,
    sharpness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_uv1_triplanar_blend_sharpness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    sharpness_ := sharpness_
    args := []__bindgen_gde.TypePtr {
        &sharpness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_uv1_triplanar_blend_sharpness :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_uv1_triplanar_blend_sharpness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_uv2_scale :: proc "contextless" (
    self: Base_Material3d,
    scale_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_uv2_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_uv2_scale :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_uv2_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_uv2_offset :: proc "contextless" (
    self: Base_Material3d,
    offset_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_uv2_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_uv2_offset :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_uv2_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_uv2_triplanar_blend_sharpness :: proc "contextless" (
    self: Base_Material3d,
    sharpness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_uv2_triplanar_blend_sharpness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    sharpness_ := sharpness_
    args := []__bindgen_gde.TypePtr {
        &sharpness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_uv2_triplanar_blend_sharpness :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_uv2_triplanar_blend_sharpness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_billboard_mode :: proc "contextless" (
    self: Base_Material3d,
    mode_: Base_Material3d_Billboard_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_billboard_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4202036497)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_billboard_mode :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Billboard_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_billboard_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1283840139)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_particles_anim_h_frames :: proc "contextless" (
    self: Base_Material3d,
    frames_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_particles_anim_h_frames", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    frames_ := frames_
    args := []__bindgen_gde.TypePtr {
        &frames_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_particles_anim_h_frames :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_particles_anim_h_frames", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_particles_anim_v_frames :: proc "contextless" (
    self: Base_Material3d,
    frames_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_particles_anim_v_frames", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    frames_ := frames_
    args := []__bindgen_gde.TypePtr {
        &frames_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_particles_anim_v_frames :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_particles_anim_v_frames", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_particles_anim_loop :: proc "contextless" (
    self: Base_Material3d,
    loop_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_particles_anim_loop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    loop_ := loop_
    args := []__bindgen_gde.TypePtr {
        &loop_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_particles_anim_loop :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_particles_anim_loop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_heightmap_deep_parallax :: proc "contextless" (
    self: Base_Material3d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_heightmap_deep_parallax", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_is_heightmap_deep_parallax_enabled :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_heightmap_deep_parallax_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_heightmap_deep_parallax_min_layers :: proc "contextless" (
    self: Base_Material3d,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_heightmap_deep_parallax_min_layers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_heightmap_deep_parallax_min_layers :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_heightmap_deep_parallax_min_layers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_heightmap_deep_parallax_max_layers :: proc "contextless" (
    self: Base_Material3d,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_heightmap_deep_parallax_max_layers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_heightmap_deep_parallax_max_layers :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_heightmap_deep_parallax_max_layers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_heightmap_deep_parallax_flip_tangent :: proc "contextless" (
    self: Base_Material3d,
    flip_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_heightmap_deep_parallax_flip_tangent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    flip_ := flip_
    args := []__bindgen_gde.TypePtr {
        &flip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_heightmap_deep_parallax_flip_tangent :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_heightmap_deep_parallax_flip_tangent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_heightmap_deep_parallax_flip_binormal :: proc "contextless" (
    self: Base_Material3d,
    flip_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_heightmap_deep_parallax_flip_binormal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    flip_ := flip_
    args := []__bindgen_gde.TypePtr {
        &flip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_heightmap_deep_parallax_flip_binormal :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_heightmap_deep_parallax_flip_binormal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_grow :: proc "contextless" (
    self: Base_Material3d,
    amount_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_grow", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_grow :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_grow", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_emission_operator :: proc "contextless" (
    self: Base_Material3d,
    operator_: Base_Material3d_Emission_Operator,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_operator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3825128922)
    }
    self := self
    operator_ := operator_
    args := []__bindgen_gde.TypePtr {
        &operator_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_emission_operator :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Emission_Operator) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_operator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 974205018)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_ao_light_affect :: proc "contextless" (
    self: Base_Material3d,
    amount_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_ao_light_affect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_ao_light_affect :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_ao_light_affect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_alpha_scissor_threshold :: proc "contextless" (
    self: Base_Material3d,
    threshold_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alpha_scissor_threshold", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    threshold_ := threshold_
    args := []__bindgen_gde.TypePtr {
        &threshold_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_alpha_scissor_threshold :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alpha_scissor_threshold", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_alpha_hash_scale :: proc "contextless" (
    self: Base_Material3d,
    threshold_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alpha_hash_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    threshold_ := threshold_
    args := []__bindgen_gde.TypePtr {
        &threshold_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_alpha_hash_scale :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alpha_hash_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_grow_enabled :: proc "contextless" (
    self: Base_Material3d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_grow_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_is_grow_enabled :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_grow_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_metallic_texture_channel :: proc "contextless" (
    self: Base_Material3d,
    channel_: Base_Material3d_Texture_Channel,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_metallic_texture_channel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 744167988)
    }
    self := self
    channel_ := channel_
    args := []__bindgen_gde.TypePtr {
        &channel_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_metallic_texture_channel :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Texture_Channel) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_metallic_texture_channel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 568133867)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_roughness_texture_channel :: proc "contextless" (
    self: Base_Material3d,
    channel_: Base_Material3d_Texture_Channel,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_roughness_texture_channel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 744167988)
    }
    self := self
    channel_ := channel_
    args := []__bindgen_gde.TypePtr {
        &channel_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_roughness_texture_channel :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Texture_Channel) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_roughness_texture_channel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 568133867)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_ao_texture_channel :: proc "contextless" (
    self: Base_Material3d,
    channel_: Base_Material3d_Texture_Channel,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_ao_texture_channel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 744167988)
    }
    self := self
    channel_ := channel_
    args := []__bindgen_gde.TypePtr {
        &channel_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_ao_texture_channel :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Texture_Channel) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_ao_texture_channel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 568133867)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_refraction_texture_channel :: proc "contextless" (
    self: Base_Material3d,
    channel_: Base_Material3d_Texture_Channel,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_refraction_texture_channel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 744167988)
    }
    self := self
    channel_ := channel_
    args := []__bindgen_gde.TypePtr {
        &channel_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_refraction_texture_channel :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Texture_Channel) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_refraction_texture_channel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 568133867)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_proximity_fade_enabled :: proc "contextless" (
    self: Base_Material3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_proximity_fade_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_is_proximity_fade_enabled :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_proximity_fade_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_proximity_fade_distance :: proc "contextless" (
    self: Base_Material3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_proximity_fade_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_proximity_fade_distance :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_proximity_fade_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_msdf_pixel_range :: proc "contextless" (
    self: Base_Material3d,
    range_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_msdf_pixel_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    range_ := range_
    args := []__bindgen_gde.TypePtr {
        &range_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_msdf_pixel_range :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_msdf_pixel_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_msdf_outline_size :: proc "contextless" (
    self: Base_Material3d,
    size_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_msdf_outline_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_msdf_outline_size :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_msdf_outline_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_distance_fade :: proc "contextless" (
    self: Base_Material3d,
    mode_: Base_Material3d_Distance_Fade_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_distance_fade", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1379478617)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_distance_fade :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Distance_Fade_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_distance_fade", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2694575734)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_distance_fade_max_distance :: proc "contextless" (
    self: Base_Material3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_distance_fade_max_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_distance_fade_max_distance :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_distance_fade_max_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_distance_fade_min_distance :: proc "contextless" (
    self: Base_Material3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_distance_fade_min_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_distance_fade_min_distance :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_distance_fade_min_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_z_clip_scale :: proc "contextless" (
    self: Base_Material3d,
    scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_z_clip_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_z_clip_scale :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_z_clip_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_fov_override :: proc "contextless" (
    self: Base_Material3d,
    scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fov_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_fov_override :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fov_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_stencil_mode :: proc "contextless" (
    self: Base_Material3d,
    stencil_mode_: Base_Material3d_Stencil_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stencil_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2272367200)
    }
    self := self
    stencil_mode_ := stencil_mode_
    args := []__bindgen_gde.TypePtr {
        &stencil_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_stencil_mode :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Stencil_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stencil_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2908443456)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_stencil_flags :: proc "contextless" (
    self: Base_Material3d,
    stencil_flags_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stencil_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    stencil_flags_ := stencil_flags_
    args := []__bindgen_gde.TypePtr {
        &stencil_flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_stencil_flags :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stencil_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_stencil_compare :: proc "contextless" (
    self: Base_Material3d,
    stencil_compare_: Base_Material3d_Stencil_Compare,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stencil_compare", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3741726481)
    }
    self := self
    stencil_compare_ := stencil_compare_
    args := []__bindgen_gde.TypePtr {
        &stencil_compare_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_stencil_compare :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Base_Material3d_Stencil_Compare) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stencil_compare", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2824600492)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_stencil_reference :: proc "contextless" (
    self: Base_Material3d,
    stencil_reference_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stencil_reference", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    stencil_reference_ := stencil_reference_
    args := []__bindgen_gde.TypePtr {
        &stencil_reference_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_stencil_reference :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stencil_reference", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_stencil_effect_color :: proc "contextless" (
    self: Base_Material3d,
    stencil_color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stencil_effect_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    stencil_color_ := stencil_color_
    args := []__bindgen_gde.TypePtr {
        &stencil_color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_stencil_effect_color :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stencil_effect_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

base_material3d_set_stencil_effect_outline_thickness :: proc "contextless" (
    self: Base_Material3d,
    stencil_outline_thickness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stencil_effect_outline_thickness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    stencil_outline_thickness_ := stencil_outline_thickness_
    args := []__bindgen_gde.TypePtr {
        &stencil_outline_thickness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

base_material3d_get_stencil_effect_outline_thickness :: proc "contextless" (
    self: Base_Material3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stencil_effect_outline_thickness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
base_material3d_get_alpha_antialiasing_mode :: proc "contextless" (self: Base_Material3d) -> Base_Material3d_Alpha_Anti_Aliasing {
    return base_material3d_get_alpha_antialiasing(self)
}
base_material3d_set_alpha_antialiasing_mode :: proc "contextless" (self: Base_Material3d, value: Base_Material3d_Alpha_Anti_Aliasing) {
    base_material3d_set_alpha_antialiasing(self, value)
}
base_material3d_get_no_depth_test :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(0))
}
base_material3d_set_no_depth_test :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(0), value)
}
base_material3d_get_disable_ambient_light :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(14))
}
base_material3d_set_disable_ambient_light :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(14), value)
}
base_material3d_get_disable_fog :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(21))
}
base_material3d_set_disable_fog :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(21), value)
}
base_material3d_get_disable_specular_occlusion :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(22))
}
base_material3d_set_disable_specular_occlusion :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(22), value)
}
base_material3d_get_vertex_color_use_as_albedo :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(1))
}
base_material3d_set_vertex_color_use_as_albedo :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(1), value)
}
base_material3d_get_vertex_color_is_srgb :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(2))
}
base_material3d_set_vertex_color_is_srgb :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(2), value)
}
base_material3d_get_albedo_color :: proc "contextless" (self: Base_Material3d) -> Color {
    return base_material3d_get_albedo(self)
}
base_material3d_set_albedo_color :: proc "contextless" (self: Base_Material3d, value: Color) {
    base_material3d_set_albedo(self, value)
}
base_material3d_get_albedo_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(0))
}
base_material3d_set_albedo_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(0), value)
}
base_material3d_get_albedo_texture_force_srgb :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(12))
}
base_material3d_set_albedo_texture_force_srgb :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(12), value)
}
base_material3d_get_albedo_texture_msdf :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(20))
}
base_material3d_set_albedo_texture_msdf :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(20), value)
}
base_material3d_get_orm_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(17))
}
base_material3d_set_orm_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(17), value)
}
base_material3d_get_metallic_specular :: proc "contextless" (self: Base_Material3d) -> f64 {
    return base_material3d_get_specular(self)
}
base_material3d_set_metallic_specular :: proc "contextless" (self: Base_Material3d, value: f64) {
    base_material3d_set_specular(self, value)
}
base_material3d_get_metallic_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(1))
}
base_material3d_set_metallic_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(1), value)
}
base_material3d_get_roughness_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(2))
}
base_material3d_set_roughness_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(2), value)
}
base_material3d_get_emission_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_feature(self, Base_Material3d_Feature(0))
}
base_material3d_set_emission_enabled :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_feature(self, Base_Material3d_Feature(0), value)
}
base_material3d_get_emission_on_uv2 :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(11))
}
base_material3d_set_emission_on_uv2 :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(11), value)
}
base_material3d_get_emission_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(3))
}
base_material3d_set_emission_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(3), value)
}
base_material3d_get_normal_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_feature(self, Base_Material3d_Feature(1))
}
base_material3d_set_normal_enabled :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_feature(self, Base_Material3d_Feature(1), value)
}
base_material3d_get_normal_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(4))
}
base_material3d_set_normal_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(4), value)
}
base_material3d_get_bent_normal_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_feature(self, Base_Material3d_Feature(12))
}
base_material3d_set_bent_normal_enabled :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_feature(self, Base_Material3d_Feature(12), value)
}
base_material3d_get_bent_normal_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(18))
}
base_material3d_set_bent_normal_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(18), value)
}
base_material3d_get_rim_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_feature(self, Base_Material3d_Feature(2))
}
base_material3d_set_rim_enabled :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_feature(self, Base_Material3d_Feature(2), value)
}
base_material3d_get_rim_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(5))
}
base_material3d_set_rim_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(5), value)
}
base_material3d_get_clearcoat_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_feature(self, Base_Material3d_Feature(3))
}
base_material3d_set_clearcoat_enabled :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_feature(self, Base_Material3d_Feature(3), value)
}
base_material3d_get_clearcoat_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(6))
}
base_material3d_set_clearcoat_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(6), value)
}
base_material3d_get_anisotropy_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_feature(self, Base_Material3d_Feature(4))
}
base_material3d_set_anisotropy_enabled :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_feature(self, Base_Material3d_Feature(4), value)
}
base_material3d_get_anisotropy_flowmap :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(7))
}
base_material3d_set_anisotropy_flowmap :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(7), value)
}
base_material3d_get_ao_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_feature(self, Base_Material3d_Feature(5))
}
base_material3d_set_ao_enabled :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_feature(self, Base_Material3d_Feature(5), value)
}
base_material3d_get_ao_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(8))
}
base_material3d_set_ao_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(8), value)
}
base_material3d_get_ao_on_uv2 :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(10))
}
base_material3d_set_ao_on_uv2 :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(10), value)
}
base_material3d_get_heightmap_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_feature(self, Base_Material3d_Feature(6))
}
base_material3d_set_heightmap_enabled :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_feature(self, Base_Material3d_Feature(6), value)
}
base_material3d_get_heightmap_deep_parallax :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_is_heightmap_deep_parallax_enabled(self)
}
base_material3d_get_heightmap_min_layers :: proc "contextless" (self: Base_Material3d) -> i32 {
    return base_material3d_get_heightmap_deep_parallax_min_layers(self)
}
base_material3d_set_heightmap_min_layers :: proc "contextless" (self: Base_Material3d, value: Int) {
    base_material3d_set_heightmap_deep_parallax_min_layers(self, value)
}
base_material3d_get_heightmap_max_layers :: proc "contextless" (self: Base_Material3d) -> i32 {
    return base_material3d_get_heightmap_deep_parallax_max_layers(self)
}
base_material3d_set_heightmap_max_layers :: proc "contextless" (self: Base_Material3d, value: Int) {
    base_material3d_set_heightmap_deep_parallax_max_layers(self, value)
}
base_material3d_get_heightmap_flip_tangent :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_heightmap_deep_parallax_flip_tangent(self)
}
base_material3d_set_heightmap_flip_tangent :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_heightmap_deep_parallax_flip_tangent(self, value)
}
base_material3d_get_heightmap_flip_binormal :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_heightmap_deep_parallax_flip_binormal(self)
}
base_material3d_set_heightmap_flip_binormal :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_heightmap_deep_parallax_flip_binormal(self, value)
}
base_material3d_get_heightmap_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(9))
}
base_material3d_set_heightmap_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(9), value)
}
base_material3d_get_heightmap_flip_texture :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(17))
}
base_material3d_set_heightmap_flip_texture :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(17), value)
}
base_material3d_get_subsurf_scatter_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_feature(self, Base_Material3d_Feature(7))
}
base_material3d_set_subsurf_scatter_enabled :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_feature(self, Base_Material3d_Feature(7), value)
}
base_material3d_get_subsurf_scatter_strength :: proc "contextless" (self: Base_Material3d) -> f64 {
    return base_material3d_get_subsurface_scattering_strength(self)
}
base_material3d_set_subsurf_scatter_strength :: proc "contextless" (self: Base_Material3d, value: f64) {
    base_material3d_set_subsurface_scattering_strength(self, value)
}
base_material3d_get_subsurf_scatter_skin_mode :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(18))
}
base_material3d_set_subsurf_scatter_skin_mode :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(18), value)
}
base_material3d_get_subsurf_scatter_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(10))
}
base_material3d_set_subsurf_scatter_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(10), value)
}
base_material3d_get_subsurf_scatter_transmittance_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_feature(self, Base_Material3d_Feature(8))
}
base_material3d_set_subsurf_scatter_transmittance_enabled :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_feature(self, Base_Material3d_Feature(8), value)
}
base_material3d_get_subsurf_scatter_transmittance_color :: proc "contextless" (self: Base_Material3d) -> Color {
    return base_material3d_get_transmittance_color(self)
}
base_material3d_set_subsurf_scatter_transmittance_color :: proc "contextless" (self: Base_Material3d, value: Color) {
    base_material3d_set_transmittance_color(self, value)
}
base_material3d_get_subsurf_scatter_transmittance_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(11))
}
base_material3d_set_subsurf_scatter_transmittance_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(11), value)
}
base_material3d_get_subsurf_scatter_transmittance_depth :: proc "contextless" (self: Base_Material3d) -> f64 {
    return base_material3d_get_transmittance_depth(self)
}
base_material3d_set_subsurf_scatter_transmittance_depth :: proc "contextless" (self: Base_Material3d, value: f64) {
    base_material3d_set_transmittance_depth(self, value)
}
base_material3d_get_subsurf_scatter_transmittance_boost :: proc "contextless" (self: Base_Material3d) -> f64 {
    return base_material3d_get_transmittance_boost(self)
}
base_material3d_set_subsurf_scatter_transmittance_boost :: proc "contextless" (self: Base_Material3d, value: f64) {
    base_material3d_set_transmittance_boost(self, value)
}
base_material3d_get_backlight_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_feature(self, Base_Material3d_Feature(9))
}
base_material3d_set_backlight_enabled :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_feature(self, Base_Material3d_Feature(9), value)
}
base_material3d_get_backlight_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(12))
}
base_material3d_set_backlight_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(12), value)
}
base_material3d_get_refraction_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_feature(self, Base_Material3d_Feature(10))
}
base_material3d_set_refraction_enabled :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_feature(self, Base_Material3d_Feature(10), value)
}
base_material3d_get_refraction_scale :: proc "contextless" (self: Base_Material3d) -> f64 {
    return base_material3d_get_refraction(self)
}
base_material3d_set_refraction_scale :: proc "contextless" (self: Base_Material3d, value: f64) {
    base_material3d_set_refraction(self, value)
}
base_material3d_get_refraction_texture :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(13))
}
base_material3d_set_refraction_texture :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(13), value)
}
base_material3d_get_detail_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_feature(self, Base_Material3d_Feature(11))
}
base_material3d_set_detail_enabled :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_feature(self, Base_Material3d_Feature(11), value)
}
base_material3d_get_detail_mask :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(14))
}
base_material3d_set_detail_mask :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(14), value)
}
base_material3d_get_detail_uv_layer :: proc "contextless" (self: Base_Material3d) -> Base_Material3d_Detail_Uv {
    return base_material3d_get_detail_uv(self)
}
base_material3d_set_detail_uv_layer :: proc "contextless" (self: Base_Material3d, value: Base_Material3d_Detail_Uv) {
    base_material3d_set_detail_uv(self, value)
}
base_material3d_get_detail_albedo :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(15))
}
base_material3d_set_detail_albedo :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(15), value)
}
base_material3d_get_detail_normal :: proc "contextless" (self: Base_Material3d) -> Texture2d {
    return base_material3d_get_texture(self, Base_Material3d_Texture_Param(16))
}
base_material3d_set_detail_normal :: proc "contextless" (self: Base_Material3d, value: Texture2d) {
    base_material3d_set_texture(self, Base_Material3d_Texture_Param(16), value)
}
base_material3d_get_uv1_triplanar :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(6))
}
base_material3d_set_uv1_triplanar :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(6), value)
}
base_material3d_get_uv1_triplanar_sharpness :: proc "contextless" (self: Base_Material3d) -> f64 {
    return base_material3d_get_uv1_triplanar_blend_sharpness(self)
}
base_material3d_set_uv1_triplanar_sharpness :: proc "contextless" (self: Base_Material3d, value: f64) {
    base_material3d_set_uv1_triplanar_blend_sharpness(self, value)
}
base_material3d_get_uv1_world_triplanar :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(8))
}
base_material3d_set_uv1_world_triplanar :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(8), value)
}
base_material3d_get_uv2_triplanar :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(7))
}
base_material3d_set_uv2_triplanar :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(7), value)
}
base_material3d_get_uv2_triplanar_sharpness :: proc "contextless" (self: Base_Material3d) -> f64 {
    return base_material3d_get_uv2_triplanar_blend_sharpness(self)
}
base_material3d_set_uv2_triplanar_sharpness :: proc "contextless" (self: Base_Material3d, value: f64) {
    base_material3d_set_uv2_triplanar_blend_sharpness(self, value)
}
base_material3d_get_uv2_world_triplanar :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(9))
}
base_material3d_set_uv2_world_triplanar :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(9), value)
}
base_material3d_get_texture_repeat :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(16))
}
base_material3d_set_texture_repeat :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(16), value)
}
base_material3d_get_disable_receive_shadows :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(13))
}
base_material3d_set_disable_receive_shadows :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(13), value)
}
base_material3d_get_shadow_to_opacity :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(15))
}
base_material3d_set_shadow_to_opacity :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(15), value)
}
base_material3d_get_billboard_keep_scale :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(5))
}
base_material3d_set_billboard_keep_scale :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(5), value)
}
base_material3d_get_grow_amount :: proc "contextless" (self: Base_Material3d) -> f64 {
    return base_material3d_get_grow(self)
}
base_material3d_set_grow_amount :: proc "contextless" (self: Base_Material3d, value: f64) {
    base_material3d_set_grow(self, value)
}
base_material3d_get_fixed_size :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(4))
}
base_material3d_set_fixed_size :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(4), value)
}
base_material3d_get_use_point_size :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(3))
}
base_material3d_set_use_point_size :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(3), value)
}
base_material3d_get_use_particle_trails :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(19))
}
base_material3d_set_use_particle_trails :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(19), value)
}
base_material3d_get_use_z_clip_scale :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(23))
}
base_material3d_set_use_z_clip_scale :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(23), value)
}
base_material3d_get_use_fov_override :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_get_flag(self, Base_Material3d_Flags(24))
}
base_material3d_set_use_fov_override :: proc "contextless" (self: Base_Material3d, value: Bool) {
    base_material3d_set_flag(self, Base_Material3d_Flags(24), value)
}
base_material3d_get_proximity_fade_enabled :: proc "contextless" (self: Base_Material3d) -> Bool {
    return base_material3d_is_proximity_fade_enabled(self)
}
base_material3d_get_distance_fade_mode :: proc "contextless" (self: Base_Material3d) -> Base_Material3d_Distance_Fade_Mode {
    return base_material3d_get_distance_fade(self)
}
base_material3d_set_distance_fade_mode :: proc "contextless" (self: Base_Material3d, value: Base_Material3d_Distance_Fade_Mode) {
    base_material3d_set_distance_fade(self, value)
}
base_material3d_get_stencil_color :: proc "contextless" (self: Base_Material3d) -> Color {
    return base_material3d_get_stencil_effect_color(self)
}
base_material3d_set_stencil_color :: proc "contextless" (self: Base_Material3d, value: Color) {
    base_material3d_set_stencil_effect_color(self, value)
}
base_material3d_get_stencil_outline_thickness :: proc "contextless" (self: Base_Material3d) -> f64 {
    return base_material3d_get_stencil_effect_outline_thickness(self)
}
base_material3d_set_stencil_outline_thickness :: proc "contextless" (self: Base_Material3d, value: f64) {
    base_material3d_set_stencil_effect_outline_thickness(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
base_material3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("BaseMaterial3D", true)
}

@(private = "file")
__class_name: String_Name