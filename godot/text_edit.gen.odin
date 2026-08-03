package godot

import __bindgen_gde "godot:gdext"

Text_Edit_Constants :: enum {
}
Text_Edit_Menu_Items :: enum int {
    Menu_Cut = 0,
    Menu_Copy = 1,
    Menu_Paste = 2,
    Menu_Clear = 3,
    Menu_Select_All = 4,
    Menu_Undo = 5,
    Menu_Redo = 6,
    Menu_Submenu_Text_Dir = 7,
    Menu_Dir_Inherited = 8,
    Menu_Dir_Auto = 9,
    Menu_Dir_Ltr = 10,
    Menu_Dir_Rtl = 11,
    Menu_Display_Ucc = 12,
    Menu_Submenu_Insert_Ucc = 13,
    Menu_Insert_Lrm = 14,
    Menu_Insert_Rlm = 15,
    Menu_Insert_Lre = 16,
    Menu_Insert_Rle = 17,
    Menu_Insert_Lro = 18,
    Menu_Insert_Rlo = 19,
    Menu_Insert_Pdf = 20,
    Menu_Insert_Alm = 21,
    Menu_Insert_Lri = 22,
    Menu_Insert_Rli = 23,
    Menu_Insert_Fsi = 24,
    Menu_Insert_Pdi = 25,
    Menu_Insert_Zwj = 26,
    Menu_Insert_Zwnj = 27,
    Menu_Insert_Wj = 28,
    Menu_Insert_Shy = 29,
    Menu_Emoji_And_Symbol = 30,
    Menu_Max = 31,
}
Text_Edit_Edit_Action :: enum int {
    Action_None = 0,
    Action_Typing = 1,
    Action_Backspace = 2,
    Action_Delete = 3,
}
Text_Edit_Search_Flags :: enum int {
    Search_Match_Case = 1,
    Search_Whole_Words = 2,
    Search_Backwards = 4,
}
Text_Edit_Caret_Type :: enum int {
    Caret_Type_Line = 0,
    Caret_Type_Block = 1,
}
Text_Edit_Selection_Mode :: enum int {
    Selection_Mode_None = 0,
    Selection_Mode_Shift = 1,
    Selection_Mode_Pointer = 2,
    Selection_Mode_Word = 3,
    Selection_Mode_Line = 4,
}
Text_Edit_Line_Wrapping_Mode :: enum int {
    Line_Wrapping_None = 0,
    Line_Wrapping_Boundary = 1,
}
Text_Edit_Gutter_Type :: enum int {
    Gutter_Type_String = 0,
    Gutter_Type_Icon = 1,
    Gutter_Type_Custom = 2,
}



text_edit_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

