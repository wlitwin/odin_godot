package godot

import __bindgen_gde "godot:gdext"

Visual_Shader_Node_Compare_Constants :: enum {
}
Visual_Shader_Node_Compare_Comparison_Type :: enum int {
    Ctype_Scalar = 0,
    Ctype_Scalar_Int = 1,
    Ctype_Scalar_Uint = 2,
    Ctype_Vector_2d = 3,
    Ctype_Vector_3d = 4,
    Ctype_Vector_4d = 5,
    Ctype_Boolean = 6,
    Ctype_Transform = 7,
    Ctype_Max = 8,
}
Visual_Shader_Node_Compare_Function :: enum int {
    Func_Equal = 0,
    Func_Not_Equal = 1,
    Func_Greater_Than = 2,
    Func_Greater_Than_Equal = 3,
    Func_Less_Than = 4,
    Func_Less_Than_Equal = 5,
    Func_Max = 6,
}
Visual_Shader_Node_Compare_Condition :: enum int {
    Cond_All = 0,
    Cond_Any = 1,
    Cond_Max = 2,
}



visual_shader_node_compare_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

visual_shader_node_compare_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_visual_shader_node_compare :: proc "contextless" () -> Visual_Shader_Node_Compare {
    return cast(Visual_Shader_Node_Compare)__bindgen_gde.classdb_construct_object(visual_shader_node_compare_name_ref())
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

visual_shader_node_compare_set_comparison_type :: proc "contextless" (
    self: Visual_Shader_Node_Compare,
    type_: Visual_Shader_Node_Compare_Comparison_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_comparison_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 516558320)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_compare_get_comparison_type :: proc "contextless" (
    self: Visual_Shader_Node_Compare,
) -> (ret: Visual_Shader_Node_Compare_Comparison_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_comparison_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3495315961)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_compare_set_function :: proc "contextless" (
    self: Visual_Shader_Node_Compare,
    func_: Visual_Shader_Node_Compare_Function,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_function", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2370951349)
    }
    self := self
    func_ := func_
    args := []__bindgen_gde.TypePtr {
        &func_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_compare_get_function :: proc "contextless" (
    self: Visual_Shader_Node_Compare,
) -> (ret: Visual_Shader_Node_Compare_Function) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_function", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4089164265)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_compare_set_condition :: proc "contextless" (
    self: Visual_Shader_Node_Compare,
    condition_: Visual_Shader_Node_Compare_Condition,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_condition", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 918742392)
    }
    self := self
    condition_ := condition_
    args := []__bindgen_gde.TypePtr {
        &condition_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_compare_get_condition :: proc "contextless" (
    self: Visual_Shader_Node_Compare,
) -> (ret: Visual_Shader_Node_Compare_Condition) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_condition", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3281078941)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
visual_shader_node_compare_get_type :: proc "contextless" (self: Visual_Shader_Node_Compare) -> Visual_Shader_Node_Compare_Comparison_Type {
    return visual_shader_node_compare_get_comparison_type(self)
}
visual_shader_node_compare_set_type :: proc "contextless" (self: Visual_Shader_Node_Compare, value: Visual_Shader_Node_Compare_Comparison_Type) {
    visual_shader_node_compare_set_comparison_type(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
visual_shader_node_compare_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("VisualShaderNodeCompare", true)
}

@(private = "file")
__class_name: String_Name