package godot

import __bindgen_gde "godot:gdext"

Config_File_Constants :: enum {
}



config_file_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

config_file_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_config_file :: proc "contextless" () -> Config_File {
    return cast(Config_File)__bindgen_gde.classdb_construct_object(config_file_name_ref())
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

config_file_set_value :: proc "contextless" (
    self: Config_File,
    section_: String,
    key_: String,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2504492430)
    }
    self := self
    section_ := section_
    key_ := key_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &section_,
        &key_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

config_file_get_value :: proc "contextless" (
    self: Config_File,
    section_: String,
    key_: String,
    default_: Variant,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 89809366)
    }
    self := self
    section_ := section_
    key_ := key_
    default_ := default_
    args := []__bindgen_gde.TypePtr {
        &section_,
        &key_,
        &default_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

config_file_has_section :: proc "contextless" (
    self: Config_File,
    section_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_section", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    section_ := section_
    args := []__bindgen_gde.TypePtr {
        &section_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

config_file_has_section_key :: proc "contextless" (
    self: Config_File,
    section_: String,
    key_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_section_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 820780508)
    }
    self := self
    section_ := section_
    key_ := key_
    args := []__bindgen_gde.TypePtr {
        &section_,
        &key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

config_file_get_sections :: proc "contextless" (
    self: Config_File,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sections", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

config_file_get_section_keys :: proc "contextless" (
    self: Config_File,
    section_: String,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_section_keys", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4291131558)
    }
    self := self
    section_ := section_
    args := []__bindgen_gde.TypePtr {
        &section_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

config_file_erase_section :: proc "contextless" (
    self: Config_File,
    section_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase_section", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    section_ := section_
    args := []__bindgen_gde.TypePtr {
        &section_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

config_file_erase_section_key :: proc "contextless" (
    self: Config_File,
    section_: String,
    key_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase_section_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3186203200)
    }
    self := self
    section_ := section_
    key_ := key_
    args := []__bindgen_gde.TypePtr {
        &section_,
        &key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

config_file_load :: proc "contextless" (
    self: Config_File,
    path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load", true)
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

config_file_parse :: proc "contextless" (
    self: Config_File,
    data_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("parse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166001499)
    }
    self := self
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

config_file_save :: proc "contextless" (
    self: Config_File,
    path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save", true)
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

config_file_encode_to_text :: proc "contextless" (
    self: Config_File,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encode_to_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

config_file_load_encrypted :: proc "contextless" (
    self: Config_File,
    path_: String,
    key_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_encrypted", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 887037711)
    }
    self := self
    path_ := path_
    key_ := key_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

config_file_load_encrypted_pass :: proc "contextless" (
    self: Config_File,
    path_: String,
    password_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("load_encrypted_pass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 852856452)
    }
    self := self
    path_ := path_
    password_ := password_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &password_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

config_file_save_encrypted :: proc "contextless" (
    self: Config_File,
    path_: String,
    key_: Packed_Byte_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_encrypted", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 887037711)
    }
    self := self
    path_ := path_
    key_ := key_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

config_file_save_encrypted_pass :: proc "contextless" (
    self: Config_File,
    path_: String,
    password_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_encrypted_pass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 852856452)
    }
    self := self
    path_ := path_
    password_ := password_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &password_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

config_file_clear :: proc "contextless" (
    self: Config_File,
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


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
config_file_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ConfigFile", true)
}

@(private = "file")
__class_name: String_Name