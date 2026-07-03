package godot

import __bindgen_gde "godot:gdext"

Visual_Shader_Node_Float_Func_Constants :: enum {
}
Visual_Shader_Node_Float_Func_Function :: enum int {
    Func_Sin = 0,
    Func_Cos = 1,
    Func_Tan = 2,
    Func_Asin = 3,
    Func_Acos = 4,
    Func_Atan = 5,
    Func_Sinh = 6,
    Func_Cosh = 7,
    Func_Tanh = 8,
    Func_Log = 9,
    Func_Exp = 10,
    Func_Sqrt = 11,
    Func_Abs = 12,
    Func_Sign = 13,
    Func_Floor = 14,
    Func_Round = 15,
    Func_Ceil = 16,
    Func_Fract = 17,
    Func_Saturate = 18,
    Func_Negate = 19,
    Func_Acosh = 20,
    Func_Asinh = 21,
    Func_Atanh = 22,
    Func_Degrees = 23,
    Func_Exp2 = 24,
    Func_Inverse_Sqrt = 25,
    Func_Log2 = 26,
    Func_Radians = 27,
    Func_Reciprocal = 28,
    Func_Roundeven = 29,
    Func_Trunc = 30,
    Func_Oneminus = 31,
    Func_Max = 32,
}



visual_shader_node_float_func_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

visual_shader_node_float_func_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_visual_shader_node_float_func :: proc "contextless" () -> Visual_Shader_Node_Float_Func {
    return cast(Visual_Shader_Node_Float_Func)__bindgen_gde.classdb_construct_object(visual_shader_node_float_func_name_ref())
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

visual_shader_node_float_func_set_function :: proc "contextless" (
    self: Visual_Shader_Node_Float_Func,
    func_: Visual_Shader_Node_Float_Func_Function,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_function", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 536026177)
    }
    self := self
    func_ := func_
    args := []__bindgen_gde.TypePtr {
        &func_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

visual_shader_node_float_func_get_function :: proc "contextless" (
    self: Visual_Shader_Node_Float_Func,
) -> (ret: Visual_Shader_Node_Float_Func_Function) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_function", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2033948868)
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
visual_shader_node_float_func_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("VisualShaderNodeFloatFunc", true)
}

@(private = "file")
__class_name: String_Name