text_edit_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_text_edit :: proc "contextless" () -> Text_Edit {
    return cast(Text_Edit)__bindgen_gde.classdb_construct_object(text_edit_name_ref())
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

text_edit__handle_unicode_input :: proc "contextless" (
    self: Text_Edit,
    unicode_char_: Int,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_handle_unicode_input", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    unicode_char_ := unicode_char_
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &unicode_char_,
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit__backspace :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_backspace", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit__cut :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_cut", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit__copy :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_copy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit__paste :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_paste", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit__paste_primary_clipboard :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_paste_primary_clipboard", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_has_ime_text :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_ime_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_cancel_ime :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cancel_ime", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_apply_ime :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("apply_ime", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_set_editable :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_editable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_editable :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_editable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_text_direction :: proc "contextless" (
    self: Text_Edit,
    direction_: Control_Text_Direction,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_text_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 119160795)
    }
    self := self
    direction_ := direction_
    args := []__bindgen_gde.TypePtr {
        &direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_text_direction :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Control_Text_Direction) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_text_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 797257663)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_language :: proc "contextless" (
    self: Text_Edit,
    language_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_language", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    language_ := language_
    args := []__bindgen_gde.TypePtr {
        &language_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_language :: proc "contextless" (
    self: Text_Edit,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_language", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_structured_text_bidi_override :: proc "contextless" (
    self: Text_Edit,
    parser_: Text_Server_Structured_Text_Parser,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_structured_text_bidi_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 55961453)
    }
    self := self
    parser_ := parser_
    args := []__bindgen_gde.TypePtr {
        &parser_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_structured_text_bidi_override :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Text_Server_Structured_Text_Parser) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_structured_text_bidi_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3385126229)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_structured_text_bidi_override_options :: proc "contextless" (
    self: Text_Edit,
    args_: Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_structured_text_bidi_override_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    args_ := args_
    args := []__bindgen_gde.TypePtr {
        &args_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_structured_text_bidi_override_options :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_structured_text_bidi_override_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_tab_size :: proc "contextless" (
    self: Text_Edit,
    size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tab_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_tab_size :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_indent_wrapped_lines :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_indent_wrapped_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_indent_wrapped_lines :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_indent_wrapped_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_tab_input_mode :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tab_input_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_tab_input_mode :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_input_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_overtype_mode_enabled :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_overtype_mode_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_overtype_mode_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_overtype_mode_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_context_menu_enabled :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_context_menu_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_context_menu_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_context_menu_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_emoji_menu_enabled :: proc "contextless" (
    self: Text_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emoji_menu_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_emoji_menu_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_emoji_menu_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_backspace_deletes_composite_character_enabled :: proc "contextless" (
    self: Text_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_backspace_deletes_composite_character_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_backspace_deletes_composite_character_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_backspace_deletes_composite_character_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_shortcut_keys_enabled :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shortcut_keys_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_shortcut_keys_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_shortcut_keys_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_virtual_keyboard_enabled :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_virtual_keyboard_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_virtual_keyboard_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_virtual_keyboard_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_virtual_keyboard_show_on_focus :: proc "contextless" (
    self: Text_Edit,
    show_on_focus_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_virtual_keyboard_show_on_focus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    show_on_focus_ := show_on_focus_
    args := []__bindgen_gde.TypePtr {
        &show_on_focus_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_virtual_keyboard_show_on_focus :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_virtual_keyboard_show_on_focus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_middle_mouse_paste_enabled :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_middle_mouse_paste_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_middle_mouse_paste_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_middle_mouse_paste_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_empty_selection_clipboard_enabled :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_empty_selection_clipboard_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_empty_selection_clipboard_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_empty_selection_clipboard_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_clear :: proc "contextless" (
    self: Text_Edit,
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

text_edit_set_text :: proc "contextless" (
    self: Text_Edit,
    text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_text :: proc "contextless" (
    self: Text_Edit,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_line_count :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_placeholder :: proc "contextless" (
    self: Text_Edit,
    text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_placeholder", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_placeholder :: proc "contextless" (
    self: Text_Edit,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_placeholder", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_line :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    new_text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    line_ := line_
    new_text_ := new_text_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &new_text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_line :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_line_with_ime :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_with_ime", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_line_width :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    wrap_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 688195400)
    }
    self := self
    line_ := line_
    wrap_index_ := wrap_index_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &wrap_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_line_height :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_indent_level :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_indent_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_first_non_whitespace_column :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_first_non_whitespace_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_swap_lines :: proc "contextless" (
    self: Text_Edit,
    from_line_: Int,
    to_line_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("swap_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
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

text_edit_insert_line_at :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("insert_line_at", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    line_ := line_
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_remove_line_at :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    move_carets_down_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_line_at", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 972357352)
    }
    self := self
    line_ := line_
    move_carets_down_ := move_carets_down_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &move_carets_down_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_insert_text_at_caret :: proc "contextless" (
    self: Text_Edit,
    text_: String,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("insert_text_at_caret", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2697778442)
    }
    self := self
    text_ := text_
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &text_,
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_insert_text :: proc "contextless" (
    self: Text_Edit,
    text_: String,
    line_: Int,
    column_: Int,
    before_selection_begin_: Bool,
    before_selection_end_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("insert_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1881564334)
    }
    self := self
    text_ := text_
    line_ := line_
    column_ := column_
    before_selection_begin_ := before_selection_begin_
    before_selection_end_ := before_selection_end_
    args := []__bindgen_gde.TypePtr {
        &text_,
        &line_,
        &column_,
        &before_selection_begin_,
        &before_selection_end_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_remove_text :: proc "contextless" (
    self: Text_Edit,
    from_line_: Int,
    from_column_: Int,
    to_line_: Int,
    to_column_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4275841770)
    }
    self := self
    from_line_ := from_line_
    from_column_ := from_column_
    to_line_ := to_line_
    to_column_ := to_column_
    args := []__bindgen_gde.TypePtr {
        &from_line_,
        &from_column_,
        &to_line_,
        &to_column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_last_unhidden_line :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_last_unhidden_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_next_visible_line_offset_from :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    visible_amount_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_next_visible_line_offset_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175239445)
    }
    self := self
    line_ := line_
    visible_amount_ := visible_amount_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &visible_amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_next_visible_line_index_offset_from :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    wrap_index_: Int,
    visible_amount_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_next_visible_line_index_offset_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3386475622)
    }
    self := self
    line_ := line_
    wrap_index_ := wrap_index_
    visible_amount_ := visible_amount_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &wrap_index_,
        &visible_amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_backspace :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("backspace", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_cut :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cut", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_copy :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("copy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_paste :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("paste", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_paste_primary_clipboard :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("paste_primary_clipboard", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_start_action :: proc "contextless" (
    self: Text_Edit,
    action_: Text_Edit_Edit_Action,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("start_action", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2834827583)
    }
    self := self
    action_ := action_
    args := []__bindgen_gde.TypePtr {
        &action_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_end_action :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("end_action", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_begin_complex_operation :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("begin_complex_operation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_end_complex_operation :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("end_complex_operation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_has_undo :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_undo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_has_redo :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_redo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_undo :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("undo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_redo :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("redo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_clear_undo_history :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_undo_history", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_tag_saved_version :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tag_saved_version", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_version :: proc "contextless" (
    self: Text_Edit,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_version", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_saved_version :: proc "contextless" (
    self: Text_Edit,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_saved_version", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_search_text :: proc "contextless" (
    self: Text_Edit,
    search_text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_search_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    search_text_ := search_text_
    args := []__bindgen_gde.TypePtr {
        &search_text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_set_search_flags :: proc "contextless" (
    self: Text_Edit,
    flags_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_search_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_search :: proc "contextless" (
    self: Text_Edit,
    text_: String,
    flags_: Int,
    from_line_: Int,
    from_column_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("search", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1203739136)
    }
    self := self
    text_ := text_
    flags_ := flags_
    from_line_ := from_line_
    from_column_ := from_column_
    args := []__bindgen_gde.TypePtr {
        &text_,
        &flags_,
        &from_line_,
        &from_column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_tooltip_request_func :: proc "contextless" (
    self: Text_Edit,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tooltip_request_func", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1611583062)
    }
    self := self
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_local_mouse_pos :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_local_mouse_pos", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_word_at_pos :: proc "contextless" (
    self: Text_Edit,
    position_: Vector2,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_word_at_pos", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3674420000)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_line_column_at_pos :: proc "contextless" (
    self: Text_Edit,
    position_: Vector2i,
    clamp_line_: Bool,
    clamp_column_: Bool,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_column_at_pos", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3472935744)
    }
    self := self
    position_ := position_
    clamp_line_ := clamp_line_
    clamp_column_ := clamp_column_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &clamp_line_,
        &clamp_column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_pos_at_line_column :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    column_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pos_at_line_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 410388347)
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

text_edit_get_rect_at_line_column :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    column_: Int,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rect_at_line_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3256618057)
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

text_edit_get_minimap_line_at_pos :: proc "contextless" (
    self: Text_Edit,
    position_: Vector2i,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_minimap_line_at_pos", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2485466453)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_is_dragging_cursor :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_dragging_cursor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_is_mouse_over_selection :: proc "contextless" (
    self: Text_Edit,
    edges_: Bool,
    caret_index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_mouse_over_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1840282309)
    }
    self := self
    edges_ := edges_
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &edges_,
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_caret_type :: proc "contextless" (
    self: Text_Edit,
    type_: Text_Edit_Caret_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_caret_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1211596914)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_caret_type :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Text_Edit_Caret_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_caret_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2830252959)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_caret_blink_enabled :: proc "contextless" (
    self: Text_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_caret_blink_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_caret_blink_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_caret_blink_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_caret_blink_interval :: proc "contextless" (
    self: Text_Edit,
    interval_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_caret_blink_interval", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    interval_ := interval_
    args := []__bindgen_gde.TypePtr {
        &interval_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_caret_blink_interval :: proc "contextless" (
    self: Text_Edit,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_caret_blink_interval", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_draw_caret_when_editable_disabled :: proc "contextless" (
    self: Text_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_caret_when_editable_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_drawing_caret_when_editable_disabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_drawing_caret_when_editable_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_move_caret_on_right_click_enabled :: proc "contextless" (
    self: Text_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_move_caret_on_right_click_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_move_caret_on_right_click_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_move_caret_on_right_click_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_caret_mid_grapheme_enabled :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_caret_mid_grapheme_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_caret_mid_grapheme_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_caret_mid_grapheme_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_multiple_carets_enabled :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_multiple_carets_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_multiple_carets_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_multiple_carets_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_add_caret :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    column_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_caret", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 50157827)
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

text_edit_remove_caret :: proc "contextless" (
    self: Text_Edit,
    caret_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_caret", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    caret_ := caret_
    args := []__bindgen_gde.TypePtr {
        &caret_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_remove_secondary_carets :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_secondary_carets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_caret_count :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_caret_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_add_caret_at_carets :: proc "contextless" (
    self: Text_Edit,
    below_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_caret_at_carets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    below_ := below_
    args := []__bindgen_gde.TypePtr {
        &below_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_sorted_carets :: proc "contextless" (
    self: Text_Edit,
    include_ignored_carets_: Bool,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sorted_carets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2131714034)
    }
    self := self
    include_ignored_carets_ := include_ignored_carets_
    args := []__bindgen_gde.TypePtr {
        &include_ignored_carets_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_collapse_carets :: proc "contextless" (
    self: Text_Edit,
    from_line_: Int,
    from_column_: Int,
    to_line_: Int,
    to_column_: Int,
    inclusive_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("collapse_carets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 228654177)
    }
    self := self
    from_line_ := from_line_
    from_column_ := from_column_
    to_line_ := to_line_
    to_column_ := to_column_
    inclusive_ := inclusive_
    args := []__bindgen_gde.TypePtr {
        &from_line_,
        &from_column_,
        &to_line_,
        &to_column_,
        &inclusive_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_merge_overlapping_carets :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("merge_overlapping_carets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_begin_multicaret_edit :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("begin_multicaret_edit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_end_multicaret_edit :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("end_multicaret_edit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_in_mulitcaret_edit :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_in_mulitcaret_edit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_multicaret_edit_ignore_caret :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("multicaret_edit_ignore_caret", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_is_caret_visible :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_caret_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1051549951)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_caret_draw_pos :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_caret_draw_pos", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 478253731)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_caret_line :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    adjust_viewport_: Bool,
    can_be_hidden_: Bool,
    wrap_index_: Int,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_caret_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1302582944)
    }
    self := self
    line_ := line_
    adjust_viewport_ := adjust_viewport_
    can_be_hidden_ := can_be_hidden_
    wrap_index_ := wrap_index_
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &adjust_viewport_,
        &can_be_hidden_,
        &wrap_index_,
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_caret_line :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_caret_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_caret_column :: proc "contextless" (
    self: Text_Edit,
    column_: Int,
    adjust_viewport_: Bool,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_caret_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3796796178)
    }
    self := self
    column_ := column_
    adjust_viewport_ := adjust_viewport_
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &adjust_viewport_,
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_caret_column :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_caret_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_next_composite_character_column :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    column_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_next_composite_character_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175239445)
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

text_edit_get_previous_composite_character_column :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    column_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_previous_composite_character_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175239445)
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

text_edit_get_caret_wrap_index :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_caret_wrap_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_word_under_caret :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_word_under_caret", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3929349208)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_use_default_word_separators :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_default_word_separators", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_default_word_separators_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_default_word_separators_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_use_custom_word_separators :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_custom_word_separators", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_custom_word_separators_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_custom_word_separators_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_custom_word_separators :: proc "contextless" (
    self: Text_Edit,
    custom_word_separators_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_word_separators", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    custom_word_separators_ := custom_word_separators_
    args := []__bindgen_gde.TypePtr {
        &custom_word_separators_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_custom_word_separators :: proc "contextless" (
    self: Text_Edit,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_word_separators", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_selecting_enabled :: proc "contextless" (
    self: Text_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_selecting_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_selecting_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_selecting_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_deselect_on_focus_loss_enabled :: proc "contextless" (
    self: Text_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_deselect_on_focus_loss_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_deselect_on_focus_loss_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_deselect_on_focus_loss_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_drag_and_drop_selection_enabled :: proc "contextless" (
    self: Text_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_drag_and_drop_selection_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_drag_and_drop_selection_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_drag_and_drop_selection_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_selection_mode :: proc "contextless" (
    self: Text_Edit,
    mode_: Text_Edit_Selection_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_selection_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1658801786)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_selection_mode :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Text_Edit_Selection_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selection_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3750106938)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_select_all :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("select_all", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_select_word_under_caret :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("select_word_under_caret", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_add_selection_for_next_occurrence :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_selection_for_next_occurrence", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_skip_selection_for_next_occurrence :: proc "contextless" (
    self: Text_Edit,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("skip_selection_for_next_occurrence", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_select :: proc "contextless" (
    self: Text_Edit,
    origin_line_: Int,
    origin_column_: Int,
    caret_line_: Int,
    caret_column_: Int,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("select", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2560984452)
    }
    self := self
    origin_line_ := origin_line_
    origin_column_ := origin_column_
    caret_line_ := caret_line_
    caret_column_ := caret_column_
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &origin_line_,
        &origin_column_,
        &caret_line_,
        &caret_column_,
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_has_selection :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2824505868)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_selected_text :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selected_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2309358862)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_selection_at_line_column :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    column_: Int,
    include_edges_: Bool,
    only_selections_: Bool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selection_at_line_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1810224333)
    }
    self := self
    line_ := line_
    column_ := column_
    include_edges_ := include_edges_
    only_selections_ := only_selections_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &column_,
        &include_edges_,
        &only_selections_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_line_ranges_from_carets :: proc "contextless" (
    self: Text_Edit,
    only_selections_: Bool,
    merge_adjacent_: Bool,
) -> (ret: Typed_Array(Vector2i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_ranges_from_carets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2393089247)
    }
    self := self
    only_selections_ := only_selections_
    merge_adjacent_ := merge_adjacent_
    args := []__bindgen_gde.TypePtr {
        &only_selections_,
        &merge_adjacent_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_selection_origin_line :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selection_origin_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_selection_origin_column :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selection_origin_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_selection_origin_line :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    can_be_hidden_: Bool,
    wrap_index_: Int,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_selection_origin_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 195434140)
    }
    self := self
    line_ := line_
    can_be_hidden_ := can_be_hidden_
    wrap_index_ := wrap_index_
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &can_be_hidden_,
        &wrap_index_,
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_set_selection_origin_column :: proc "contextless" (
    self: Text_Edit,
    column_: Int,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_selection_origin_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2230941749)
    }
    self := self
    column_ := column_
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_selection_from_line :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selection_from_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_selection_from_column :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selection_from_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_selection_to_line :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selection_to_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_selection_to_column :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selection_to_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_is_caret_after_selection_origin :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_caret_after_selection_origin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1051549951)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_deselect :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("deselect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_delete_selection :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("delete_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_set_line_wrapping_mode :: proc "contextless" (
    self: Text_Edit,
    mode_: Text_Edit_Line_Wrapping_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_wrapping_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2525115309)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_line_wrapping_mode :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Text_Edit_Line_Wrapping_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_wrapping_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3562716114)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_autowrap_mode :: proc "contextless" (
    self: Text_Edit,
    autowrap_mode_: Text_Server_Autowrap_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_autowrap_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3289138044)
    }
    self := self
    autowrap_mode_ := autowrap_mode_
    args := []__bindgen_gde.TypePtr {
        &autowrap_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_autowrap_mode :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Text_Server_Autowrap_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_autowrap_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1549071663)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_is_line_wrapped :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_line_wrapped", true)
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

text_edit_get_line_wrap_count :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_wrap_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_line_wrap_index_at_column :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    column_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_wrap_index_at_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175239445)
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

text_edit_get_line_wrapped_text :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_wrapped_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 647634434)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_smooth_scroll_enabled :: proc "contextless" (
    self: Text_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_smooth_scroll_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_smooth_scroll_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_smooth_scroll_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_v_scroll_bar :: proc "contextless" (
    self: Text_Edit,
) -> (ret: V_Scroll_Bar) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_v_scroll_bar", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3226026593)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_h_scroll_bar :: proc "contextless" (
    self: Text_Edit,
) -> (ret: H_Scroll_Bar) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_h_scroll_bar", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3774687988)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_v_scroll :: proc "contextless" (
    self: Text_Edit,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_v_scroll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_v_scroll :: proc "contextless" (
    self: Text_Edit,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_v_scroll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_h_scroll :: proc "contextless" (
    self: Text_Edit,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_h_scroll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_h_scroll :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_h_scroll", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_scroll_past_end_of_file_enabled :: proc "contextless" (
    self: Text_Edit,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scroll_past_end_of_file_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_scroll_past_end_of_file_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_scroll_past_end_of_file_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_v_scroll_speed :: proc "contextless" (
    self: Text_Edit,
    speed_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_v_scroll_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    speed_ := speed_
    args := []__bindgen_gde.TypePtr {
        &speed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_v_scroll_speed :: proc "contextless" (
    self: Text_Edit,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_v_scroll_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_fit_content_height_enabled :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fit_content_height_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_fit_content_height_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_fit_content_height_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_fit_content_width_enabled :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fit_content_width_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_fit_content_width_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_fit_content_width_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_scroll_pos_for_line :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    wrap_index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scroll_pos_for_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3929084198)
    }
    self := self
    line_ := line_
    wrap_index_ := wrap_index_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &wrap_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_line_as_first_visible :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    wrap_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_as_first_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2230941749)
    }
    self := self
    line_ := line_
    wrap_index_ := wrap_index_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &wrap_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_first_visible_line :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_first_visible_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_is_line_in_viewport :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_line_in_viewport", true)
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

text_edit_set_line_as_center_visible :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    wrap_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_as_center_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2230941749)
    }
    self := self
    line_ := line_
    wrap_index_ := wrap_index_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &wrap_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_set_line_as_last_visible :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    wrap_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_as_last_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2230941749)
    }
    self := self
    line_ := line_
    wrap_index_ := wrap_index_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &wrap_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_last_full_visible_line :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_last_full_visible_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_last_full_visible_line_wrap_index :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_last_full_visible_line_wrap_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_visible_line_count :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visible_line_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_visible_line_count_in_range :: proc "contextless" (
    self: Text_Edit,
    from_line_: Int,
    to_line_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visible_line_count_in_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175239445)
    }
    self := self
    from_line_ := from_line_
    to_line_ := to_line_
    args := []__bindgen_gde.TypePtr {
        &from_line_,
        &to_line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_total_visible_line_count :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_total_visible_line_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_adjust_viewport_to_caret :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("adjust_viewport_to_caret", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1995695955)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_center_viewport_to_caret :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("center_viewport_to_caret", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1995695955)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_set_draw_minimap :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_minimap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_drawing_minimap :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_drawing_minimap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_minimap_width :: proc "contextless" (
    self: Text_Edit,
    width_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_minimap_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    width_ := width_
    args := []__bindgen_gde.TypePtr {
        &width_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_minimap_width :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_minimap_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_minimap_visible_lines :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_minimap_visible_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_add_gutter :: proc "contextless" (
    self: Text_Edit,
    at_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_gutter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    at_ := at_
    args := []__bindgen_gde.TypePtr {
        &at_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_remove_gutter :: proc "contextless" (
    self: Text_Edit,
    gutter_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_gutter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    gutter_ := gutter_
    args := []__bindgen_gde.TypePtr {
        &gutter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_gutter_count :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gutter_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_gutter_name :: proc "contextless" (
    self: Text_Edit,
    gutter_: Int,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gutter_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    gutter_ := gutter_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &gutter_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_gutter_name :: proc "contextless" (
    self: Text_Edit,
    gutter_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gutter_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    gutter_ := gutter_
    args := []__bindgen_gde.TypePtr {
        &gutter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_gutter_type :: proc "contextless" (
    self: Text_Edit,
    gutter_: Int,
    type_: Text_Edit_Gutter_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gutter_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1088959071)
    }
    self := self
    gutter_ := gutter_
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &gutter_,
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_gutter_type :: proc "contextless" (
    self: Text_Edit,
    gutter_: Int,
) -> (ret: Text_Edit_Gutter_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gutter_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1159699127)
    }
    self := self
    gutter_ := gutter_
    args := []__bindgen_gde.TypePtr {
        &gutter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_gutter_width :: proc "contextless" (
    self: Text_Edit,
    gutter_: Int,
    width_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gutter_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    gutter_ := gutter_
    width_ := width_
    args := []__bindgen_gde.TypePtr {
        &gutter_,
        &width_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_gutter_width :: proc "contextless" (
    self: Text_Edit,
    gutter_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gutter_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    gutter_ := gutter_
    args := []__bindgen_gde.TypePtr {
        &gutter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_gutter_draw :: proc "contextless" (
    self: Text_Edit,
    gutter_: Int,
    draw_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gutter_draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    gutter_ := gutter_
    draw_ := draw_
    args := []__bindgen_gde.TypePtr {
        &gutter_,
        &draw_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_gutter_drawn :: proc "contextless" (
    self: Text_Edit,
    gutter_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_gutter_drawn", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    gutter_ := gutter_
    args := []__bindgen_gde.TypePtr {
        &gutter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_gutter_clickable :: proc "contextless" (
    self: Text_Edit,
    gutter_: Int,
    clickable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gutter_clickable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    gutter_ := gutter_
    clickable_ := clickable_
    args := []__bindgen_gde.TypePtr {
        &gutter_,
        &clickable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_gutter_clickable :: proc "contextless" (
    self: Text_Edit,
    gutter_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_gutter_clickable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    gutter_ := gutter_
    args := []__bindgen_gde.TypePtr {
        &gutter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_gutter_overwritable :: proc "contextless" (
    self: Text_Edit,
    gutter_: Int,
    overwritable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gutter_overwritable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    gutter_ := gutter_
    overwritable_ := overwritable_
    args := []__bindgen_gde.TypePtr {
        &gutter_,
        &overwritable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_gutter_overwritable :: proc "contextless" (
    self: Text_Edit,
    gutter_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_gutter_overwritable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    gutter_ := gutter_
    args := []__bindgen_gde.TypePtr {
        &gutter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_merge_gutters :: proc "contextless" (
    self: Text_Edit,
    from_line_: Int,
    to_line_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("merge_gutters", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
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

text_edit_set_gutter_custom_draw :: proc "contextless" (
    self: Text_Edit,
    column_: Int,
    draw_callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gutter_custom_draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 957362965)
    }
    self := self
    column_ := column_
    draw_callback_ := draw_callback_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &draw_callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_total_gutter_width :: proc "contextless" (
    self: Text_Edit,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_total_gutter_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_line_gutter_metadata :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    gutter_: Int,
    metadata_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_gutter_metadata", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2060538656)
    }
    self := self
    line_ := line_
    gutter_ := gutter_
    metadata_ := metadata_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &gutter_,
        &metadata_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_line_gutter_metadata :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    gutter_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_gutter_metadata", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 678354945)
    }
    self := self
    line_ := line_
    gutter_ := gutter_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &gutter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_line_gutter_text :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    gutter_: Int,
    text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_gutter_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2285447957)
    }
    self := self
    line_ := line_
    gutter_ := gutter_
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &gutter_,
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_line_gutter_text :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    gutter_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_gutter_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1391810591)
    }
    self := self
    line_ := line_
    gutter_ := gutter_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &gutter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_line_gutter_icon :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    gutter_: Int,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_gutter_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 176101966)
    }
    self := self
    line_ := line_
    gutter_ := gutter_
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &gutter_,
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_line_gutter_icon :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    gutter_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_gutter_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2584904275)
    }
    self := self
    line_ := line_
    gutter_ := gutter_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &gutter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_line_gutter_item_color :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    gutter_: Int,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_gutter_item_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3733378741)
    }
    self := self
    line_ := line_
    gutter_ := gutter_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &gutter_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_line_gutter_item_color :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    gutter_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_gutter_item_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2165839948)
    }
    self := self
    line_ := line_
    gutter_ := gutter_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &gutter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_line_gutter_clickable :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    gutter_: Int,
    clickable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_gutter_clickable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1383440665)
    }
    self := self
    line_ := line_
    gutter_ := gutter_
    clickable_ := clickable_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &gutter_,
        &clickable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_line_gutter_clickable :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    gutter_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_line_gutter_clickable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2522259332)
    }
    self := self
    line_ := line_
    gutter_ := gutter_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &gutter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_line_background_color :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_line_background_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878471219)
    }
    self := self
    line_ := line_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &line_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_line_background_color :: proc "contextless" (
    self: Text_Edit,
    line_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_background_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3457211756)
    }
    self := self
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_syntax_highlighter :: proc "contextless" (
    self: Text_Edit,
    syntax_highlighter_: Syntax_Highlighter,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_syntax_highlighter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2765644541)
    }
    self := self
    syntax_highlighter_ := syntax_highlighter_
    args := []__bindgen_gde.TypePtr {
        &syntax_highlighter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_syntax_highlighter :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Syntax_Highlighter) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_syntax_highlighter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2721131626)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_highlight_current_line :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_highlight_current_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_highlight_current_line_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_highlight_current_line_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_highlight_all_occurrences :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_highlight_all_occurrences", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_highlight_all_occurrences_enabled :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_highlight_all_occurrences_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_draw_control_chars :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_draw_control_chars", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_draw_control_chars :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_control_chars", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_set_draw_tabs :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_tabs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_drawing_tabs :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_drawing_tabs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_set_draw_spaces :: proc "contextless" (
    self: Text_Edit,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_spaces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_is_drawing_spaces :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_drawing_spaces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_menu :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Popup_Menu) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 229722558)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_is_menu_visible :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_menu_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_menu_option :: proc "contextless" (
    self: Text_Edit,
    option_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("menu_option", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    option_ := option_
    args := []__bindgen_gde.TypePtr {
        &option_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_adjust_carets_after_edit :: proc "contextless" (
    self: Text_Edit,
    caret_: Int,
    from_line_: Int,
    from_col_: Int,
    to_line_: Int,
    to_col_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("adjust_carets_after_edit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1770277138)
    }
    self := self
    caret_ := caret_
    from_line_ := from_line_
    from_col_ := from_col_
    to_line_ := to_line_
    to_col_ := to_col_
    args := []__bindgen_gde.TypePtr {
        &caret_,
        &from_line_,
        &from_col_,
        &to_line_,
        &to_col_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

text_edit_get_caret_index_edit_order :: proc "contextless" (
    self: Text_Edit,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_caret_index_edit_order", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 969006518)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_selection_line :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selection_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

text_edit_get_selection_column :: proc "contextless" (
    self: Text_Edit,
    caret_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selection_column", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    caret_index_ := caret_index_
    args := []__bindgen_gde.TypePtr {
        &caret_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
text_edit_get_placeholder_text :: proc "contextless" (self: Text_Edit) -> String {
    return text_edit_get_placeholder(self)
}
text_edit_set_placeholder_text :: proc "contextless" (self: Text_Edit, value: String) {
    text_edit_set_placeholder(self, value)
}
text_edit_get_editable :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_editable(self)
}
text_edit_get_context_menu_enabled :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_context_menu_enabled(self)
}
text_edit_get_emoji_menu_enabled :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_emoji_menu_enabled(self)
}
text_edit_get_backspace_deletes_composite_character_enabled :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_backspace_deletes_composite_character_enabled(self)
}
text_edit_get_shortcut_keys_enabled :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_shortcut_keys_enabled(self)
}
text_edit_get_selecting_enabled :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_selecting_enabled(self)
}
text_edit_get_deselect_on_focus_loss_enabled :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_deselect_on_focus_loss_enabled(self)
}
text_edit_get_drag_and_drop_selection_enabled :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_drag_and_drop_selection_enabled(self)
}
text_edit_get_middle_mouse_paste_enabled :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_middle_mouse_paste_enabled(self)
}
text_edit_get_empty_selection_clipboard_enabled :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_empty_selection_clipboard_enabled(self)
}
text_edit_get_wrap_mode :: proc "contextless" (self: Text_Edit) -> Text_Edit_Line_Wrapping_Mode {
    return text_edit_get_line_wrapping_mode(self)
}
text_edit_set_wrap_mode :: proc "contextless" (self: Text_Edit, value: Text_Edit_Line_Wrapping_Mode) {
    text_edit_set_line_wrapping_mode(self, value)
}
text_edit_get_indent_wrapped_lines :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_indent_wrapped_lines(self)
}
text_edit_get_virtual_keyboard_enabled :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_virtual_keyboard_enabled(self)
}
text_edit_get_scroll_smooth :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_smooth_scroll_enabled(self)
}
text_edit_set_scroll_smooth :: proc "contextless" (self: Text_Edit, value: Bool) {
    text_edit_set_smooth_scroll_enabled(self, value)
}
text_edit_get_scroll_v_scroll_speed :: proc "contextless" (self: Text_Edit) -> f64 {
    return text_edit_get_v_scroll_speed(self)
}
text_edit_set_scroll_v_scroll_speed :: proc "contextless" (self: Text_Edit, value: f64) {
    text_edit_set_v_scroll_speed(self, value)
}
text_edit_get_scroll_past_end_of_file :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_scroll_past_end_of_file_enabled(self)
}
text_edit_set_scroll_past_end_of_file :: proc "contextless" (self: Text_Edit, value: Bool) {
    text_edit_set_scroll_past_end_of_file_enabled(self, value)
}
text_edit_get_scroll_vertical :: proc "contextless" (self: Text_Edit) -> f64 {
    return text_edit_get_v_scroll(self)
}
text_edit_set_scroll_vertical :: proc "contextless" (self: Text_Edit, value: f64) {
    text_edit_set_v_scroll(self, value)
}
text_edit_get_scroll_horizontal :: proc "contextless" (self: Text_Edit) -> i32 {
    return text_edit_get_h_scroll(self)
}
text_edit_set_scroll_horizontal :: proc "contextless" (self: Text_Edit, value: Int) {
    text_edit_set_h_scroll(self, value)
}
text_edit_get_scroll_fit_content_height :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_fit_content_height_enabled(self)
}
text_edit_set_scroll_fit_content_height :: proc "contextless" (self: Text_Edit, value: Bool) {
    text_edit_set_fit_content_height_enabled(self, value)
}
text_edit_get_scroll_fit_content_width :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_fit_content_width_enabled(self)
}
text_edit_set_scroll_fit_content_width :: proc "contextless" (self: Text_Edit, value: Bool) {
    text_edit_set_fit_content_width_enabled(self, value)
}
text_edit_get_minimap_draw :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_drawing_minimap(self)
}
text_edit_set_minimap_draw :: proc "contextless" (self: Text_Edit, value: Bool) {
    text_edit_set_draw_minimap(self, value)
}
text_edit_get_caret_blink :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_caret_blink_enabled(self)
}
text_edit_set_caret_blink :: proc "contextless" (self: Text_Edit, value: Bool) {
    text_edit_set_caret_blink_enabled(self, value)
}
text_edit_get_caret_draw_when_editable_disabled :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_drawing_caret_when_editable_disabled(self)
}
text_edit_set_caret_draw_when_editable_disabled :: proc "contextless" (self: Text_Edit, value: Bool) {
    text_edit_set_draw_caret_when_editable_disabled(self, value)
}
text_edit_get_caret_move_on_right_click :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_move_caret_on_right_click_enabled(self)
}
text_edit_set_caret_move_on_right_click :: proc "contextless" (self: Text_Edit, value: Bool) {
    text_edit_set_move_caret_on_right_click_enabled(self, value)
}
text_edit_get_caret_mid_grapheme :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_caret_mid_grapheme_enabled(self)
}
text_edit_set_caret_mid_grapheme :: proc "contextless" (self: Text_Edit, value: Bool) {
    text_edit_set_caret_mid_grapheme_enabled(self, value)
}
text_edit_get_caret_multiple :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_multiple_carets_enabled(self)
}
text_edit_set_caret_multiple :: proc "contextless" (self: Text_Edit, value: Bool) {
    text_edit_set_multiple_carets_enabled(self, value)
}
text_edit_get_use_default_word_separators :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_default_word_separators_enabled(self)
}
text_edit_get_use_custom_word_separators :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_custom_word_separators_enabled(self)
}
text_edit_get_highlight_all_occurrences :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_highlight_all_occurrences_enabled(self)
}
text_edit_get_highlight_current_line :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_highlight_current_line_enabled(self)
}
text_edit_get_draw_tabs :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_drawing_tabs(self)
}
text_edit_get_draw_spaces :: proc "contextless" (self: Text_Edit) -> Bool {
    return text_edit_is_drawing_spaces(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
text_edit_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("TextEdit", true)
}

@(private = "file")
__class_name: String_Name