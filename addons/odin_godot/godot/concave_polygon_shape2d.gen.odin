package godot

import __bindgen_gde "godot:gdext"

Concave_Polygon_Shape2d_Constants :: enum {
}



concave_polygon_shape2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

concave_polygon_shape2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_concave_polygon_shape2d :: proc "contextless" () -> Concave_Polygon_Shape2d {
    return cast(Concave_Polygon_Shape2d)__bindgen_gde.classdb_construct_object(concave_polygon_shape2d_name_ref())
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

concave_polygon_shape2d_set_segments :: proc "contextless" (
    self: Concave_Polygon_Shape2d,
    segments_: Packed_Vector2_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_segments", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1509147220)
    }
    self := self
    segments_ := segments_
    args := []__bindgen_gde.TypePtr {
        &segments_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

concave_polygon_shape2d_get_segments :: proc "contextless" (
    self: Concave_Polygon_Shape2d,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_segments", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2961356807)
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
concave_polygon_shape2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ConcavePolygonShape2D", true)
}

@(private = "file")
__class_name: String_Name