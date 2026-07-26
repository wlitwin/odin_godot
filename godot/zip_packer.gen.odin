package godot

import __bindgen_gde "godot:gdext"

Zip_Packer_Constants :: enum {
}
Zip_Packer_Zip_Append :: enum int {
    Append_Create = 0,
    Append_Createafter = 1,
    Append_Addinzip = 2,
}
Zip_Packer_Compression_Level :: enum int {
    Compression_Default = -1,
    Compression_None = 0,
    Compression_Fast = 1,
    Compression_Best = 9,
}



zip_packer_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

zip_packer_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_zip_packer :: proc "contextless" () -> Zip_Packer {
    return cast(Zip_Packer)__bindgen_gde.classdb_construct_object(zip_packer_name_ref())
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

zip_packer_open :: proc "contextless" (
    self: Zip_Packer,
    path_: String,
    append_: Zip_Packer_Zip_Append,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("open", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1936816515)
    }
    self := self
    path_ := path_
    append_ := append_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &append_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

zip_packer_set_compression_level :: proc "contextless" (
    self: Zip_Packer,
    compression_level_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_compression_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    compression_level_ := compression_level_
    args := []__bindgen_gde.TypePtr {
        &compression_level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

zip_packer_get_compression_level :: proc "contextless" (
    self: Zip_Packer,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_compression_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

zip_packer_add_directory :: proc "contextless" (
    self: Zip_Packer,
    path_: String,
    permissions_: File_Access_Unix_Permission_Flags,
    modified_time_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_directory", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 934773537)
    }
    self := self
    path_ := path_
    permissions_ := permissions_
    modified_time_ := modified_time_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &permissions_,
        &modified_time_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

zip_packer_start_file :: proc "contextless" (
    self: Zip_Packer,
    path_: String,
    permissions_: File_Access_Unix_Permission_Flags,
    modified_time_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("start_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4260848715)
    }
    self := self
    path_ := path_
    permissions_ := permissions_
    modified_time_ := modified_time_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &permissions_,
        &modified_time_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

zip_packer_write_file :: proc "contextless" (
    self: Zip_Packer,
    data_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("write_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 680677267)
    }
    self := self
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

zip_packer_close_file :: proc "contextless" (
    self: Zip_Packer,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("close_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

zip_packer_close :: proc "contextless" (
    self: Zip_Packer,
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


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
zip_packer_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ZIPPacker", true)
}

@(private = "file")
__class_name: String_Name