package godot

import __bindgen_gde "godot:gdext"

Blit_Material_Constants :: enum {
}
Blit_Material_Blend_Mode :: enum int {
    Blend_Mode_Mix = 0,
    Blend_Mode_Add = 1,
    Blend_Mode_Sub = 2,
    Blend_Mode_Mul = 3,
    Blend_Mode_Disabled = 4,
}



blit_material_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

blit_material_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_blit_material :: proc "contextless" () -> Blit_Material {
    return cast(Blit_Material)__bindgen_gde.classdb_construct_object(blit_material_name_ref())
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

blit_material_set_blend_mode :: proc "contextless" (
    self: Blit_Material,
    blend_mode_: Blit_Material_Blend_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_blend_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 80206916)
    }
    self := self
    blend_mode_ := blend_mode_
    args := []__bindgen_gde.TypePtr {
        &blend_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

blit_material_get_blend_mode :: proc "contextless" (
    self: Blit_Material,
) -> (ret: Blit_Material_Blend_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_blend_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4234246416)
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
blit_material_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("BlitMaterial", true)
}

@(private = "file")
__class_name: String_Name