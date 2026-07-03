package godot

import __bindgen_gde "godot:gdext"

Csg_Primitive3d_Constants :: enum {
}



csg_primitive3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

csg_primitive3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_csg_primitive3d :: proc "contextless" () -> Csg_Primitive3d {
    return __bindgen_gde.classdb_construct_object(csg_primitive3d_name_ref())
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

csg_primitive3d_set_flip_faces :: proc "contextless" (
    self: Csg_Primitive3d,
    flip_faces_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flip_faces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    flip_faces_ := flip_faces_
    args := []__bindgen_gde.TypePtr {
        &flip_faces_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

csg_primitive3d_get_flip_faces :: proc "contextless" (
    self: Csg_Primitive3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_flip_faces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
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
csg_primitive3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("CSGPrimitive3D", true)
}

@(private = "file")
__class_name: String_Name