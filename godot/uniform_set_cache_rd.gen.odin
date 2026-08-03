package godot

import __bindgen_gde "godot:gdext"

Uniform_Set_Cache_Rd_Constants :: enum {
}



uniform_set_cache_rd_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

uniform_set_cache_rd_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_uniform_set_cache_rd :: proc "contextless" () -> Uniform_Set_Cache_Rd {
    return cast(Uniform_Set_Cache_Rd)__bindgen_gde.classdb_construct_object(uniform_set_cache_rd_name_ref())
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
uniform_set_cache_rd_get_cache :: proc "contextless" (
    shader_: Rid,
    set_: Int,
    uniforms_: Typed_Array(Rd_Uniform),
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cache", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 658571723)
    }
    shader_ := shader_
    set_ := set_
    uniforms_ := uniforms_
    args := []__bindgen_gde.TypePtr {
        &shader_,
        &set_,
        &uniforms_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}



// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
uniform_set_cache_rd_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("UniformSetCacheRD", true)
}

@(private = "file")
__class_name: String_Name