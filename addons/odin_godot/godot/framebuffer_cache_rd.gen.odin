package godot

import __bindgen_gde "godot:gdext"

Framebuffer_Cache_Rd_Constants :: enum {
}



framebuffer_cache_rd_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

framebuffer_cache_rd_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_framebuffer_cache_rd :: proc "contextless" () -> Framebuffer_Cache_Rd {
    return __bindgen_gde.classdb_construct_object(framebuffer_cache_rd_name_ref())
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
framebuffer_cache_rd_get_cache_multipass :: proc "contextless" (
    textures_: Typed_Array(Rid),
    passes_: Typed_Array(Rd_Framebuffer_Pass),
    views_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cache_multipass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3437881813)
    }
    textures_ := textures_
    passes_ := passes_
    views_ := views_
    args := []__bindgen_gde.TypePtr {
        &textures_,
        &passes_,
        &views_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}



// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
framebuffer_cache_rd_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("FramebufferCacheRD", true)
}

@(private = "file")
__class_name: String_Name