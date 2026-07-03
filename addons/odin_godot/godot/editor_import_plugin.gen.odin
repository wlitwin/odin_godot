package godot

import __bindgen_gde "godot:gdext"

Editor_Import_Plugin_Constants :: enum {
}



editor_import_plugin_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_import_plugin_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_import_plugin :: proc "contextless" () -> Editor_Import_Plugin {
    return cast(Editor_Import_Plugin)__bindgen_gde.classdb_construct_object(editor_import_plugin_name_ref())
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

editor_import_plugin__get_importer_name :: proc "contextless" (
    self: Editor_Import_Plugin,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_importer_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin__get_visible_name :: proc "contextless" (
    self: Editor_Import_Plugin,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_visible_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin__get_preset_count :: proc "contextless" (
    self: Editor_Import_Plugin,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_preset_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin__get_preset_name :: proc "contextless" (
    self: Editor_Import_Plugin,
    preset_index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_preset_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    preset_index_ := preset_index_
    args := []__bindgen_gde.TypePtr {
        &preset_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin__get_recognized_extensions :: proc "contextless" (
    self: Editor_Import_Plugin,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_recognized_extensions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin__get_import_options :: proc "contextless" (
    self: Editor_Import_Plugin,
    path_: String,
    preset_index_: Int,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_import_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 520498173)
    }
    self := self
    path_ := path_
    preset_index_ := preset_index_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &preset_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin__get_save_extension :: proc "contextless" (
    self: Editor_Import_Plugin,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_save_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin__get_resource_type :: proc "contextless" (
    self: Editor_Import_Plugin,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_resource_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin__get_priority :: proc "contextless" (
    self: Editor_Import_Plugin,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_priority", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin__get_import_order :: proc "contextless" (
    self: Editor_Import_Plugin,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_import_order", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin__get_format_version :: proc "contextless" (
    self: Editor_Import_Plugin,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_format_version", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin__get_option_visibility :: proc "contextless" (
    self: Editor_Import_Plugin,
    path_: String,
    option_name_: String_Name,
    options_: Dictionary,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_option_visibility", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 240466755)
    }
    self := self
    path_ := path_
    option_name_ := option_name_
    options_ := options_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &option_name_,
        &options_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin__import :: proc "contextless" (
    self: Editor_Import_Plugin,
    source_file_: String,
    save_path_: String,
    options_: Dictionary,
    platform_variants_: Typed_Array(String),
    gen_files_: Typed_Array(String),
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_import", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4108152118)
    }
    self := self
    source_file_ := source_file_
    save_path_ := save_path_
    options_ := options_
    platform_variants_ := platform_variants_
    gen_files_ := gen_files_
    args := []__bindgen_gde.TypePtr {
        &source_file_,
        &save_path_,
        &options_,
        &platform_variants_,
        &gen_files_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin__can_import_threaded :: proc "contextless" (
    self: Editor_Import_Plugin,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_can_import_threaded", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_import_plugin_append_import_external_resource :: proc "contextless" (
    self: Editor_Import_Plugin,
    path_: String,
    custom_options_: Dictionary,
    custom_importer_: String,
    generator_parameters_: Variant,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_import_external_resource", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 320493106)
    }
    self := self
    path_ := path_
    custom_options_ := custom_options_
    custom_importer_ := custom_importer_
    generator_parameters_ := generator_parameters_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &custom_options_,
        &custom_importer_,
        &generator_parameters_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_import_plugin_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorImportPlugin", true)
}

@(private = "file")
__class_name: String_Name