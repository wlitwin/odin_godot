package godot

import __bindgen_gde "godot:gdext"

Rd_Pipeline_Shader_Constants :: enum {
}



rd_pipeline_shader_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

rd_pipeline_shader_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_rd_pipeline_shader :: proc "contextless" () -> Rd_Pipeline_Shader {
    return cast(Rd_Pipeline_Shader)__bindgen_gde.classdb_construct_object(rd_pipeline_shader_name_ref())
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

rd_pipeline_shader_set_shader :: proc "contextless" (
    self: Rd_Pipeline_Shader,
    p_member_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shader", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    p_member_ := p_member_
    args := []__bindgen_gde.TypePtr {
        &p_member_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_shader_get_shader :: proc "contextless" (
    self: Rd_Pipeline_Shader,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shader", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2944877500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_pipeline_shader_set_specialization_constants :: proc "contextless" (
    self: Rd_Pipeline_Shader,
    specialization_constants_: Typed_Array(Rd_Pipeline_Specialization_Constant),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_specialization_constants", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    specialization_constants_ := specialization_constants_
    args := []__bindgen_gde.TypePtr {
        &specialization_constants_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_pipeline_shader_get_specialization_constants :: proc "contextless" (
    self: Rd_Pipeline_Shader,
) -> (ret: Typed_Array(Rd_Pipeline_Specialization_Constant)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_specialization_constants", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
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
rd_pipeline_shader_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("RDPipelineShader", true)
}

@(private = "file")
__class_name: String_Name