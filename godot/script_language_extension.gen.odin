package godot

import __bindgen_gde "godot:gdext"

Script_Language_Extension_Constants :: enum {
}
Script_Language_Extension_Lookup_Result_Type :: enum int {
    Lookup_Result_Script_Location = 0,
    Lookup_Result_Class = 1,
    Lookup_Result_Class_Constant = 2,
    Lookup_Result_Class_Property = 3,
    Lookup_Result_Class_Method = 4,
    Lookup_Result_Class_Signal = 5,
    Lookup_Result_Class_Enum = 6,
    Lookup_Result_Class_Tbd_Globalscope = 7,
    Lookup_Result_Class_Annotation = 8,
    Lookup_Result_Local_Constant = 9,
    Lookup_Result_Local_Variable = 10,
    Lookup_Result_Max = 11,
}
Script_Language_Extension_Code_Completion_Location :: enum int {
    Location_Local = 0,
    Location_Parent_Mask = 256,
    Location_Other_User_Code = 512,
    Location_Other = 1024,
}
Script_Language_Extension_Code_Completion_Kind :: enum int {
    Code_Completion_Kind_Class = 0,
    Code_Completion_Kind_Function = 1,
    Code_Completion_Kind_Signal = 2,
    Code_Completion_Kind_Variable = 3,
    Code_Completion_Kind_Member = 4,
    Code_Completion_Kind_Enum = 5,
    Code_Completion_Kind_Constant = 6,
    Code_Completion_Kind_Node_Path = 7,
    Code_Completion_Kind_File_Path = 8,
    Code_Completion_Kind_Plain_Text = 9,
    Code_Completion_Kind_Keyword = 10,
    Code_Completion_Kind_Max = 11,
}



script_language_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

