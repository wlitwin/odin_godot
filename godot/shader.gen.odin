package godot

import __bindgen_gde "godot:gdext"

Shader_Constants :: enum {
}
Shader_Mode :: enum int {
    Mode_Spatial = 0,
    Mode_Canvas_Item = 1,
    Mode_Particles = 2,
    Mode_Sky = 3,
    Mode_Fog = 4,
    Mode_Texture_Blit = 5,
}



shader_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

shader_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_shader :: proc "contextless" () -> Shader {
    return cast(Shader)__bindgen_gde.classdb_construct_object(shader_name_ref())
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

shader_get_mode :: proc "contextless" (
    self: Shader,
) -> (ret: Shader_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3392948163)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

shader_set_code :: proc "contextless" (
    self: Shader,
    code_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_code", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    code_ := code_
    args := []__bindgen_gde.TypePtr {
        &code_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

shader_get_code :: proc "contextless" (
    self: Shader,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_code", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

shader_set_default_texture_parameter :: proc "contextless" (
    self: Shader,
    name_: String_Name,
    texture_: Texture,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_default_texture_parameter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3850209648)
    }
    self := self
    name_ := name_
    texture_ := texture_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &texture_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

shader_get_default_texture_parameter :: proc "contextless" (
    self: Shader,
    name_: String_Name,
    index_: Int,
) -> (ret: Texture) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_default_texture_parameter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4213877425)
    }
    self := self
    name_ := name_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

shader_get_shader_uniform_list :: proc "contextless" (
    self: Shader,
    get_groups_: Bool,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shader_uniform_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1230511656)
    }
    self := self
    get_groups_ := get_groups_
    args := []__bindgen_gde.TypePtr {
        &get_groups_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

shader_inspect_native_shader_code :: proc "contextless" (
    self: Shader,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("inspect_native_shader_code", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
shader_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Shader", true)
}

@(private = "file")
__class_name: String_Name