package godot

import __bindgen_gde "godot:gdext"

Visual_Shader_Node_Derivative_Func_Constants :: enum {
}
Visual_Shader_Node_Derivative_Func_Op_Type :: enum int {
    Op_Type_Scalar = 0,
    Op_Type_Vector_2d = 1,
    Op_Type_Vector_3d = 2,
    Op_Type_Vector_4d = 3,
    Op_Type_Max = 4,
}
Visual_Shader_Node_Derivative_Func_Function :: enum int {
    Func_Sum = 0,
    Func_X = 1,
    Func_Y = 2,
    Func_Max = 3,
}
Visual_Shader_Node_Derivative_Func_Precision :: enum int {
    Precision_None = 0,
    Precision_Coarse = 1,
    Precision_Fine = 2,
    Precision_Max = 3,
}



visual_shader_node_derivative_func_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

visual_shader_node_derivative_func_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_visual_shader_node_derivative_func :: proc "contextless" () -> Visual_Shader_Node_Derivative_Func {
    return cast(Visual_Shader_Node_Derivative_Func)__bindgen_gde.classdb_construct_object(visual_shader_node_derivative_func_name_ref())
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

visual_shader_node_derivative_func_set_op_type :: proc "contextless" (
    self: Visual_Shader_Node_Derivative_Func,
    type_: Visual_Shader_Node_Derivative_Func_Op_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_op_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 377800221)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_derivative_func_get_op_type :: proc "contextless" (
    self: Visual_Shader_Node_Derivative_Func,
) -> (ret: Visual_Shader_Node_Derivative_Func_Op_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_op_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3997800514)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_derivative_func_set_function :: proc "contextless" (
    self: Visual_Shader_Node_Derivative_Func,
    func_: Visual_Shader_Node_Derivative_Func_Function,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_function", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1944704156)
    }
    self := self
    func_ := func_
    args := []__bindgen_gde.TypePtr {
        &func_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_derivative_func_get_function :: proc "contextless" (
    self: Visual_Shader_Node_Derivative_Func,
) -> (ret: Visual_Shader_Node_Derivative_Func_Function) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_function", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2389093396)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

visual_shader_node_derivative_func_set_precision :: proc "contextless" (
    self: Visual_Shader_Node_Derivative_Func,
    precision_: Visual_Shader_Node_Derivative_Func_Precision,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_precision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 797270566)
    }
    self := self
    precision_ := precision_
    args := []__bindgen_gde.TypePtr {
        &precision_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_derivative_func_get_precision :: proc "contextless" (
    self: Visual_Shader_Node_Derivative_Func,
) -> (ret: Visual_Shader_Node_Derivative_Func_Precision) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_precision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3822547323)
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
visual_shader_node_derivative_func_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("VisualShaderNodeDerivativeFunc", true)
}

@(private = "file")
__class_name: String_Name