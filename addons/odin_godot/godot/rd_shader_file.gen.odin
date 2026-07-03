package godot

import __bindgen_gde "godot:gdext"

Rd_Shader_File_Constants :: enum {
}



rd_shader_file_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

rd_shader_file_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_rd_shader_file :: proc "contextless" () -> Rd_Shader_File {
    return cast(Rd_Shader_File)__bindgen_gde.classdb_construct_object(rd_shader_file_name_ref())
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

rd_shader_file_set_bytecode :: proc "contextless" (
    self: Rd_Shader_File,
    bytecode_: Rd_Shader_Spirv,
    version_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bytecode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1526857008)
    }
    self := self
    bytecode_ := bytecode_
    version_ := version_
    args := []__bindgen_gde.TypePtr {
        &bytecode_,
        &version_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_shader_file_get_spirv :: proc "contextless" (
    self: Rd_Shader_File,
    version_: String_Name,
) -> (ret: Rd_Shader_Spirv) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_spirv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2689310080)
    }
    self := self
    version_ := version_
    args := []__bindgen_gde.TypePtr {
        &version_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_shader_file_get_version_list :: proc "contextless" (
    self: Rd_Shader_File,
) -> (ret: Typed_Array(String_Name)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_version_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rd_shader_file_set_base_error :: proc "contextless" (
    self: Rd_Shader_File,
    error_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_base_error", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    error_ := error_
    args := []__bindgen_gde.TypePtr {
        &error_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rd_shader_file_get_base_error :: proc "contextless" (
    self: Rd_Shader_File,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_base_error", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
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
rd_shader_file_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("RDShaderFile", true)
}

@(private = "file")
__class_name: String_Name