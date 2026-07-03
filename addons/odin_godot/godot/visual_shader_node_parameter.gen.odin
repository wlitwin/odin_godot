package godot

import __bindgen_gde "godot:gdext"

Visual_Shader_Node_Parameter_Constants :: enum {
}
Visual_Shader_Node_Parameter_Qualifier :: enum int {
    Qual_None = 0,
    Qual_Global = 1,
    Qual_Instance = 2,
    Qual_Instance_Index = 3,
    Qual_Max = 4,
}



visual_shader_node_parameter_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

visual_shader_node_parameter_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_visual_shader_node_parameter :: proc "contextless" () -> Visual_Shader_Node_Parameter {
    return cast(Visual_Shader_Node_Parameter)__bindgen_gde.classdb_construct_object(visual_shader_node_parameter_name_ref())
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

visual_shader_node_parameter_set_parameter_name :: proc "contextless" (
    self: Visual_Shader_Node_Parameter,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_parameter_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_parameter_get_parameter_name :: proc "contextless" (
    self: Visual_Shader_Node_Parameter,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_parameter_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_parameter_set_qualifier :: proc "contextless" (
    self: Visual_Shader_Node_Parameter,
    qualifier_: Visual_Shader_Node_Parameter_Qualifier,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_qualifier", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1276489447)
    }
    self := self
    qualifier_ := qualifier_
    args := []__bindgen_gde.TypePtr {
        &qualifier_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_parameter_get_qualifier :: proc "contextless" (
    self: Visual_Shader_Node_Parameter,
) -> (ret: Visual_Shader_Node_Parameter_Qualifier) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_qualifier", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3558406205)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_parameter_set_instance_index :: proc "contextless" (
    self: Visual_Shader_Node_Parameter,
    instance_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_instance_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    instance_index_ := instance_index_
    args := []__bindgen_gde.TypePtr {
        &instance_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_parameter_get_instance_index :: proc "contextless" (
    self: Visual_Shader_Node_Parameter,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_instance_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
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
visual_shader_node_parameter_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("VisualShaderNodeParameter", true)
}

@(private = "file")
__class_name: String_Name