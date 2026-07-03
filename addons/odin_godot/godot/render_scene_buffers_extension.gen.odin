package godot

import __bindgen_gde "godot:gdext"

Render_Scene_Buffers_Extension_Constants :: enum {
}



render_scene_buffers_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

render_scene_buffers_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_render_scene_buffers_extension :: proc "contextless" () -> Render_Scene_Buffers_Extension {
    return cast(Render_Scene_Buffers_Extension)__bindgen_gde.classdb_construct_object(render_scene_buffers_extension_name_ref())
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

render_scene_buffers_extension__configure :: proc "contextless" (
    self: Render_Scene_Buffers_Extension,
    config_: Render_Scene_Buffers_Configuration,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_configure", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3072623270)
    }
    self := self
    config_ := config_
    args := []__bindgen_gde.TypePtr {
        &config_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

render_scene_buffers_extension__set_fsr_sharpness :: proc "contextless" (
    self: Render_Scene_Buffers_Extension,
    fsr_sharpness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_fsr_sharpness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    fsr_sharpness_ := fsr_sharpness_
    args := []__bindgen_gde.TypePtr {
        &fsr_sharpness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

render_scene_buffers_extension__set_texture_mipmap_bias :: proc "contextless" (
    self: Render_Scene_Buffers_Extension,
    texture_mipmap_bias_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_texture_mipmap_bias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    texture_mipmap_bias_ := texture_mipmap_bias_
    args := []__bindgen_gde.TypePtr {
        &texture_mipmap_bias_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

render_scene_buffers_extension__set_anisotropic_filtering_level :: proc "contextless" (
    self: Render_Scene_Buffers_Extension,
    anisotropic_filtering_level_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_anisotropic_filtering_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    anisotropic_filtering_level_ := anisotropic_filtering_level_
    args := []__bindgen_gde.TypePtr {
        &anisotropic_filtering_level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

render_scene_buffers_extension__set_use_debanding :: proc "contextless" (
    self: Render_Scene_Buffers_Extension,
    use_debanding_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_use_debanding", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    use_debanding_ := use_debanding_
    args := []__bindgen_gde.TypePtr {
        &use_debanding_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
render_scene_buffers_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("RenderSceneBuffersExtension", true)
}

@(private = "file")
__class_name: String_Name