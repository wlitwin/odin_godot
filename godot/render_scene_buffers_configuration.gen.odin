package godot

import __bindgen_gde "godot:gdext"

Render_Scene_Buffers_Configuration_Constants :: enum {
}



render_scene_buffers_configuration_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

render_scene_buffers_configuration_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_render_scene_buffers_configuration :: proc "contextless" () -> Render_Scene_Buffers_Configuration {
    return cast(Render_Scene_Buffers_Configuration)__bindgen_gde.classdb_construct_object(render_scene_buffers_configuration_name_ref())
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

render_scene_buffers_configuration_get_render_target :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_render_target", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2944877500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_configuration_set_render_target :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
    render_target_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_render_target", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    render_target_ := render_target_
    args := []__bindgen_gde.TypePtr {
        &render_target_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

render_scene_buffers_configuration_get_internal_size :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_internal_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_configuration_set_internal_size :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
    internal_size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_internal_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    internal_size_ := internal_size_
    args := []__bindgen_gde.TypePtr {
        &internal_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

render_scene_buffers_configuration_get_target_size :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_target_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_configuration_set_target_size :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
    target_size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_target_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    target_size_ := target_size_
    args := []__bindgen_gde.TypePtr {
        &target_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

render_scene_buffers_configuration_get_view_count :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_view_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_configuration_set_view_count :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
    view_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_view_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    view_count_ := view_count_
    args := []__bindgen_gde.TypePtr {
        &view_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

render_scene_buffers_configuration_get_scaling_3d_mode :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
) -> (ret: Rendering_Server_Viewport_Scaling3d_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scaling_3d_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 976778074)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_configuration_set_scaling_3d_mode :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
    scaling_3d_mode_: Rendering_Server_Viewport_Scaling3d_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scaling_3d_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 447477857)
    }
    self := self
    scaling_3d_mode_ := scaling_3d_mode_
    args := []__bindgen_gde.TypePtr {
        &scaling_3d_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

render_scene_buffers_configuration_get_msaa_3d :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
) -> (ret: Rendering_Server_Viewport_Msaa) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_msaa_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3109158617)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_configuration_set_msaa_3d :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
    msaa_3d_: Rendering_Server_Viewport_Msaa,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_msaa_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3952630748)
    }
    self := self
    msaa_3d_ := msaa_3d_
    args := []__bindgen_gde.TypePtr {
        &msaa_3d_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

render_scene_buffers_configuration_get_screen_space_aa :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
) -> (ret: Rendering_Server_Viewport_Screen_Space_Aa) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_screen_space_aa", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 641513172)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_configuration_set_screen_space_aa :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
    screen_space_aa_: Rendering_Server_Viewport_Screen_Space_Aa,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_screen_space_aa", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 139543108)
    }
    self := self
    screen_space_aa_ := screen_space_aa_
    args := []__bindgen_gde.TypePtr {
        &screen_space_aa_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

render_scene_buffers_configuration_get_fsr_sharpness :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
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

render_scene_buffers_configuration_set_fsr_sharpness :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
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

render_scene_buffers_configuration_get_texture_mipmap_bias :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
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

render_scene_buffers_configuration_set_texture_mipmap_bias :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
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

render_scene_buffers_configuration_get_anisotropic_filtering_level :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
) -> (ret: Rendering_Server_Viewport_Anisotropic_Filtering) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_anisotropic_filtering_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1617414954)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_configuration_set_anisotropic_filtering_level :: proc "contextless" (
    self: Render_Scene_Buffers_Configuration,
    anisotropic_filtering_level_: Rendering_Server_Viewport_Anisotropic_Filtering,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_anisotropic_filtering_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2559658741)
    }
    self := self
    anisotropic_filtering_level_ := anisotropic_filtering_level_
    args := []__bindgen_gde.TypePtr {
        &anisotropic_filtering_level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
render_scene_buffers_configuration_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("RenderSceneBuffersConfiguration", true)
}

@(private = "file")
__class_name: String_Name