script_language_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_script_language_extension :: proc "contextless" () -> Script_Language_Extension {
    return cast(Script_Language_Extension)__bindgen_gde.classdb_construct_object(script_language_extension_name_ref())
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

script_language_extension__get_name :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__init :: proc "contextless" (
    self: Script_Language_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_init", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__get_type :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__get_extension :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__finish :: proc "contextless" (
    self: Script_Language_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_finish", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__get_reserved_words :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_reserved_words", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__is_control_flow_keyword :: proc "contextless" (
    self: Script_Language_Extension,
    keyword_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_control_flow_keyword", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    keyword_ := keyword_
    args := []__bindgen_gde.TypePtr {
        &keyword_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__get_comment_delimiters :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_comment_delimiters", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__get_doc_comment_delimiters :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_doc_comment_delimiters", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__get_string_delimiters :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_string_delimiters", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__make_template :: proc "contextless" (
    self: Script_Language_Extension,
    template_: String,
    class_name_: String,
    base_class_name_: String,
) -> (ret: Script) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_make_template", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3583744548)
    }
    self := self
    template_ := template_
    class_name_ := class_name_
    base_class_name_ := base_class_name_
    args := []__bindgen_gde.TypePtr {
        &template_,
        &class_name_,
        &base_class_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__get_built_in_templates :: proc "contextless" (
    self: Script_Language_Extension,
    object_: String_Name,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_built_in_templates", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3147814860)
    }
    self := self
    object_ := object_
    args := []__bindgen_gde.TypePtr {
        &object_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__is_using_templates :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_using_templates", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__validate :: proc "contextless" (
    self: Script_Language_Extension,
    script_: String,
    path_: String,
    validate_functions_: Bool,
    validate_errors_: Bool,
    validate_warnings_: Bool,
    validate_safe_lines_: Bool,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_validate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1697887509)
    }
    self := self
    script_ := script_
    path_ := path_
    validate_functions_ := validate_functions_
    validate_errors_ := validate_errors_
    validate_warnings_ := validate_warnings_
    validate_safe_lines_ := validate_safe_lines_
    args := []__bindgen_gde.TypePtr {
        &script_,
        &path_,
        &validate_functions_,
        &validate_errors_,
        &validate_warnings_,
        &validate_safe_lines_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__validate_path :: proc "contextless" (
    self: Script_Language_Extension,
    path_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_validate_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3135753539)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__create_script :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Object) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_create_script", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1981248198)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__has_named_classes :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_has_named_classes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__supports_builtin_mode :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_supports_builtin_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__supports_documentation :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_supports_documentation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__can_inherit_from_file :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_can_inherit_from_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__find_function :: proc "contextless" (
    self: Script_Language_Extension,
    function_: String,
    code_: String,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_find_function", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878152881)
    }
    self := self
    function_ := function_
    code_ := code_
    args := []__bindgen_gde.TypePtr {
        &function_,
        &code_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__make_function :: proc "contextless" (
    self: Script_Language_Extension,
    class_name_: String,
    function_name_: String,
    function_args_: Packed_String_Array,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_make_function", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1243061914)
    }
    self := self
    class_name_ := class_name_
    function_name_ := function_name_
    function_args_ := function_args_
    args := []__bindgen_gde.TypePtr {
        &class_name_,
        &function_name_,
        &function_args_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__can_make_function :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_can_make_function", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__open_in_external_editor :: proc "contextless" (
    self: Script_Language_Extension,
    script_: Script,
    line_: Int,
    column_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_open_in_external_editor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 552845695)
    }
    self := self
    script_ := script_
    line_ := line_
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &script_,
        &line_,
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__overrides_external_editor :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_overrides_external_editor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__preferred_file_name_casing :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Script_Language_Script_Name_Casing) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_preferred_file_name_casing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2969522789)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__complete_code :: proc "contextless" (
    self: Script_Language_Extension,
    code_: String,
    path_: String,
    owner_: Object,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_complete_code", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 950756616)
    }
    self := self
    code_ := code_
    path_ := path_
    owner_ := owner_
    args := []__bindgen_gde.TypePtr {
        &code_,
        &path_,
        &owner_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__lookup_code :: proc "contextless" (
    self: Script_Language_Extension,
    code_: String,
    symbol_: String,
    path_: String,
    owner_: Object,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_lookup_code", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3143837309)
    }
    self := self
    code_ := code_
    symbol_ := symbol_
    path_ := path_
    owner_ := owner_
    args := []__bindgen_gde.TypePtr {
        &code_,
        &symbol_,
        &path_,
        &owner_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__auto_indent_code :: proc "contextless" (
    self: Script_Language_Extension,
    code_: String,
    from_line_: Int,
    to_line_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_auto_indent_code", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2531480354)
    }
    self := self
    code_ := code_
    from_line_ := from_line_
    to_line_ := to_line_
    args := []__bindgen_gde.TypePtr {
        &code_,
        &from_line_,
        &to_line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__add_global_constant :: proc "contextless" (
    self: Script_Language_Extension,
    name_: String_Name,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_add_global_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3776071444)
    }
    self := self
    name_ := name_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__add_named_global_constant :: proc "contextless" (
    self: Script_Language_Extension,
    name_: String_Name,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_add_named_global_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3776071444)
    }
    self := self
    name_ := name_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__remove_named_global_constant :: proc "contextless" (
    self: Script_Language_Extension,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_remove_named_global_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__thread_enter :: proc "contextless" (
    self: Script_Language_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_thread_enter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__thread_exit :: proc "contextless" (
    self: Script_Language_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_thread_exit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__debug_get_error :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_debug_get_error", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__debug_get_stack_level_count :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_debug_get_stack_level_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__debug_get_stack_level_line :: proc "contextless" (
    self: Script_Language_Extension,
    level_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_debug_get_stack_level_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    level_ := level_
    args := []__bindgen_gde.TypePtr {
        &level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__debug_get_stack_level_function :: proc "contextless" (
    self: Script_Language_Extension,
    level_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_debug_get_stack_level_function", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    level_ := level_
    args := []__bindgen_gde.TypePtr {
        &level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__debug_get_stack_level_source :: proc "contextless" (
    self: Script_Language_Extension,
    level_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_debug_get_stack_level_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    level_ := level_
    args := []__bindgen_gde.TypePtr {
        &level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__debug_get_stack_level_locals :: proc "contextless" (
    self: Script_Language_Extension,
    level_: Int,
    max_subitems_: Int,
    max_depth_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_debug_get_stack_level_locals", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 335235777)
    }
    self := self
    level_ := level_
    max_subitems_ := max_subitems_
    max_depth_ := max_depth_
    args := []__bindgen_gde.TypePtr {
        &level_,
        &max_subitems_,
        &max_depth_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__debug_get_stack_level_members :: proc "contextless" (
    self: Script_Language_Extension,
    level_: Int,
    max_subitems_: Int,
    max_depth_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_debug_get_stack_level_members", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 335235777)
    }
    self := self
    level_ := level_
    max_subitems_ := max_subitems_
    max_depth_ := max_depth_
    args := []__bindgen_gde.TypePtr {
        &level_,
        &max_subitems_,
        &max_depth_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__debug_get_stack_level_instance :: proc "contextless" (
    self: Script_Language_Extension,
    level_: Int,
) -> (ret: rawptr) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_debug_get_stack_level_instance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    level_ := level_
    args := []__bindgen_gde.TypePtr {
        &level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__debug_get_globals :: proc "contextless" (
    self: Script_Language_Extension,
    max_subitems_: Int,
    max_depth_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_debug_get_globals", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4123630098)
    }
    self := self
    max_subitems_ := max_subitems_
    max_depth_ := max_depth_
    args := []__bindgen_gde.TypePtr {
        &max_subitems_,
        &max_depth_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__debug_parse_stack_level_expression :: proc "contextless" (
    self: Script_Language_Extension,
    level_: Int,
    expression_: String,
    max_subitems_: Int,
    max_depth_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_debug_parse_stack_level_expression", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1135811067)
    }
    self := self
    level_ := level_
    expression_ := expression_
    max_subitems_ := max_subitems_
    max_depth_ := max_depth_
    args := []__bindgen_gde.TypePtr {
        &level_,
        &expression_,
        &max_subitems_,
        &max_depth_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__debug_get_current_stack_info :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_debug_get_current_stack_info", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__reload_all_scripts :: proc "contextless" (
    self: Script_Language_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_reload_all_scripts", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__reload_scripts :: proc "contextless" (
    self: Script_Language_Extension,
    scripts_: Array,
    soft_reload_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_reload_scripts", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3156113851)
    }
    self := self
    scripts_ := scripts_
    soft_reload_ := soft_reload_
    args := []__bindgen_gde.TypePtr {
        &scripts_,
        &soft_reload_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__reload_tool_script :: proc "contextless" (
    self: Script_Language_Extension,
    script_: Script,
    soft_reload_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_reload_tool_script", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1957307671)
    }
    self := self
    script_ := script_
    soft_reload_ := soft_reload_
    args := []__bindgen_gde.TypePtr {
        &script_,
        &soft_reload_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__get_recognized_extensions :: proc "contextless" (
    self: Script_Language_Extension,
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

script_language_extension__get_public_functions :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_public_functions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__get_public_constants :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_public_constants", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__get_public_annotations :: proc "contextless" (
    self: Script_Language_Extension,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_public_annotations", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__profiling_start :: proc "contextless" (
    self: Script_Language_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_profiling_start", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__profiling_stop :: proc "contextless" (
    self: Script_Language_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_profiling_stop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__profiling_set_save_native_calls :: proc "contextless" (
    self: Script_Language_Extension,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_profiling_set_save_native_calls", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__profiling_get_accumulated_data :: proc "contextless" (
    self: Script_Language_Extension,
    info_array_: ^Script_Language_Extension_Profiling_Info,
    info_max_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_profiling_get_accumulated_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 50157827)
    }
    self := self
    info_array_ := info_array_
    info_max_ := info_max_
    args := []__bindgen_gde.TypePtr {
        &info_array_,
        &info_max_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__profiling_get_frame_data :: proc "contextless" (
    self: Script_Language_Extension,
    info_array_: ^Script_Language_Extension_Profiling_Info,
    info_max_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_profiling_get_frame_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 50157827)
    }
    self := self
    info_array_ := info_array_
    info_max_ := info_max_
    args := []__bindgen_gde.TypePtr {
        &info_array_,
        &info_max_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__frame :: proc "contextless" (
    self: Script_Language_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_frame", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

script_language_extension__handles_global_class_type :: proc "contextless" (
    self: Script_Language_Extension,
    type_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_handles_global_class_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

script_language_extension__get_global_class_name :: proc "contextless" (
    self: Script_Language_Extension,
    path_: String,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_global_class_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2248993622)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
script_language_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ScriptLanguageExtension", true)
}

@(private = "file")
__class_name: String_Name