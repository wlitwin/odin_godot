package godot

import __bindgen_gde "godot:gdext"

Geometry_Instance3d_Constants :: enum {
}
Geometry_Instance3d_Shadow_Casting_Setting :: enum int {
    Shadow_Casting_Setting_Off = 0,
    Shadow_Casting_Setting_On = 1,
    Shadow_Casting_Setting_Double_Sided = 2,
    Shadow_Casting_Setting_Shadows_Only = 3,
}
Geometry_Instance3dgi_Mode :: enum int {
    Gi_Mode_Disabled = 0,
    Gi_Mode_Static = 1,
    Gi_Mode_Dynamic = 2,
}
Geometry_Instance3d_Lightmap_Scale :: enum int {
    Lightmap_Scale_1x = 0,
    Lightmap_Scale_2x = 1,
    Lightmap_Scale_4x = 2,
    Lightmap_Scale_8x = 3,
    Lightmap_Scale_Max = 4,
}
Geometry_Instance3d_Visibility_Range_Fade_Mode :: enum int {
    Visibility_Range_Fade_Disabled = 0,
    Visibility_Range_Fade_Self = 1,
    Visibility_Range_Fade_Dependencies = 2,
}



geometry_instance3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

geometry_instance3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_geometry_instance3d :: proc "contextless" () -> Geometry_Instance3d {
    return cast(Geometry_Instance3d)__bindgen_gde.classdb_construct_object(geometry_instance3d_name_ref())
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

geometry_instance3d_set_material_override :: proc "contextless" (
    self: Geometry_Instance3d,
    material_: Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_material_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2757459619)
    }
    self := self
    material_ := material_
    args := []__bindgen_gde.TypePtr {
        &material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_material_override :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: Material) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_material_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 5934680)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_material_overlay :: proc "contextless" (
    self: Geometry_Instance3d,
    material_: Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_material_overlay", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2757459619)
    }
    self := self
    material_ := material_
    args := []__bindgen_gde.TypePtr {
        &material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_material_overlay :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: Material) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_material_overlay", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 5934680)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_cast_shadows_setting :: proc "contextless" (
    self: Geometry_Instance3d,
    shadow_casting_setting_: Geometry_Instance3d_Shadow_Casting_Setting,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cast_shadows_setting", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 856677339)
    }
    self := self
    shadow_casting_setting_ := shadow_casting_setting_
    args := []__bindgen_gde.TypePtr {
        &shadow_casting_setting_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_cast_shadows_setting :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: Geometry_Instance3d_Shadow_Casting_Setting) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cast_shadows_setting", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3383019359)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_lod_bias :: proc "contextless" (
    self: Geometry_Instance3d,
    bias_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_lod_bias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    bias_ := bias_
    args := []__bindgen_gde.TypePtr {
        &bias_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_lod_bias :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_lod_bias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_transparency :: proc "contextless" (
    self: Geometry_Instance3d,
    transparency_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transparency", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    transparency_ := transparency_
    args := []__bindgen_gde.TypePtr {
        &transparency_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_transparency :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transparency", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_visibility_range_end_margin :: proc "contextless" (
    self: Geometry_Instance3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_range_end_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_visibility_range_end_margin :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_range_end_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_visibility_range_end :: proc "contextless" (
    self: Geometry_Instance3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_range_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_visibility_range_end :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_range_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_visibility_range_begin_margin :: proc "contextless" (
    self: Geometry_Instance3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_range_begin_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_visibility_range_begin_margin :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_range_begin_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_visibility_range_begin :: proc "contextless" (
    self: Geometry_Instance3d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_range_begin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_visibility_range_begin :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_range_begin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_visibility_range_fade_mode :: proc "contextless" (
    self: Geometry_Instance3d,
    mode_: Geometry_Instance3d_Visibility_Range_Fade_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_range_fade_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1440117808)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_visibility_range_fade_mode :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: Geometry_Instance3d_Visibility_Range_Fade_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_range_fade_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2067221882)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_instance_shader_parameter :: proc "contextless" (
    self: Geometry_Instance3d,
    name_: String_Name,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_instance_shader_parameter", true)
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

geometry_instance3d_get_instance_shader_parameter :: proc "contextless" (
    self: Geometry_Instance3d,
    name_: String_Name,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_instance_shader_parameter", true)
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

geometry_instance3d_set_extra_cull_margin :: proc "contextless" (
    self: Geometry_Instance3d,
    margin_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_extra_cull_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    margin_ := margin_
    args := []__bindgen_gde.TypePtr {
        &margin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_extra_cull_margin :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_extra_cull_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_lightmap_texel_scale :: proc "contextless" (
    self: Geometry_Instance3d,
    scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_lightmap_texel_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_lightmap_texel_scale :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_lightmap_texel_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_lightmap_scale :: proc "contextless" (
    self: Geometry_Instance3d,
    scale_: Geometry_Instance3d_Lightmap_Scale,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_lightmap_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2462696582)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_lightmap_scale :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: Geometry_Instance3d_Lightmap_Scale) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_lightmap_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 798767852)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_gi_mode :: proc "contextless" (
    self: Geometry_Instance3d,
    mode_: Geometry_Instance3dgi_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gi_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2548557163)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_gi_mode :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: Geometry_Instance3dgi_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gi_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2188566509)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_ignore_occlusion_culling :: proc "contextless" (
    self: Geometry_Instance3d,
    ignore_culling_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_ignore_occlusion_culling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    ignore_culling_ := ignore_culling_
    args := []__bindgen_gde.TypePtr {
        &ignore_culling_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_is_ignoring_occlusion_culling :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_ignoring_occlusion_culling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry_instance3d_set_custom_aabb :: proc "contextless" (
    self: Geometry_Instance3d,
    aabb_: Aabb,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_aabb", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 259215842)
    }
    self := self
    aabb_ := aabb_
    args := []__bindgen_gde.TypePtr {
        &aabb_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

geometry_instance3d_get_custom_aabb :: proc "contextless" (
    self: Geometry_Instance3d,
) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_aabb", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1068685055)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
geometry_instance3d_get_cast_shadow :: proc "contextless" (self: Geometry_Instance3d) -> Geometry_Instance3d_Shadow_Casting_Setting {
    return geometry_instance3d_get_cast_shadows_setting(self)
}
geometry_instance3d_set_cast_shadow :: proc "contextless" (self: Geometry_Instance3d, value: Geometry_Instance3d_Shadow_Casting_Setting) {
    geometry_instance3d_set_cast_shadows_setting(self, value)
}
geometry_instance3d_get_ignore_occlusion_culling :: proc "contextless" (self: Geometry_Instance3d) -> Bool {
    return geometry_instance3d_is_ignoring_occlusion_culling(self)
}
geometry_instance3d_get_gi_lightmap_texel_scale :: proc "contextless" (self: Geometry_Instance3d) -> f64 {
    return geometry_instance3d_get_lightmap_texel_scale(self)
}
geometry_instance3d_set_gi_lightmap_texel_scale :: proc "contextless" (self: Geometry_Instance3d, value: f64) {
    geometry_instance3d_set_lightmap_texel_scale(self, value)
}
geometry_instance3d_get_gi_lightmap_scale :: proc "contextless" (self: Geometry_Instance3d) -> Geometry_Instance3d_Lightmap_Scale {
    return geometry_instance3d_get_lightmap_scale(self)
}
geometry_instance3d_set_gi_lightmap_scale :: proc "contextless" (self: Geometry_Instance3d, value: Geometry_Instance3d_Lightmap_Scale) {
    geometry_instance3d_set_lightmap_scale(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
geometry_instance3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GeometryInstance3D", true)
}

@(private = "file")
__class_name: String_Name