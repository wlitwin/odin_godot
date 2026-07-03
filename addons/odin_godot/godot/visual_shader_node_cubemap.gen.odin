package godot

import __bindgen_gde "godot:gdext"

Visual_Shader_Node_Cubemap_Constants :: enum {
}
Visual_Shader_Node_Cubemap_Source :: enum int {
    Source_Texture = 0,
    Source_Port = 1,
    Source_Max = 2,
}
Visual_Shader_Node_Cubemap_Texture_Type :: enum int {
    Type_Data = 0,
    Type_Color = 1,
    Type_Normal_Map = 2,
    Type_Max = 3,
}



visual_shader_node_cubemap_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

visual_shader_node_cubemap_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_visual_shader_node_cubemap :: proc "contextless" () -> Visual_Shader_Node_Cubemap {
    return cast(Visual_Shader_Node_Cubemap)__bindgen_gde.classdb_construct_object(visual_shader_node_cubemap_name_ref())
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

visual_shader_node_cubemap_set_source :: proc "contextless" (
    self: Visual_Shader_Node_Cubemap,
    value_: Visual_Shader_Node_Cubemap_Source,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1625400621)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_cubemap_get_source :: proc "contextless" (
    self: Visual_Shader_Node_Cubemap,
) -> (ret: Visual_Shader_Node_Cubemap_Source) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2222048781)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_cubemap_set_cube_map :: proc "contextless" (
    self: Visual_Shader_Node_Cubemap,
    value_: Texture_Layered,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cube_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1278366092)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_cubemap_get_cube_map :: proc "contextless" (
    self: Visual_Shader_Node_Cubemap,
) -> (ret: Texture_Layered) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cube_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3984243839)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_cubemap_set_texture_type :: proc "contextless" (
    self: Visual_Shader_Node_Cubemap,
    value_: Visual_Shader_Node_Cubemap_Texture_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1899718876)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_cubemap_get_texture_type :: proc "contextless" (
    self: Visual_Shader_Node_Cubemap,
) -> (ret: Visual_Shader_Node_Cubemap_Texture_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3356498888)
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
visual_shader_node_cubemap_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("VisualShaderNodeCubemap", true)
}

@(private = "file")
__class_name: String_Name