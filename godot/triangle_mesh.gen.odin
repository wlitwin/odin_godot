package godot

import __bindgen_gde "godot:gdext"

Triangle_Mesh_Constants :: enum {
}



triangle_mesh_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

triangle_mesh_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_triangle_mesh :: proc "contextless" () -> Triangle_Mesh {
    return cast(Triangle_Mesh)__bindgen_gde.classdb_construct_object(triangle_mesh_name_ref())
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

triangle_mesh_create_from_faces :: proc "contextless" (
    self: Triangle_Mesh,
    faces_: Packed_Vector3_Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_from_faces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2637816732)
    }
    self := self
    faces_ := faces_
    args := []__bindgen_gde.TypePtr {
        &faces_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

triangle_mesh_get_faces :: proc "contextless" (
    self: Triangle_Mesh,
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_faces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 497664490)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

triangle_mesh_intersect_segment :: proc "contextless" (
    self: Triangle_Mesh,
    begin_: Vector3,
    end_: Vector3,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersect_segment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3648293151)
    }
    self := self
    begin_ := begin_
    end_ := end_
    args := []__bindgen_gde.TypePtr {
        &begin_,
        &end_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

triangle_mesh_intersect_ray :: proc "contextless" (
    self: Triangle_Mesh,
    begin_: Vector3,
    dir_: Vector3,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersect_ray", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3648293151)
    }
    self := self
    begin_ := begin_
    dir_ := dir_
    args := []__bindgen_gde.TypePtr {
        &begin_,
        &dir_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
triangle_mesh_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("TriangleMesh", true)
}

@(private = "file")
__class_name: String_Name