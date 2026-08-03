package godot

import __bindgen_gde "godot:gdext"

Viewport_Constants :: enum {
}
Viewport_Positional_Shadow_Atlas_Quadrant_Subdiv :: enum int {
    Shadow_Atlas_Quadrant_Subdiv_Disabled = 0,
    Shadow_Atlas_Quadrant_Subdiv_1 = 1,
    Shadow_Atlas_Quadrant_Subdiv_4 = 2,
    Shadow_Atlas_Quadrant_Subdiv_16 = 3,
    Shadow_Atlas_Quadrant_Subdiv_64 = 4,
    Shadow_Atlas_Quadrant_Subdiv_256 = 5,
    Shadow_Atlas_Quadrant_Subdiv_1024 = 6,
    Shadow_Atlas_Quadrant_Subdiv_Max = 7,
}
Viewport_Scaling3d_Mode :: enum int {
    Scaling_3d_Mode_Bilinear = 0,
    Scaling_3d_Mode_Fsr = 1,
    Scaling_3d_Mode_Fsr2 = 2,
    Scaling_3d_Mode_Metalfx_Spatial = 3,
    Scaling_3d_Mode_Metalfx_Temporal = 4,
    Scaling_3d_Mode_Nearest = 5,
    Scaling_3d_Mode_Max = 6,
}
Viewport_Msaa :: enum int {
    Msaa_Disabled = 0,
    Msaa_2x = 1,
    Msaa_4x = 2,
    Msaa_8x = 3,
    Msaa_Max = 4,
}
Viewport_Anisotropic_Filtering :: enum int {
    Anisotropy_Disabled = 0,
    Anisotropy_2x = 1,
    Anisotropy_4x = 2,
    Anisotropy_8x = 3,
    Anisotropy_16x = 4,
    Anisotropy_Max = 5,
}
Viewport_Screen_Space_Aa :: enum int {
    Screen_Space_Aa_Disabled = 0,
    Screen_Space_Aa_Fxaa = 1,
    Screen_Space_Aa_Smaa = 2,
    Screen_Space_Aa_Max = 3,
}
Viewport_Render_Info :: enum int {
    Render_Info_Objects_In_Frame = 0,
    Render_Info_Primitives_In_Frame = 1,
    Render_Info_Draw_Calls_In_Frame = 2,
    Render_Info_Max = 3,
}
Viewport_Render_Info_Type :: enum int {
    Render_Info_Type_Visible = 0,
    Render_Info_Type_Shadow = 1,
    Render_Info_Type_Canvas = 2,
    Render_Info_Type_Max = 3,
}
Viewport_Debug_Draw :: enum int {
    Debug_Draw_Disabled = 0,
    Debug_Draw_Unshaded = 1,
    Debug_Draw_Lighting = 2,
    Debug_Draw_Overdraw = 3,
    Debug_Draw_Wireframe = 4,
    Debug_Draw_Normal_Buffer = 5,
    Debug_Draw_Voxel_Gi_Albedo = 6,
    Debug_Draw_Voxel_Gi_Lighting = 7,
    Debug_Draw_Voxel_Gi_Emission = 8,
    Debug_Draw_Shadow_Atlas = 9,
    Debug_Draw_Directional_Shadow_Atlas = 10,
    Debug_Draw_Scene_Luminance = 11,
    Debug_Draw_Ssao = 12,
    Debug_Draw_Ssil = 13,
    Debug_Draw_Pssm_Splits = 14,
    Debug_Draw_Decal_Atlas = 15,
    Debug_Draw_Sdfgi = 16,
    Debug_Draw_Sdfgi_Probes = 17,
    Debug_Draw_Gi_Buffer = 18,
    Debug_Draw_Disable_Lod = 19,
    Debug_Draw_Cluster_Omni_Lights = 20,
    Debug_Draw_Cluster_Spot_Lights = 21,
    Debug_Draw_Cluster_Decals = 22,
    Debug_Draw_Cluster_Reflection_Probes = 23,
    Debug_Draw_Occluders = 24,
    Debug_Draw_Motion_Vectors = 25,
    Debug_Draw_Internal_Buffer = 26,
    Debug_Draw_Cluster_Area_Lights = 27,
    Debug_Draw_Area_Light_Atlas = 28,
}
Viewport_Default_Canvas_Item_Texture_Filter :: enum int {
    Default_Canvas_Item_Texture_Filter_Nearest = 0,
    Default_Canvas_Item_Texture_Filter_Linear = 1,
    Default_Canvas_Item_Texture_Filter_Linear_With_Mipmaps = 2,
    Default_Canvas_Item_Texture_Filter_Nearest_With_Mipmaps = 3,
    Default_Canvas_Item_Texture_Filter_Parent_Node = 4,
    Default_Canvas_Item_Texture_Filter_Max = 5,
}
Viewport_Default_Canvas_Item_Texture_Repeat :: enum int {
    Default_Canvas_Item_Texture_Repeat_Disabled = 0,
    Default_Canvas_Item_Texture_Repeat_Enabled = 1,
    Default_Canvas_Item_Texture_Repeat_Mirror = 2,
    Default_Canvas_Item_Texture_Repeat_Parent_Node = 3,
    Default_Canvas_Item_Texture_Repeat_Max = 4,
}
Viewport_Sdf_Oversize :: enum int {
    Sdf_Oversize_100_Percent = 0,
    Sdf_Oversize_120_Percent = 1,
    Sdf_Oversize_150_Percent = 2,
    Sdf_Oversize_200_Percent = 3,
    Sdf_Oversize_Max = 4,
}
Viewport_Sdf_Scale :: enum int {
    Sdf_Scale_100_Percent = 0,
    Sdf_Scale_50_Percent = 1,
    Sdf_Scale_25_Percent = 2,
    Sdf_Scale_Max = 3,
}
Viewport_Vrs_Mode :: enum int {
    Vrs_Disabled = 0,
    Vrs_Texture = 1,
    Vrs_Xr = 2,
    Vrs_Max = 3,
}
Viewport_Vrs_Update_Mode :: enum int {
    Vrs_Update_Disabled = 0,
    Vrs_Update_Once = 1,
    Vrs_Update_Always = 2,
    Vrs_Update_Max = 3,
}



