package godot

import __bindgen_gde "godot:gdext"

Visual_Shader_Node_Texture_Parameter_Constants :: enum {
}
Visual_Shader_Node_Texture_Parameter_Texture_Type :: enum int {
    Type_Data = 0,
    Type_Color = 1,
    Type_Normal_Map = 2,
    Type_Anisotropy = 3,
    Type_Max = 4,
}
Visual_Shader_Node_Texture_Parameter_Color_Default :: enum int {
    Color_Default_White = 0,
    Color_Default_Black = 1,
    Color_Default_Transparent = 2,
    Color_Default_Max = 3,
}
Visual_Shader_Node_Texture_Parameter_Texture_Filter :: enum int {
    Filter_Default = 0,
    Filter_Nearest = 1,
    Filter_Linear = 2,
    Filter_Nearest_Mipmap = 3,
    Filter_Linear_Mipmap = 4,
    Filter_Nearest_Mipmap_Anisotropic = 5,
    Filter_Linear_Mipmap_Anisotropic = 6,
    Filter_Max = 7,
}
Visual_Shader_Node_Texture_Parameter_Texture_Repeat :: enum int {
    Repeat_Default = 0,
    Repeat_Enabled = 1,
    Repeat_Disabled = 2,
    Repeat_Max = 3,
}
Visual_Shader_Node_Texture_Parameter_Texture_Source :: enum int {
    Source_None = 0,
    Source_Screen = 1,
    Source_Depth = 2,
    Source_Normal_Roughness = 3,
    Source_Max = 4,
}



visual_shader_node_texture_parameter_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

visual_shader_node_texture_parameter_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_visual_shader_node_texture_parameter :: proc "contextless" () -> Visual_Shader_Node_Texture_Parameter {
    return cast(Visual_Shader_Node_Texture_Parameter)__bindgen_gde.classdb_construct_object(visual_shader_node_texture_parameter_name_ref())
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

visual_shader_node_texture_parameter_set_texture_type :: proc "contextless" (
    self: Visual_Shader_Node_Texture_Parameter,
    type_: Visual_Shader_Node_Texture_Parameter_Texture_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2227296876)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_texture_parameter_get_texture_type :: proc "contextless" (
    self: Visual_Shader_Node_Texture_Parameter,
) -> (ret: Visual_Shader_Node_Texture_Parameter_Texture_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 367922070)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_texture_parameter_set_color_default :: proc "contextless" (
    self: Visual_Shader_Node_Texture_Parameter,
    color_: Visual_Shader_Node_Texture_Parameter_Color_Default,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_color_default", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4217624432)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_texture_parameter_get_color_default :: proc "contextless" (
    self: Visual_Shader_Node_Texture_Parameter,
) -> (ret: Visual_Shader_Node_Texture_Parameter_Color_Default) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color_default", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3837060134)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_texture_parameter_set_texture_filter :: proc "contextless" (
    self: Visual_Shader_Node_Texture_Parameter,
    filter_: Visual_Shader_Node_Texture_Parameter_Texture_Filter,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2147684752)
    }
    self := self
    filter_ := filter_
    args := []__bindgen_gde.TypePtr {
        &filter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_texture_parameter_get_texture_filter :: proc "contextless" (
    self: Visual_Shader_Node_Texture_Parameter,
) -> (ret: Visual_Shader_Node_Texture_Parameter_Texture_Filter) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4184490817)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_texture_parameter_set_texture_repeat :: proc "contextless" (
    self: Visual_Shader_Node_Texture_Parameter,
    repeat_: Visual_Shader_Node_Texture_Parameter_Texture_Repeat,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_repeat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2036143070)
    }
    self := self
    repeat_ := repeat_
    args := []__bindgen_gde.TypePtr {
        &repeat_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_texture_parameter_get_texture_repeat :: proc "contextless" (
    self: Visual_Shader_Node_Texture_Parameter,
) -> (ret: Visual_Shader_Node_Texture_Parameter_Texture_Repeat) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_repeat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1690132794)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_texture_parameter_set_texture_source :: proc "contextless" (
    self: Visual_Shader_Node_Texture_Parameter,
    source_: Visual_Shader_Node_Texture_Parameter_Texture_Source,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1212687372)
    }
    self := self
    source_ := source_
    args := []__bindgen_gde.TypePtr {
        &source_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_texture_parameter_get_texture_source :: proc "contextless" (
    self: Visual_Shader_Node_Texture_Parameter,
) -> (ret: Visual_Shader_Node_Texture_Parameter_Texture_Source) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2039092262)
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
visual_shader_node_texture_parameter_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("VisualShaderNodeTextureParameter", true)
}

@(private = "file")
__class_name: String_Name