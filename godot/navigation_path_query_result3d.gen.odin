package godot

import __bindgen_gde "godot:gdext"

Navigation_Path_Query_Result3d_Constants :: enum {
}
Navigation_Path_Query_Result3d_Path_Segment_Type :: enum int {
    Path_Segment_Type_Region = 0,
    Path_Segment_Type_Link = 1,
}



navigation_path_query_result3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

navigation_path_query_result3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_navigation_path_query_result3d :: proc "contextless" () -> Navigation_Path_Query_Result3d {
    return cast(Navigation_Path_Query_Result3d)__bindgen_gde.classdb_construct_object(navigation_path_query_result3d_name_ref())
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

navigation_path_query_result3d_set_path :: proc "contextless" (
    self: Navigation_Path_Query_Result3d,
    path_: Packed_Vector3_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 334873810)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_result3d_get_path :: proc "contextless" (
    self: Navigation_Path_Query_Result3d,
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 497664490)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_result3d_set_path_types :: proc "contextless" (
    self: Navigation_Path_Query_Result3d,
    path_types_: Packed_Int32_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_path_types", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3614634198)
    }
    self := self
    path_types_ := path_types_
    args := []__bindgen_gde.TypePtr {
        &path_types_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_result3d_get_path_types :: proc "contextless" (
    self: Navigation_Path_Query_Result3d,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_path_types", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1930428628)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_result3d_set_path_rids :: proc "contextless" (
    self: Navigation_Path_Query_Result3d,
    path_rids_: Typed_Array(Rid),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_path_rids", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    path_rids_ := path_rids_
    args := []__bindgen_gde.TypePtr {
        &path_rids_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_result3d_get_path_rids :: proc "contextless" (
    self: Navigation_Path_Query_Result3d,
) -> (ret: Typed_Array(Rid)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_path_rids", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_result3d_set_path_owner_ids :: proc "contextless" (
    self: Navigation_Path_Query_Result3d,
    path_owner_ids_: Packed_Int64_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_path_owner_ids", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3709968205)
    }
    self := self
    path_owner_ids_ := path_owner_ids_
    args := []__bindgen_gde.TypePtr {
        &path_owner_ids_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_result3d_get_path_owner_ids :: proc "contextless" (
    self: Navigation_Path_Query_Result3d,
) -> (ret: Packed_Int64_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_path_owner_ids", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 235988956)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_result3d_set_path_length :: proc "contextless" (
    self: Navigation_Path_Query_Result3d,
    length_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_path_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    length_ := length_
    args := []__bindgen_gde.TypePtr {
        &length_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

navigation_path_query_result3d_get_path_length :: proc "contextless" (
    self: Navigation_Path_Query_Result3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_path_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

navigation_path_query_result3d_reset :: proc "contextless" (
    self: Navigation_Path_Query_Result3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reset", true)
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
navigation_path_query_result3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("NavigationPathQueryResult3D", true)
}

@(private = "file")
__class_name: String_Name