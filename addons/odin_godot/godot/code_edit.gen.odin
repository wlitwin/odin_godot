package godot

import __bindgen_gde "godot:gdext"

Code_Edit_Constants :: enum {
}
Code_Edit_Code_Completion_Kind :: enum int {
    Kind_Class = 0,
    Kind_Function = 1,
    Kind_Signal = 2,
    Kind_Variable = 3,
    Kind_Member = 4,
    Kind_Enum = 5,
    Kind_Constant = 6,
    Kind_Node_Path = 7,
    Kind_File_Path = 8,
    Kind_Plain_Text = 9,
}
Code_Edit_Code_Completion_Location :: enum int {
    Location_Local = 0,
    Location_Parent_Mask = 256,
    Location_Other_User_Code = 512,
    Location_Other = 1024,
}



code_edit_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

code_edit_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_code_edit :: proc "contextless" () -> Code_Edit {
    return __bindgen_gde.classdb_construct_object(code_edit_name_ref())
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

code_edit__confirm_code_completion :: proc "contextless" (
    self: Code_Edit,
    replace_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_confirm_code_completion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    replace_ := replace_
    args := []__bindgen_gde.TypePtr {
        &replace_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit__request_code_completion :: proc "contextless" (
    self: Code_Edit,
    force_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_request_code_completion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit__filter_code_completion_candidates :: proc "contextless" (
    self: Code_Edit,
    candidates_: Typed_Array(Dictionary),
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_filter_code_completion_candidates", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2560709669)
    }
    self := self
    candidates_ := candidates_
    args := []__bindgen_gde.TypePtr {
        &candidates_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_indent_size :: proc "contextless" (
    self: Code_Edit,
    size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_indent_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_indent_size :: proc "contextless" (
    self: Code_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_indent_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_indent_using_spaces :: proc "contextless" (
    self: Code_Edit,
    use_spaces_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_indent_using_spaces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    use_spaces_ := use_spaces_
    args := []__bindgen_gde.TypePtr {
        &use_spaces_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_indent_using_spaces :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_indent_using_spaces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_auto_indent_enabled :: proc "contextless" (
    self: Code_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_indent_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_auto_indent_enabled :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_auto_indent_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_auto_indent_prefixes :: proc "contextless" (
    self: Code_Edit,
    prefixes_: Typed_Array(String),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_indent_prefixes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    prefixes_ := prefixes_
    args := []__bindgen_gde.TypePtr {
        &prefixes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_auto_indent_prefixes :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Typed_Array(String)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_auto_indent_prefixes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_do_indent :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("do_indent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_indent_lines :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("indent_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_unindent_lines :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unindent_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_convert_indent :: proc "contextless" (
    self: Code_Edit,
    from_line_: Int,
    to_line_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("convert_indent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 423910286)
    }
    self := self
    from_line_ := from_line_
    to_line_ := to_line_
    args := []__bindgen_gde.TypePtr {
        &from_line_,
        &to_line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_set_auto_brace_completion_enabled :: proc "contextless" (
    self: Code_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_brace_completion_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_auto_brace_completion_enabled :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_auto_brace_completion_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_highlight_matching_braces_enabled :: proc "contextless" (
    self: Code_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_highlight_matching_braces_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_highlight_matching_braces_enabled :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_highlight_matching_braces_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_add_auto_brace_completion_pair :: proc "contextless" (
    self: Code_Edit,
    start_key_: String,
    end_key_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_auto_brace_completion_pair", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3186203200)
    }
    self := self
    start_key_ := start_key_
    end_key_ := end_key_
    args := []__bindgen_gde.TypePtr {
        &start_key_,
        &end_key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_set_auto_brace_completion_pairs :: proc "contextless" (
    self: Code_Edit,
    pairs_: Dictionary,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_brace_completion_pairs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155329257)
    }
    self := self
    pairs_ := pairs_
    args := []__bindgen_gde.TypePtr {
        &pairs_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_auto_brace_completion_pairs :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_auto_brace_completion_pairs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_has_auto_brace_completion_open_key :: proc "contextless" (
    self: Code_Edit,
    open_key_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_auto_brace_completion_open_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    open_key_ := open_key_
    args := []__bindgen_gde.TypePtr {
        &open_key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_has_auto_brace_completion_close_key :: proc "contextless" (
    self: Code_Edit,
    close_key_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_auto_brace_completion_close_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    close_key_ := close_key_
    args := []__bindgen_gde.TypePtr {
        &close_key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_get_auto_brace_completion_close_key :: proc "contextless" (
    self: Code_Edit,
    open_key_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_auto_brace_completion_close_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3135753539)
    }
    self := self
    open_key_ := open_key_
    args := []__bindgen_gde.TypePtr {
        &open_key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_draw_breakpoints_gutter :: proc "contextless" (
    self: Code_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_breakpoints_gutter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_drawing_breakpoints_gutter :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_drawing_breakpoints_gutter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_draw_bookmarks_gutter :: proc "contextless" (
    self: Code_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_bookmarks_gutter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_drawing_bookmarks_gutter :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_drawing_bookmarks_gutter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_draw_executing_lines_gutter :: proc "contextless" (
    self: Code_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_executing_lines_gutter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_drawing_executing_lines_gutter :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_drawing_executing_lines_gutter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_line_as_breakpoint :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
    breakpointed_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_as_breakpoint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    line_ := line_
    breakpointed_ := breakpointed_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &breakpointed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_line_breakpointed :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_line_breakpointed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_clear_breakpointed_lines :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_breakpointed_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_breakpointed_lines :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_breakpointed_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1930428628)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_line_as_bookmarked :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
    bookmarked_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_as_bookmarked", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    line_ := line_
    bookmarked_ := bookmarked_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &bookmarked_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_line_bookmarked :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_line_bookmarked", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_clear_bookmarked_lines :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_bookmarked_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_bookmarked_lines :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bookmarked_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1930428628)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_line_as_executing :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
    executing_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_as_executing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    line_ := line_
    executing_ := executing_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &executing_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_line_executing :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_line_executing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_clear_executing_lines :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_executing_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_executing_lines :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_executing_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1930428628)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_draw_line_numbers :: proc "contextless" (
    self: Code_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_line_numbers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_draw_line_numbers_enabled :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_draw_line_numbers_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_line_numbers_zero_padded :: proc "contextless" (
    self: Code_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_numbers_zero_padded", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_line_numbers_zero_padded :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_line_numbers_zero_padded", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_line_numbers_min_digits :: proc "contextless" (
    self: Code_Edit,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_numbers_min_digits", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_line_numbers_min_digits :: proc "contextless" (
    self: Code_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_numbers_min_digits", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_draw_fold_gutter :: proc "contextless" (
    self: Code_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_fold_gutter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_drawing_fold_gutter :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_drawing_fold_gutter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_line_folding_enabled :: proc "contextless" (
    self: Code_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_folding_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_line_folding_enabled :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_line_folding_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_can_fold_line :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("can_fold_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_fold_line :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("fold_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_unfold_line :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unfold_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_fold_all_lines :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("fold_all_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_unfold_all_lines :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unfold_all_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_toggle_foldable_line :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("toggle_foldable_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_toggle_foldable_lines_at_carets :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("toggle_foldable_lines_at_carets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_line_folded :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_line_folded", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_get_folded_lines :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Typed_Array(Int)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_folded_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_create_code_region :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_code_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_code_region_start_tag :: proc "contextless" (
    self: Code_Edit,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_code_region_start_tag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_get_code_region_end_tag :: proc "contextless" (
    self: Code_Edit,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_code_region_end_tag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_code_region_tags :: proc "contextless" (
    self: Code_Edit,
    start_: String,
    end_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_code_region_tags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 708800718)
    }
    self := self
    start_ := start_
    end_ := end_
    args := []__bindgen_gde.TypePtr {
        &start_,
        &end_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_line_code_region_start :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_line_code_region_start", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_is_line_code_region_end :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_line_code_region_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_add_string_delimiter :: proc "contextless" (
    self: Code_Edit,
    start_key_: String,
    end_key_: String,
    line_only_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_string_delimiter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3146098955)
    }
    self := self
    start_key_ := start_key_
    end_key_ := end_key_
    line_only_ := line_only_
    args := []__bindgen_gde.TypePtr {
        &start_key_,
        &end_key_,
        &line_only_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_remove_string_delimiter :: proc "contextless" (
    self: Code_Edit,
    start_key_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_string_delimiter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    start_key_ := start_key_
    args := []__bindgen_gde.TypePtr {
        &start_key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_has_string_delimiter :: proc "contextless" (
    self: Code_Edit,
    start_key_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_string_delimiter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    start_key_ := start_key_
    args := []__bindgen_gde.TypePtr {
        &start_key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_string_delimiters :: proc "contextless" (
    self: Code_Edit,
    string_delimiters_: Typed_Array(String),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_string_delimiters", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    string_delimiters_ := string_delimiters_
    args := []__bindgen_gde.TypePtr {
        &string_delimiters_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_clear_string_delimiters :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_string_delimiters", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_string_delimiters :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Typed_Array(String)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_string_delimiters", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_is_in_string :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
    column_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_in_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 688195400)
    }
    self := self
    line_ := line_
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_add_comment_delimiter :: proc "contextless" (
    self: Code_Edit,
    start_key_: String,
    end_key_: String,
    line_only_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_comment_delimiter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3146098955)
    }
    self := self
    start_key_ := start_key_
    end_key_ := end_key_
    line_only_ := line_only_
    args := []__bindgen_gde.TypePtr {
        &start_key_,
        &end_key_,
        &line_only_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_remove_comment_delimiter :: proc "contextless" (
    self: Code_Edit,
    start_key_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_comment_delimiter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    start_key_ := start_key_
    args := []__bindgen_gde.TypePtr {
        &start_key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_has_comment_delimiter :: proc "contextless" (
    self: Code_Edit,
    start_key_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_comment_delimiter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    start_key_ := start_key_
    args := []__bindgen_gde.TypePtr {
        &start_key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_comment_delimiters :: proc "contextless" (
    self: Code_Edit,
    comment_delimiters_: Typed_Array(String),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_comment_delimiters", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    comment_delimiters_ := comment_delimiters_
    args := []__bindgen_gde.TypePtr {
        &comment_delimiters_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_clear_comment_delimiters :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_comment_delimiters", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_comment_delimiters :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Typed_Array(String)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_comment_delimiters", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_is_in_comment :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
    column_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_in_comment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 688195400)
    }
    self := self
    line_ := line_
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_get_delimiter_start_key :: proc "contextless" (
    self: Code_Edit,
    delimiter_index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_delimiter_start_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    delimiter_index_ := delimiter_index_
    args := []__bindgen_gde.TypePtr {
        &delimiter_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_get_delimiter_end_key :: proc "contextless" (
    self: Code_Edit,
    delimiter_index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_delimiter_end_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    delimiter_index_ := delimiter_index_
    args := []__bindgen_gde.TypePtr {
        &delimiter_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_get_delimiter_start_position :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
    column_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_delimiter_start_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3016396712)
    }
    self := self
    line_ := line_
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_get_delimiter_end_position :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
    column_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_delimiter_end_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3016396712)
    }
    self := self
    line_ := line_
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_code_hint :: proc "contextless" (
    self: Code_Edit,
    code_hint_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_code_hint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    code_hint_ := code_hint_
    args := []__bindgen_gde.TypePtr {
        &code_hint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_set_code_hint_draw_below :: proc "contextless" (
    self: Code_Edit,
    draw_below_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_code_hint_draw_below", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    draw_below_ := draw_below_
    args := []__bindgen_gde.TypePtr {
        &draw_below_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_text_for_code_completion :: proc "contextless" (
    self: Code_Edit,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_text_for_code_completion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_request_code_completion :: proc "contextless" (
    self: Code_Edit,
    force_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("request_code_completion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 107499316)
    }
    self := self
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_add_code_completion_option :: proc "contextless" (
    self: Code_Edit,
    type_: Code_Edit_Code_Completion_Kind,
    display_text_: String,
    insert_text_: String,
    text_color_: Color,
    icon_: Resource,
    value_: Variant,
    location_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_code_completion_option", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3944379502)
    }
    self := self
    type_ := type_
    display_text_ := display_text_
    insert_text_ := insert_text_
    text_color_ := text_color_
    icon_ := icon_
    value_ := value_
    location_ := location_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &display_text_,
        &insert_text_,
        &text_color_,
        &icon_,
        &value_,
        &location_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_update_code_completion_options :: proc "contextless" (
    self: Code_Edit,
    force_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_code_completion_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_code_completion_options :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_code_completion_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_get_code_completion_option :: proc "contextless" (
    self: Code_Edit,
    index_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_code_completion_option", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3485342025)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_get_code_completion_selected_index :: proc "contextless" (
    self: Code_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_code_completion_selected_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_code_completion_selected_index :: proc "contextless" (
    self: Code_Edit,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_code_completion_selected_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_confirm_code_completion :: proc "contextless" (
    self: Code_Edit,
    replace_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("confirm_code_completion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 107499316)
    }
    self := self
    replace_ := replace_
    args := []__bindgen_gde.TypePtr {
        &replace_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_cancel_code_completion :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cancel_code_completion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_set_code_completion_enabled :: proc "contextless" (
    self: Code_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_code_completion_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_code_completion_enabled :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_code_completion_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_code_completion_prefixes :: proc "contextless" (
    self: Code_Edit,
    prefixes_: Typed_Array(String),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_code_completion_prefixes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    prefixes_ := prefixes_
    args := []__bindgen_gde.TypePtr {
        &prefixes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_code_completion_prefixes :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Typed_Array(String)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_code_completion_prefixes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_line_length_guidelines :: proc "contextless" (
    self: Code_Edit,
    guideline_columns_: Typed_Array(Int),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_length_guidelines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    guideline_columns_ := guideline_columns_
    args := []__bindgen_gde.TypePtr {
        &guideline_columns_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_get_line_length_guidelines :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Typed_Array(Int)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_length_guidelines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_symbol_lookup_on_click_enabled :: proc "contextless" (
    self: Code_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_symbol_lookup_on_click_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_symbol_lookup_on_click_enabled :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_symbol_lookup_on_click_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_get_text_for_symbol_lookup :: proc "contextless" (
    self: Code_Edit,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_text_for_symbol_lookup", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_get_text_with_cursor_char :: proc "contextless" (
    self: Code_Edit,
    line_: Int,
    column_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_text_with_cursor_char", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1391810591)
    }
    self := self
    line_ := line_
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_set_symbol_lookup_word_as_valid :: proc "contextless" (
    self: Code_Edit,
    valid_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_symbol_lookup_word_as_valid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    valid_ := valid_
    args := []__bindgen_gde.TypePtr {
        &valid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_set_symbol_tooltip_on_hover_enabled :: proc "contextless" (
    self: Code_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_symbol_tooltip_on_hover_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_is_symbol_tooltip_on_hover_enabled :: proc "contextless" (
    self: Code_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_symbol_tooltip_on_hover_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

code_edit_move_lines_up :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_lines_up", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_move_lines_down :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_lines_down", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_delete_lines :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("delete_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_duplicate_selection :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("duplicate_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

code_edit_duplicate_lines :: proc "contextless" (
    self: Code_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("duplicate_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
code_edit_get_symbol_lookup_on_click :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_symbol_lookup_on_click_enabled(self)
}
code_edit_set_symbol_lookup_on_click :: proc "contextless" (self: Code_Edit, value: Bool) {
    code_edit_set_symbol_lookup_on_click_enabled(self, value)
}
code_edit_get_symbol_tooltip_on_hover :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_symbol_tooltip_on_hover_enabled(self)
}
code_edit_set_symbol_tooltip_on_hover :: proc "contextless" (self: Code_Edit, value: Bool) {
    code_edit_set_symbol_tooltip_on_hover_enabled(self, value)
}
code_edit_get_line_folding :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_line_folding_enabled(self)
}
code_edit_set_line_folding :: proc "contextless" (self: Code_Edit, value: Bool) {
    code_edit_set_line_folding_enabled(self, value)
}
code_edit_get_gutters_draw_breakpoints_gutter :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_drawing_breakpoints_gutter(self)
}
code_edit_set_gutters_draw_breakpoints_gutter :: proc "contextless" (self: Code_Edit, value: Bool) {
    code_edit_set_draw_breakpoints_gutter(self, value)
}
code_edit_get_gutters_draw_bookmarks :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_drawing_bookmarks_gutter(self)
}
code_edit_set_gutters_draw_bookmarks :: proc "contextless" (self: Code_Edit, value: Bool) {
    code_edit_set_draw_bookmarks_gutter(self, value)
}
code_edit_get_gutters_draw_executing_lines :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_drawing_executing_lines_gutter(self)
}
code_edit_set_gutters_draw_executing_lines :: proc "contextless" (self: Code_Edit, value: Bool) {
    code_edit_set_draw_executing_lines_gutter(self, value)
}
code_edit_get_gutters_draw_line_numbers :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_draw_line_numbers_enabled(self)
}
code_edit_set_gutters_draw_line_numbers :: proc "contextless" (self: Code_Edit, value: Bool) {
    code_edit_set_draw_line_numbers(self, value)
}
code_edit_get_gutters_zero_pad_line_numbers :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_line_numbers_zero_padded(self)
}
code_edit_set_gutters_zero_pad_line_numbers :: proc "contextless" (self: Code_Edit, value: Bool) {
    code_edit_set_line_numbers_zero_padded(self, value)
}
code_edit_get_gutters_line_numbers_min_digits :: proc "contextless" (self: Code_Edit) -> i32 {
    return code_edit_get_line_numbers_min_digits(self)
}
code_edit_set_gutters_line_numbers_min_digits :: proc "contextless" (self: Code_Edit, value: Int) {
    code_edit_set_line_numbers_min_digits(self, value)
}
code_edit_get_gutters_draw_fold_gutter :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_drawing_fold_gutter(self)
}
code_edit_set_gutters_draw_fold_gutter :: proc "contextless" (self: Code_Edit, value: Bool) {
    code_edit_set_draw_fold_gutter(self, value)
}
code_edit_get_delimiter_strings :: proc "contextless" (self: Code_Edit) -> Typed_Array(String) {
    return code_edit_get_string_delimiters(self)
}
code_edit_set_delimiter_strings :: proc "contextless" (self: Code_Edit, value: Typed_Array(String)) {
    code_edit_set_string_delimiters(self, value)
}
code_edit_get_delimiter_comments :: proc "contextless" (self: Code_Edit) -> Typed_Array(String) {
    return code_edit_get_comment_delimiters(self)
}
code_edit_set_delimiter_comments :: proc "contextless" (self: Code_Edit, value: Typed_Array(String)) {
    code_edit_set_comment_delimiters(self, value)
}
code_edit_get_code_completion_enabled :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_code_completion_enabled(self)
}
code_edit_get_indent_use_spaces :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_indent_using_spaces(self)
}
code_edit_set_indent_use_spaces :: proc "contextless" (self: Code_Edit, value: Bool) {
    code_edit_set_indent_using_spaces(self, value)
}
code_edit_get_indent_automatic :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_auto_indent_enabled(self)
}
code_edit_set_indent_automatic :: proc "contextless" (self: Code_Edit, value: Bool) {
    code_edit_set_auto_indent_enabled(self, value)
}
code_edit_get_indent_automatic_prefixes :: proc "contextless" (self: Code_Edit) -> Typed_Array(String) {
    return code_edit_get_auto_indent_prefixes(self)
}
code_edit_set_indent_automatic_prefixes :: proc "contextless" (self: Code_Edit, value: Typed_Array(String)) {
    code_edit_set_auto_indent_prefixes(self, value)
}
code_edit_get_auto_brace_completion_enabled :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_auto_brace_completion_enabled(self)
}
code_edit_get_auto_brace_completion_highlight_matching :: proc "contextless" (self: Code_Edit) -> Bool {
    return code_edit_is_highlight_matching_braces_enabled(self)
}
code_edit_set_auto_brace_completion_highlight_matching :: proc "contextless" (self: Code_Edit, value: Bool) {
    code_edit_set_highlight_matching_braces_enabled(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
code_edit_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("CodeEdit", true)
}

@(private = "file")
__class_name: String_Name