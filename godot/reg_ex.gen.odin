package godot

import __bindgen_gde "godot:gdext"

Reg_Ex_Constants :: enum {
}



reg_ex_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

reg_ex_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_reg_ex :: proc "contextless" () -> Reg_Ex {
    return cast(Reg_Ex)__bindgen_gde.classdb_construct_object(reg_ex_name_ref())
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
reg_ex_create_from_string :: proc "contextless" (
    pattern_: String,
    show_error_: Bool,
) -> (ret: Reg_Ex) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_from_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4249111514)
    }
    pattern_ := pattern_
    show_error_ := show_error_
    args := []__bindgen_gde.TypePtr {
        &pattern_,
        &show_error_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}


reg_ex_clear :: proc "contextless" (
    self: Reg_Ex,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

reg_ex_compile :: proc "contextless" (
    self: Reg_Ex,
    pattern_: String,
    show_error_: Bool,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3565188097)
    }
    self := self
    pattern_ := pattern_
    show_error_ := show_error_
    args := []__bindgen_gde.TypePtr {
        &pattern_,
        &show_error_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

reg_ex_search :: proc "contextless" (
    self: Reg_Ex,
    subject_: String,
    offset_: Int,
    end_: Int,
) -> (ret: Reg_Ex_Match) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("search", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3365977994)
    }
    self := self
    subject_ := subject_
    offset_ := offset_
    end_ := end_
    args := []__bindgen_gde.TypePtr {
        &subject_,
        &offset_,
        &end_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

reg_ex_search_all :: proc "contextless" (
    self: Reg_Ex,
    subject_: String,
    offset_: Int,
    end_: Int,
) -> (ret: Typed_Array(Reg_Ex_Match)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("search_all", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 849021363)
    }
    self := self
    subject_ := subject_
    offset_ := offset_
    end_ := end_
    args := []__bindgen_gde.TypePtr {
        &subject_,
        &offset_,
        &end_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

reg_ex_sub :: proc "contextless" (
    self: Reg_Ex,
    subject_: String,
    replacement_: String,
    all_: Bool,
    offset_: Int,
    end_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sub", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 54019702)
    }
    self := self
    subject_ := subject_
    replacement_ := replacement_
    all_ := all_
    offset_ := offset_
    end_ := end_
    args := []__bindgen_gde.TypePtr {
        &subject_,
        &replacement_,
        &all_,
        &offset_,
        &end_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

reg_ex_is_valid :: proc "contextless" (
    self: Reg_Ex,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

reg_ex_get_pattern :: proc "contextless" (
    self: Reg_Ex,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pattern", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

reg_ex_get_group_count :: proc "contextless" (
    self: Reg_Ex,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_group_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

reg_ex_get_names :: proc "contextless" (
    self: Reg_Ex,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_names", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
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
reg_ex_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("RegEx", true)
}

@(private = "file")
__class_name: String_Name