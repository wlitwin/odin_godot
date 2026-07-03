package godot

import __bindgen_gde "godot:gdext"

Zip_Reader_Constants :: enum {
}



zip_reader_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

zip_reader_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_zip_reader :: proc "contextless" () -> Zip_Reader {
    return cast(Zip_Reader)__bindgen_gde.classdb_construct_object(zip_reader_name_ref())
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

zip_reader_open :: proc "contextless" (
    self: Zip_Reader,
    path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("open", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166001499)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

zip_reader_close :: proc "contextless" (
    self: Zip_Reader,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("close", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

zip_reader_get_files :: proc "contextless" (
    self: Zip_Reader,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_files", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2981934095)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

zip_reader_read_file :: proc "contextless" (
    self: Zip_Reader,
    path_: String,
    case_sensitive_: Bool,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("read_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 740857591)
    }
    self := self
    path_ := path_
    case_sensitive_ := case_sensitive_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &case_sensitive_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

zip_reader_file_exists :: proc "contextless" (
    self: Zip_Reader,
    path_: String,
    case_sensitive_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("file_exists", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 35364943)
    }
    self := self
    path_ := path_
    case_sensitive_ := case_sensitive_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &case_sensitive_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

zip_reader_get_compression_level :: proc "contextless" (
    self: Zip_Reader,
    path_: String,
    case_sensitive_: Bool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_compression_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3694577386)
    }
    self := self
    path_ := path_
    case_sensitive_ := case_sensitive_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &case_sensitive_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
zip_reader_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ZIPReader", true)
}

@(private = "file")
__class_name: String_Name