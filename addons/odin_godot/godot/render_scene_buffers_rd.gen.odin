package godot

import __bindgen_gde "godot:gdext"

Render_Scene_Buffers_Rd_Constants :: enum {
}



render_scene_buffers_rd_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

render_scene_buffers_rd_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_render_scene_buffers_rd :: proc "contextless" () -> Render_Scene_Buffers_Rd {
    return cast(Render_Scene_Buffers_Rd)__bindgen_gde.classdb_construct_object(render_scene_buffers_rd_name_ref())
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

render_scene_buffers_rd_has_texture :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    context_: String_Name,
    name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 471820014)
    }
    self := self
    context_ := context_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &context_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_create_texture :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    context_: String_Name,
    name_: String_Name,
    data_format_: Rendering_Device_Data_Format,
    usage_bits_: Int,
    texture_samples_: Rendering_Device_Texture_Samples,
    size_: Vector2i,
    layers_: Int,
    mipmaps_: Int,
    unique_: Bool,
    discardable_: Bool,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2950875024)
    }
    self := self
    context_ := context_
    name_ := name_
    data_format_ := data_format_
    usage_bits_ := usage_bits_
    texture_samples_ := texture_samples_
    size_ := size_
    layers_ := layers_
    mipmaps_ := mipmaps_
    unique_ := unique_
    discardable_ := discardable_
    args := []__bindgen_gde.TypePtr {
        &context_,
        &name_,
        &data_format_,
        &usage_bits_,
        &texture_samples_,
        &size_,
        &layers_,
        &mipmaps_,
        &unique_,
        &discardable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_create_texture_from_format :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    context_: String_Name,
    name_: String_Name,
    format_: Rd_Texture_Format,
    view_: Rd_Texture_View,
    unique_: Bool,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_texture_from_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3344669382)
    }
    self := self
    context_ := context_
    name_ := name_
    format_ := format_
    view_ := view_
    unique_ := unique_
    args := []__bindgen_gde.TypePtr {
        &context_,
        &name_,
        &format_,
        &view_,
        &unique_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_create_texture_view :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    context_: String_Name,
    name_: String_Name,
    view_name_: String_Name,
    view_: Rd_Texture_View,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_texture_view", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 283055834)
    }
    self := self
    context_ := context_
    name_ := name_
    view_name_ := view_name_
    view_ := view_
    args := []__bindgen_gde.TypePtr {
        &context_,
        &name_,
        &view_name_,
        &view_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_get_texture :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    context_: String_Name,
    name_: String_Name,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 750006389)
    }
    self := self
    context_ := context_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &context_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_get_texture_format :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    context_: String_Name,
    name_: String_Name,
) -> (ret: Rd_Texture_Format) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 371461758)
    }
    self := self
    context_ := context_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &context_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_get_texture_slice :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    context_: String_Name,
    name_: String_Name,
    layer_: Int,
    mipmap_: Int,
    layers_: Int,
    mipmaps_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_slice", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 588440706)
    }
    self := self
    context_ := context_
    name_ := name_
    layer_ := layer_
    mipmap_ := mipmap_
    layers_ := layers_
    mipmaps_ := mipmaps_
    args := []__bindgen_gde.TypePtr {
        &context_,
        &name_,
        &layer_,
        &mipmap_,
        &layers_,
        &mipmaps_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_get_texture_slice_view :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    context_: String_Name,
    name_: String_Name,
    layer_: Int,
    mipmap_: Int,
    layers_: Int,
    mipmaps_: Int,
    view_: Rd_Texture_View,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_slice_view", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 682451778)
    }
    self := self
    context_ := context_
    name_ := name_
    layer_ := layer_
    mipmap_ := mipmap_
    layers_ := layers_
    mipmaps_ := mipmaps_
    view_ := view_
    args := []__bindgen_gde.TypePtr {
        &context_,
        &name_,
        &layer_,
        &mipmap_,
        &layers_,
        &mipmaps_,
        &view_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_get_texture_slice_size :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    context_: String_Name,
    name_: String_Name,
    mipmap_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_slice_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2617625368)
    }
    self := self
    context_ := context_
    name_ := name_
    mipmap_ := mipmap_
    args := []__bindgen_gde.TypePtr {
        &context_,
        &name_,
        &mipmap_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_clear_context :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    context_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_context", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    context_ := context_
    args := []__bindgen_gde.TypePtr {
        &context_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

render_scene_buffers_rd_get_color_texture :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    msaa_: Bool,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3050822880)
    }
    self := self
    msaa_ := msaa_
    args := []__bindgen_gde.TypePtr {
        &msaa_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_get_color_layer :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    layer_: Int,
    msaa_: Bool,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3087988589)
    }
    self := self
    layer_ := layer_
    msaa_ := msaa_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &msaa_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_get_depth_texture :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    msaa_: Bool,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_depth_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3050822880)
    }
    self := self
    msaa_ := msaa_
    args := []__bindgen_gde.TypePtr {
        &msaa_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_get_depth_layer :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    layer_: Int,
    msaa_: Bool,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_depth_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3087988589)
    }
    self := self
    layer_ := layer_
    msaa_ := msaa_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &msaa_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_get_velocity_texture :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    msaa_: Bool,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_velocity_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3050822880)
    }
    self := self
    msaa_ := msaa_
    args := []__bindgen_gde.TypePtr {
        &msaa_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_get_velocity_layer :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
    layer_: Int,
    msaa_: Bool,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_velocity_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3087988589)
    }
    self := self
    layer_ := layer_
    msaa_ := msaa_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &msaa_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_get_render_target :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
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

render_scene_buffers_rd_get_view_count :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
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

render_scene_buffers_rd_get_internal_size :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
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

render_scene_buffers_rd_get_target_size :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
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

render_scene_buffers_rd_get_scaling_3d_mode :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
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

render_scene_buffers_rd_get_fsr_sharpness :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
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

render_scene_buffers_rd_get_msaa_3d :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
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

render_scene_buffers_rd_get_texture_samples :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
) -> (ret: Rendering_Device_Texture_Samples) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_samples", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 407791724)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_get_screen_space_aa :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
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

render_scene_buffers_rd_get_use_taa :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_use_taa", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

render_scene_buffers_rd_get_use_debanding :: proc "contextless" (
    self: Render_Scene_Buffers_Rd,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_use_debanding", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
render_scene_buffers_rd_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("RenderSceneBuffersRD", true)
}

@(private = "file")
__class_name: String_Name