viewport_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

viewport_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_viewport :: proc "contextless" () -> Viewport {
    return cast(Viewport)__bindgen_gde.classdb_construct_object(viewport_name_ref())
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

viewport_set_world_2d :: proc "contextless" (
    self: Viewport,
    world_2d_: World2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_world_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2736080068)
    }
    self := self
    world_2d_ := world_2d_
    args := []__bindgen_gde.TypePtr {
        &world_2d_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_world_2d :: proc "contextless" (
    self: Viewport,
) -> (ret: World2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_world_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339128592)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_find_world_2d :: proc "contextless" (
    self: Viewport,
) -> (ret: World2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_world_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339128592)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_canvas_transform :: proc "contextless" (
    self: Viewport,
    xform_: Transform2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_canvas_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2761652528)
    }
    self := self
    xform_ := xform_
    args := []__bindgen_gde.TypePtr {
        &xform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_canvas_transform :: proc "contextless" (
    self: Viewport,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_canvas_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814499831)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_global_canvas_transform :: proc "contextless" (
    self: Viewport,
    xform_: Transform2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_global_canvas_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2761652528)
    }
    self := self
    xform_ := xform_
    args := []__bindgen_gde.TypePtr {
        &xform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_global_canvas_transform :: proc "contextless" (
    self: Viewport,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_canvas_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814499831)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_get_stretch_transform :: proc "contextless" (
    self: Viewport,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stretch_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814499831)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_get_final_transform :: proc "contextless" (
    self: Viewport,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_final_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814499831)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_get_screen_transform :: proc "contextless" (
    self: Viewport,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_screen_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814499831)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_get_visible_rect :: proc "contextless" (
    self: Viewport,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visible_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1639390495)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_transparent_background :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transparent_background", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_has_transparent_background :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_transparent_background", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_use_hdr_2d :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_hdr_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_using_hdr_2d :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_hdr_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_msaa_2d :: proc "contextless" (
    self: Viewport,
    msaa_: Viewport_Msaa,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_msaa_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3330258708)
    }
    self := self
    msaa_ := msaa_
    args := []__bindgen_gde.TypePtr {
        &msaa_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_msaa_2d :: proc "contextless" (
    self: Viewport,
) -> (ret: Viewport_Msaa) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_msaa_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2542055527)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_msaa_3d :: proc "contextless" (
    self: Viewport,
    msaa_: Viewport_Msaa,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_msaa_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3330258708)
    }
    self := self
    msaa_ := msaa_
    args := []__bindgen_gde.TypePtr {
        &msaa_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_msaa_3d :: proc "contextless" (
    self: Viewport,
) -> (ret: Viewport_Msaa) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_msaa_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2542055527)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_screen_space_aa :: proc "contextless" (
    self: Viewport,
    screen_space_aa_: Viewport_Screen_Space_Aa,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_screen_space_aa", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3544169389)
    }
    self := self
    screen_space_aa_ := screen_space_aa_
    args := []__bindgen_gde.TypePtr {
        &screen_space_aa_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_screen_space_aa :: proc "contextless" (
    self: Viewport,
) -> (ret: Viewport_Screen_Space_Aa) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_screen_space_aa", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1390814124)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_use_taa :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_taa", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_using_taa :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_taa", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_use_debanding :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_debanding", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_using_debanding :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_debanding", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_use_occlusion_culling :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_occlusion_culling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_using_occlusion_culling :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_occlusion_culling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_debug_draw :: proc "contextless" (
    self: Viewport,
    debug_draw_: Viewport_Debug_Draw,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_debug_draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1970246205)
    }
    self := self
    debug_draw_ := debug_draw_
    args := []__bindgen_gde.TypePtr {
        &debug_draw_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_debug_draw :: proc "contextless" (
    self: Viewport,
) -> (ret: Viewport_Debug_Draw) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_debug_draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 579191299)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_use_oversampling :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_oversampling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_using_oversampling :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_oversampling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_oversampling_override :: proc "contextless" (
    self: Viewport,
    oversampling_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_oversampling_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    oversampling_ := oversampling_
    args := []__bindgen_gde.TypePtr {
        &oversampling_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_oversampling_override :: proc "contextless" (
    self: Viewport,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_oversampling_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_get_oversampling :: proc "contextless" (
    self: Viewport,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_oversampling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_get_render_info :: proc "contextless" (
    self: Viewport,
    type_: Viewport_Render_Info_Type,
    info_: Viewport_Render_Info,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_render_info", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 481977019)
    }
    self := self
    type_ := type_
    info_ := info_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &info_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_get_texture :: proc "contextless" (
    self: Viewport,
) -> (ret: Viewport_Texture) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1746695840)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_physics_object_picking :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_physics_object_picking", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_physics_object_picking :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_physics_object_picking", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_physics_object_picking_sort :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_physics_object_picking_sort", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_physics_object_picking_sort :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_physics_object_picking_sort", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_physics_object_picking_first_only :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_physics_object_picking_first_only", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_physics_object_picking_first_only :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_physics_object_picking_first_only", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_get_viewport_rid :: proc "contextless" (
    self: Viewport,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_viewport_rid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2944877500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_push_text_input :: proc "contextless" (
    self: Viewport,
    text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("push_text_input", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_push_input :: proc "contextless" (
    self: Viewport,
    event_: Input_Event,
    in_local_coords_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("push_input", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3644664830)
    }
    self := self
    event_ := event_
    in_local_coords_ := in_local_coords_
    args := []__bindgen_gde.TypePtr {
        &event_,
        &in_local_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_push_unhandled_input :: proc "contextless" (
    self: Viewport,
    event_: Input_Event,
    in_local_coords_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("push_unhandled_input", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3644664830)
    }
    self := self
    event_ := event_
    in_local_coords_ := in_local_coords_
    args := []__bindgen_gde.TypePtr {
        &event_,
        &in_local_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_notify_mouse_entered :: proc "contextless" (
    self: Viewport,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("notify_mouse_entered", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_notify_mouse_exited :: proc "contextless" (
    self: Viewport,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("notify_mouse_exited", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_mouse_position :: proc "contextless" (
    self: Viewport,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mouse_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_warp_mouse :: proc "contextless" (
    self: Viewport,
    position_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("warp_mouse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_update_mouse_cursor_state :: proc "contextless" (
    self: Viewport,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_mouse_cursor_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_gui_cancel_drag :: proc "contextless" (
    self: Viewport,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("gui_cancel_drag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_gui_get_drag_data :: proc "contextless" (
    self: Viewport,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("gui_get_drag_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1214101251)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_gui_get_drag_description :: proc "contextless" (
    self: Viewport,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("gui_get_drag_description", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_gui_set_drag_description :: proc "contextless" (
    self: Viewport,
    description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("gui_set_drag_description", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    description_ := description_
    args := []__bindgen_gde.TypePtr {
        &description_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_gui_is_dragging :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("gui_is_dragging", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_gui_is_drag_successful :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("gui_is_drag_successful", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_gui_release_focus :: proc "contextless" (
    self: Viewport,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("gui_release_focus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_gui_get_focus_owner :: proc "contextless" (
    self: Viewport,
) -> (ret: Control) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("gui_get_focus_owner", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2783021301)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_gui_get_hovered_control :: proc "contextless" (
    self: Viewport,
) -> (ret: Control) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("gui_get_hovered_control", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2783021301)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_disable_input :: proc "contextless" (
    self: Viewport,
    disable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_disable_input", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    disable_ := disable_
    args := []__bindgen_gde.TypePtr {
        &disable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_input_disabled :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_input_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_positional_shadow_atlas_size :: proc "contextless" (
    self: Viewport,
    size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_positional_shadow_atlas_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_positional_shadow_atlas_size :: proc "contextless" (
    self: Viewport,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_positional_shadow_atlas_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_positional_shadow_atlas_16_bits :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_positional_shadow_atlas_16_bits", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_positional_shadow_atlas_16_bits :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_positional_shadow_atlas_16_bits", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_snap_controls_to_pixels :: proc "contextless" (
    self: Viewport,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_snap_controls_to_pixels", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_snap_controls_to_pixels_enabled :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_snap_controls_to_pixels_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_snap_2d_transforms_to_pixel :: proc "contextless" (
    self: Viewport,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_snap_2d_transforms_to_pixel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_snap_2d_transforms_to_pixel_enabled :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_snap_2d_transforms_to_pixel_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_snap_2d_vertices_to_pixel :: proc "contextless" (
    self: Viewport,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_snap_2d_vertices_to_pixel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_snap_2d_vertices_to_pixel_enabled :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_snap_2d_vertices_to_pixel_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_positional_shadow_atlas_quadrant_subdiv :: proc "contextless" (
    self: Viewport,
    quadrant_: Int,
    subdiv_: Viewport_Positional_Shadow_Atlas_Quadrant_Subdiv,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_positional_shadow_atlas_quadrant_subdiv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2596956071)
    }
    self := self
    quadrant_ := quadrant_
    subdiv_ := subdiv_
    args := []__bindgen_gde.TypePtr {
        &quadrant_,
        &subdiv_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_positional_shadow_atlas_quadrant_subdiv :: proc "contextless" (
    self: Viewport,
    quadrant_: Int,
) -> (ret: Viewport_Positional_Shadow_Atlas_Quadrant_Subdiv) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_positional_shadow_atlas_quadrant_subdiv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2676778355)
    }
    self := self
    quadrant_ := quadrant_
    args := []__bindgen_gde.TypePtr {
        &quadrant_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_input_as_handled :: proc "contextless" (
    self: Viewport,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_input_as_handled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_input_handled :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_input_handled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_handle_input_locally :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_handle_input_locally", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_handling_input_locally :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_handling_input_locally", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_default_canvas_item_texture_filter :: proc "contextless" (
    self: Viewport,
    mode_: Viewport_Default_Canvas_Item_Texture_Filter,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_default_canvas_item_texture_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2815160100)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_default_canvas_item_texture_filter :: proc "contextless" (
    self: Viewport,
) -> (ret: Viewport_Default_Canvas_Item_Texture_Filter) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_default_canvas_item_texture_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 896601198)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_embedding_subwindows :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_embedding_subwindows", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_embedding_subwindows :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_embedding_subwindows", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_get_embedded_subwindows :: proc "contextless" (
    self: Viewport,
) -> (ret: Typed_Array(Window)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_embedded_subwindows", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_drag_threshold :: proc "contextless" (
    self: Viewport,
    threshold_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_drag_threshold", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    threshold_ := threshold_
    args := []__bindgen_gde.TypePtr {
        &threshold_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_drag_threshold :: proc "contextless" (
    self: Viewport,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_drag_threshold", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_canvas_cull_mask :: proc "contextless" (
    self: Viewport,
    mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_canvas_cull_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    mask_ := mask_
    args := []__bindgen_gde.TypePtr {
        &mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_canvas_cull_mask :: proc "contextless" (
    self: Viewport,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_canvas_cull_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_canvas_cull_mask_bit :: proc "contextless" (
    self: Viewport,
    layer_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_canvas_cull_mask_bit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    layer_ := layer_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_canvas_cull_mask_bit :: proc "contextless" (
    self: Viewport,
    layer_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_canvas_cull_mask_bit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_default_canvas_item_texture_repeat :: proc "contextless" (
    self: Viewport,
    mode_: Viewport_Default_Canvas_Item_Texture_Repeat,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_default_canvas_item_texture_repeat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1658513413)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_default_canvas_item_texture_repeat :: proc "contextless" (
    self: Viewport,
) -> (ret: Viewport_Default_Canvas_Item_Texture_Repeat) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_default_canvas_item_texture_repeat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4049774160)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_sdf_oversize :: proc "contextless" (
    self: Viewport,
    oversize_: Viewport_Sdf_Oversize,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sdf_oversize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2574159017)
    }
    self := self
    oversize_ := oversize_
    args := []__bindgen_gde.TypePtr {
        &oversize_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_sdf_oversize :: proc "contextless" (
    self: Viewport,
) -> (ret: Viewport_Sdf_Oversize) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sdf_oversize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2631427510)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_sdf_scale :: proc "contextless" (
    self: Viewport,
    scale_: Viewport_Sdf_Scale,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sdf_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1402773951)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_sdf_scale :: proc "contextless" (
    self: Viewport,
) -> (ret: Viewport_Sdf_Scale) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sdf_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3162688184)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_mesh_lod_threshold :: proc "contextless" (
    self: Viewport,
    pixels_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mesh_lod_threshold", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    pixels_ := pixels_
    args := []__bindgen_gde.TypePtr {
        &pixels_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_mesh_lod_threshold :: proc "contextless" (
    self: Viewport,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mesh_lod_threshold", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_as_audio_listener_2d :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_as_audio_listener_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_audio_listener_2d :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_audio_listener_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_get_audio_listener_2d :: proc "contextless" (
    self: Viewport,
) -> (ret: Audio_Listener2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_audio_listener_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1840977180)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_get_camera_2d :: proc "contextless" (
    self: Viewport,
) -> (ret: Camera2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_camera_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3551466917)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_world_3d :: proc "contextless" (
    self: Viewport,
    world_3d_: World3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_world_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1400875337)
    }
    self := self
    world_3d_ := world_3d_
    args := []__bindgen_gde.TypePtr {
        &world_3d_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_world_3d :: proc "contextless" (
    self: Viewport,
) -> (ret: World3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_world_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 317588385)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_find_world_3d :: proc "contextless" (
    self: Viewport,
) -> (ret: World3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_world_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 317588385)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_use_own_world_3d :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_own_world_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_using_own_world_3d :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_own_world_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_get_audio_listener_3d :: proc "contextless" (
    self: Viewport,
) -> (ret: Audio_Listener3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_audio_listener_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3472246991)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_get_camera_3d :: proc "contextless" (
    self: Viewport,
) -> (ret: Camera3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_camera_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2285090890)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_as_audio_listener_3d :: proc "contextless" (
    self: Viewport,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_as_audio_listener_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_audio_listener_3d :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_audio_listener_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_disable_3d :: proc "contextless" (
    self: Viewport,
    disable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_disable_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    disable_ := disable_
    args := []__bindgen_gde.TypePtr {
        &disable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_3d_disabled :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_3d_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_use_xr :: proc "contextless" (
    self: Viewport,
    use_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_xr", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    use_ := use_
    args := []__bindgen_gde.TypePtr {
        &use_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_is_using_xr :: proc "contextless" (
    self: Viewport,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_xr", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_scaling_3d_mode :: proc "contextless" (
    self: Viewport,
    scaling_3d_mode_: Viewport_Scaling3d_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scaling_3d_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1531597597)
    }
    self := self
    scaling_3d_mode_ := scaling_3d_mode_
    args := []__bindgen_gde.TypePtr {
        &scaling_3d_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_scaling_3d_mode :: proc "contextless" (
    self: Viewport,
) -> (ret: Viewport_Scaling3d_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scaling_3d_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2597660574)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_scaling_3d_scale :: proc "contextless" (
    self: Viewport,
    scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scaling_3d_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_scaling_3d_scale :: proc "contextless" (
    self: Viewport,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scaling_3d_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_fsr_sharpness :: proc "contextless" (
    self: Viewport,
    fsr_sharpness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fsr_sharpness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    fsr_sharpness_ := fsr_sharpness_
    args := []__bindgen_gde.TypePtr {
        &fsr_sharpness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_fsr_sharpness :: proc "contextless" (
    self: Viewport,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fsr_sharpness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_texture_mipmap_bias :: proc "contextless" (
    self: Viewport,
    texture_mipmap_bias_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_mipmap_bias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    texture_mipmap_bias_ := texture_mipmap_bias_
    args := []__bindgen_gde.TypePtr {
        &texture_mipmap_bias_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_texture_mipmap_bias :: proc "contextless" (
    self: Viewport,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_mipmap_bias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_anisotropic_filtering_level :: proc "contextless" (
    self: Viewport,
    anisotropic_filtering_level_: Viewport_Anisotropic_Filtering,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_anisotropic_filtering_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3445583046)
    }
    self := self
    anisotropic_filtering_level_ := anisotropic_filtering_level_
    args := []__bindgen_gde.TypePtr {
        &anisotropic_filtering_level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_anisotropic_filtering_level :: proc "contextless" (
    self: Viewport,
) -> (ret: Viewport_Anisotropic_Filtering) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_anisotropic_filtering_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3991528932)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_vrs_mode :: proc "contextless" (
    self: Viewport,
    mode_: Viewport_Vrs_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vrs_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2749867817)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_vrs_mode :: proc "contextless" (
    self: Viewport,
) -> (ret: Viewport_Vrs_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vrs_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 349660525)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_vrs_update_mode :: proc "contextless" (
    self: Viewport,
    mode_: Viewport_Vrs_Update_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vrs_update_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3182412319)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_vrs_update_mode :: proc "contextless" (
    self: Viewport,
) -> (ret: Viewport_Vrs_Update_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vrs_update_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2255951583)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

viewport_set_vrs_texture :: proc "contextless" (
    self: Viewport,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vrs_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

viewport_get_vrs_texture :: proc "contextless" (
    self: Viewport,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vrs_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
viewport_get_disable_3d :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_3d_disabled(self)
}
viewport_get_use_xr :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_using_xr(self)
}
viewport_get_own_world_3d :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_using_own_world_3d(self)
}
viewport_set_own_world_3d :: proc "contextless" (self: Viewport, value: Bool) {
    viewport_set_use_own_world_3d(self, value)
}
viewport_get_transparent_bg :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_has_transparent_background(self)
}
viewport_set_transparent_bg :: proc "contextless" (self: Viewport, value: Bool) {
    viewport_set_transparent_background(self, value)
}
viewport_get_handle_input_locally :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_handling_input_locally(self)
}
viewport_get_snap_2d_transforms_to_pixel :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_snap_2d_transforms_to_pixel_enabled(self)
}
viewport_get_snap_2d_vertices_to_pixel :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_snap_2d_vertices_to_pixel_enabled(self)
}
viewport_get_use_taa :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_using_taa(self)
}
viewport_get_use_debanding :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_using_debanding(self)
}
viewport_get_use_occlusion_culling :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_using_occlusion_culling(self)
}
viewport_get_use_hdr_2d :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_using_hdr_2d(self)
}
viewport_get_canvas_item_default_texture_filter :: proc "contextless" (self: Viewport) -> Viewport_Default_Canvas_Item_Texture_Filter {
    return viewport_get_default_canvas_item_texture_filter(self)
}
viewport_set_canvas_item_default_texture_filter :: proc "contextless" (self: Viewport, value: Viewport_Default_Canvas_Item_Texture_Filter) {
    viewport_set_default_canvas_item_texture_filter(self, value)
}
viewport_get_canvas_item_default_texture_repeat :: proc "contextless" (self: Viewport) -> Viewport_Default_Canvas_Item_Texture_Repeat {
    return viewport_get_default_canvas_item_texture_repeat(self)
}
viewport_set_canvas_item_default_texture_repeat :: proc "contextless" (self: Viewport, value: Viewport_Default_Canvas_Item_Texture_Repeat) {
    viewport_set_default_canvas_item_texture_repeat(self, value)
}
viewport_get_audio_listener_enable_2d :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_audio_listener_2d(self)
}
viewport_set_audio_listener_enable_2d :: proc "contextless" (self: Viewport, value: Bool) {
    viewport_set_as_audio_listener_2d(self, value)
}
viewport_get_audio_listener_enable_3d :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_audio_listener_3d(self)
}
viewport_set_audio_listener_enable_3d :: proc "contextless" (self: Viewport, value: Bool) {
    viewport_set_as_audio_listener_3d(self, value)
}
viewport_get_gui_disable_input :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_input_disabled(self)
}
viewport_set_gui_disable_input :: proc "contextless" (self: Viewport, value: Bool) {
    viewport_set_disable_input(self, value)
}
viewport_get_gui_snap_controls_to_pixels :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_snap_controls_to_pixels_enabled(self)
}
viewport_set_gui_snap_controls_to_pixels :: proc "contextless" (self: Viewport, value: Bool) {
    viewport_set_snap_controls_to_pixels(self, value)
}
viewport_get_gui_embed_subwindows :: proc "contextless" (self: Viewport) -> Bool {
    return viewport_is_embedding_subwindows(self)
}
viewport_set_gui_embed_subwindows :: proc "contextless" (self: Viewport, value: Bool) {
    viewport_set_embedding_subwindows(self, value)
}
viewport_get_gui_drag_threshold :: proc "contextless" (self: Viewport) -> i32 {
    return viewport_get_drag_threshold(self)
}
viewport_set_gui_drag_threshold :: proc "contextless" (self: Viewport, value: Int) {
    viewport_set_drag_threshold(self, value)
}
viewport_get_positional_shadow_atlas_quad_0 :: proc "contextless" (self: Viewport) -> Viewport_Positional_Shadow_Atlas_Quadrant_Subdiv {
    return viewport_get_positional_shadow_atlas_quadrant_subdiv(self, Int(0))
}
viewport_set_positional_shadow_atlas_quad_0 :: proc "contextless" (self: Viewport, value: Viewport_Positional_Shadow_Atlas_Quadrant_Subdiv) {
    viewport_set_positional_shadow_atlas_quadrant_subdiv(self, Int(0), value)
}
viewport_get_positional_shadow_atlas_quad_1 :: proc "contextless" (self: Viewport) -> Viewport_Positional_Shadow_Atlas_Quadrant_Subdiv {
    return viewport_get_positional_shadow_atlas_quadrant_subdiv(self, Int(1))
}
viewport_set_positional_shadow_atlas_quad_1 :: proc "contextless" (self: Viewport, value: Viewport_Positional_Shadow_Atlas_Quadrant_Subdiv) {
    viewport_set_positional_shadow_atlas_quadrant_subdiv(self, Int(1), value)
}
viewport_get_positional_shadow_atlas_quad_2 :: proc "contextless" (self: Viewport) -> Viewport_Positional_Shadow_Atlas_Quadrant_Subdiv {
    return viewport_get_positional_shadow_atlas_quadrant_subdiv(self, Int(2))
}
viewport_set_positional_shadow_atlas_quad_2 :: proc "contextless" (self: Viewport, value: Viewport_Positional_Shadow_Atlas_Quadrant_Subdiv) {
    viewport_set_positional_shadow_atlas_quadrant_subdiv(self, Int(2), value)
}
viewport_get_positional_shadow_atlas_quad_3 :: proc "contextless" (self: Viewport) -> Viewport_Positional_Shadow_Atlas_Quadrant_Subdiv {
    return viewport_get_positional_shadow_atlas_quadrant_subdiv(self, Int(3))
}
viewport_set_positional_shadow_atlas_quad_3 :: proc "contextless" (self: Viewport, value: Viewport_Positional_Shadow_Atlas_Quadrant_Subdiv) {
    viewport_set_positional_shadow_atlas_quadrant_subdiv(self, Int(3), value)
}
viewport_set_oversampling :: proc "contextless" (self: Viewport, value: Bool) {
    viewport_set_use_oversampling(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
viewport_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Viewport", true)
}

@(private = "file")
__class_name: String_Name