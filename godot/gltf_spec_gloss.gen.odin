package godot

import __bindgen_gde "godot:gdext"

Gltf_Spec_Gloss_Constants :: enum {
}



gltf_spec_gloss_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

gltf_spec_gloss_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_gltf_spec_gloss :: proc "contextless" () -> Gltf_Spec_Gloss {
    return cast(Gltf_Spec_Gloss)__bindgen_gde.classdb_construct_object(gltf_spec_gloss_name_ref())
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

gltf_spec_gloss_get_diffuse_img :: proc "contextless" (
    self: Gltf_Spec_Gloss,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_diffuse_img", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 564927088)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_spec_gloss_set_diffuse_img :: proc "contextless" (
    self: Gltf_Spec_Gloss,
    diffuse_img_: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_diffuse_img", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 532598488)
    }
    self := self
    diffuse_img_ := diffuse_img_
    args := []__bindgen_gde.TypePtr {
        &diffuse_img_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_spec_gloss_get_diffuse_factor :: proc "contextless" (
    self: Gltf_Spec_Gloss,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_diffuse_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3200896285)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_spec_gloss_set_diffuse_factor :: proc "contextless" (
    self: Gltf_Spec_Gloss,
    diffuse_factor_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_diffuse_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    diffuse_factor_ := diffuse_factor_
    args := []__bindgen_gde.TypePtr {
        &diffuse_factor_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_spec_gloss_get_gloss_factor :: proc "contextless" (
    self: Gltf_Spec_Gloss,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gloss_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_spec_gloss_set_gloss_factor :: proc "contextless" (
    self: Gltf_Spec_Gloss,
    gloss_factor_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gloss_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    gloss_factor_ := gloss_factor_
    args := []__bindgen_gde.TypePtr {
        &gloss_factor_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_spec_gloss_get_specular_factor :: proc "contextless" (
    self: Gltf_Spec_Gloss,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_specular_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3200896285)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_spec_gloss_set_specular_factor :: proc "contextless" (
    self: Gltf_Spec_Gloss,
    specular_factor_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_specular_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    specular_factor_ := specular_factor_
    args := []__bindgen_gde.TypePtr {
        &specular_factor_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_spec_gloss_get_spec_gloss_img :: proc "contextless" (
    self: Gltf_Spec_Gloss,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_spec_gloss_img", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 564927088)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_spec_gloss_set_spec_gloss_img :: proc "contextless" (
    self: Gltf_Spec_Gloss,
    spec_gloss_img_: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_spec_gloss_img", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 532598488)
    }
    self := self
    spec_gloss_img_ := spec_gloss_img_
    args := []__bindgen_gde.TypePtr {
        &spec_gloss_img_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
gltf_spec_gloss_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GLTFSpecGloss", true)
}

@(private = "file")
__class_name: String_Name