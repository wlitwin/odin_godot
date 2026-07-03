package godot

import __bindgen_gde "godot:gdext"

Editor_File_System_Import_Format_Support_Query_Constants :: enum {
}



editor_file_system_import_format_support_query_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_file_system_import_format_support_query_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_file_system_import_format_support_query :: proc "contextless" () -> Editor_File_System_Import_Format_Support_Query {
    return cast(Editor_File_System_Import_Format_Support_Query)__bindgen_gde.classdb_construct_object(editor_file_system_import_format_support_query_name_ref())
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

editor_file_system_import_format_support_query__is_active :: proc "contextless" (
    self: Editor_File_System_Import_Format_Support_Query,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_file_system_import_format_support_query__get_file_extensions :: proc "contextless" (
    self: Editor_File_System_Import_Format_Support_Query,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_file_extensions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_file_system_import_format_support_query__query :: proc "contextless" (
    self: Editor_File_System_Import_Format_Support_Query,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_query", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
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
editor_file_system_import_format_support_query_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorFileSystemImportFormatSupportQuery", true)
}

@(private = "file")
__class_name: String_Name