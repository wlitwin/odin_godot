package godot

import __bindgen_gde "godot:gdext"

Rd_Shader_Source_Constants :: enum {
}



rd_shader_source_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

rd_shader_source_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_rd_shader_source :: proc "contextless" () -> Rd_Shader_Source {
    return cast(Rd_Shader_Source)__bindgen_gde.classdb_construct_object(rd_shader_source_name_ref())
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

rd_shader_source_set_stage_source :: proc "contextless" (
    self: Rd_Shader_Source,
    stage_: Rendering_Device_Shader_Stage,
    source_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stage_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 620821314)
    }
    self := self
    stage_ := stage_
    source_ := source_
    args := []__bindgen_gde.TypePtr {
        &stage_,
        &source_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_shader_source_get_stage_source :: proc "contextless" (
    self: Rd_Shader_Source,
    stage_: Rendering_Device_Shader_Stage,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stage_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3354920045)
    }
    self := self
    stage_ := stage_
    args := []__bindgen_gde.TypePtr {
        &stage_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_shader_source_set_language :: proc "contextless" (
    self: Rd_Shader_Source,
    language_: Rendering_Device_Shader_Language,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_language", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3422186742)
    }
    self := self
    language_ := language_
    args := []__bindgen_gde.TypePtr {
        &language_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_shader_source_get_language :: proc "contextless" (
    self: Rd_Shader_Source,
) -> (ret: Rendering_Device_Shader_Language) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_language", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1063538261)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
rd_shader_source_get_source_vertex :: proc "contextless" (self: Rd_Shader_Source) -> String {
    return rd_shader_source_get_stage_source(self, Rendering_Device_Shader_Stage(0))
}
rd_shader_source_set_source_vertex :: proc "contextless" (self: Rd_Shader_Source, value: String) {
    rd_shader_source_set_stage_source(self, Rendering_Device_Shader_Stage(0), value)
}
rd_shader_source_get_source_fragment :: proc "contextless" (self: Rd_Shader_Source) -> String {
    return rd_shader_source_get_stage_source(self, Rendering_Device_Shader_Stage(1))
}
rd_shader_source_set_source_fragment :: proc "contextless" (self: Rd_Shader_Source, value: String) {
    rd_shader_source_set_stage_source(self, Rendering_Device_Shader_Stage(1), value)
}
rd_shader_source_get_source_tesselation_control :: proc "contextless" (self: Rd_Shader_Source) -> String {
    return rd_shader_source_get_stage_source(self, Rendering_Device_Shader_Stage(2))
}
rd_shader_source_set_source_tesselation_control :: proc "contextless" (self: Rd_Shader_Source, value: String) {
    rd_shader_source_set_stage_source(self, Rendering_Device_Shader_Stage(2), value)
}
rd_shader_source_get_source_tesselation_evaluation :: proc "contextless" (self: Rd_Shader_Source) -> String {
    return rd_shader_source_get_stage_source(self, Rendering_Device_Shader_Stage(3))
}
rd_shader_source_set_source_tesselation_evaluation :: proc "contextless" (self: Rd_Shader_Source, value: String) {
    rd_shader_source_set_stage_source(self, Rendering_Device_Shader_Stage(3), value)
}
rd_shader_source_get_source_compute :: proc "contextless" (self: Rd_Shader_Source) -> String {
    return rd_shader_source_get_stage_source(self, Rendering_Device_Shader_Stage(4))
}
rd_shader_source_set_source_compute :: proc "contextless" (self: Rd_Shader_Source, value: String) {
    rd_shader_source_set_stage_source(self, Rendering_Device_Shader_Stage(4), value)
}
rd_shader_source_get_source_raygen :: proc "contextless" (self: Rd_Shader_Source) -> String {
    return rd_shader_source_get_stage_source(self, Rendering_Device_Shader_Stage(5))
}
rd_shader_source_set_source_raygen :: proc "contextless" (self: Rd_Shader_Source, value: String) {
    rd_shader_source_set_stage_source(self, Rendering_Device_Shader_Stage(5), value)
}
rd_shader_source_get_source_any_hit :: proc "contextless" (self: Rd_Shader_Source) -> String {
    return rd_shader_source_get_stage_source(self, Rendering_Device_Shader_Stage(6))
}
rd_shader_source_set_source_any_hit :: proc "contextless" (self: Rd_Shader_Source, value: String) {
    rd_shader_source_set_stage_source(self, Rendering_Device_Shader_Stage(6), value)
}
rd_shader_source_get_source_closest_hit :: proc "contextless" (self: Rd_Shader_Source) -> String {
    return rd_shader_source_get_stage_source(self, Rendering_Device_Shader_Stage(7))
}
rd_shader_source_set_source_closest_hit :: proc "contextless" (self: Rd_Shader_Source, value: String) {
    rd_shader_source_set_stage_source(self, Rendering_Device_Shader_Stage(7), value)
}
rd_shader_source_get_source_miss :: proc "contextless" (self: Rd_Shader_Source) -> String {
    return rd_shader_source_get_stage_source(self, Rendering_Device_Shader_Stage(8))
}
rd_shader_source_set_source_miss :: proc "contextless" (self: Rd_Shader_Source, value: String) {
    rd_shader_source_set_stage_source(self, Rendering_Device_Shader_Stage(8), value)
}
rd_shader_source_get_source_intersection :: proc "contextless" (self: Rd_Shader_Source) -> String {
    return rd_shader_source_get_stage_source(self, Rendering_Device_Shader_Stage(9))
}
rd_shader_source_set_source_intersection :: proc "contextless" (self: Rd_Shader_Source, value: String) {
    rd_shader_source_set_stage_source(self, Rendering_Device_Shader_Stage(9), value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
rd_shader_source_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("RDShaderSource", true)
}

@(private = "file")
__class_name: String_Name