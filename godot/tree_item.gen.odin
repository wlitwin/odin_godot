package godot

import __bindgen_gde "godot:gdext"

Tree_Item_Constants :: enum {
}
Tree_Item_Tree_Cell_Mode :: enum int {
    Cell_Mode_String = 0,
    Cell_Mode_Check = 1,
    Cell_Mode_Range = 2,
    Cell_Mode_Icon = 3,
    Cell_Mode_Custom = 4,
}



tree_item_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

tree_item_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_tree_item :: proc "contextless" () -> Tree_Item {
    return cast(Tree_Item)__bindgen_gde.classdb_construct_object(tree_item_name_ref())
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

tree_item_set_cell_mode :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    mode_: Tree_Item_Tree_Cell_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cell_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 289920701)
    }
    self := self
    column_ := column_
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_cell_mode :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Tree_Item_Tree_Cell_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cell_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3406114978)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_auto_translate_mode :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    mode_: Node_Auto_Translate_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_translate_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 287402019)
    }
    self := self
    column_ := column_
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_auto_translate_mode :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Node_Auto_Translate_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_auto_translate_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 906302372)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_edit_multiline :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    multiline_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_edit_multiline", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    column_ := column_
    multiline_ := multiline_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &multiline_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_is_edit_multiline :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_edit_multiline", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_checked :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    checked_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_checked", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    column_ := column_
    checked_ := checked_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &checked_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_set_indeterminate :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    indeterminate_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_indeterminate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    column_ := column_
    indeterminate_ := indeterminate_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &indeterminate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_is_checked :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_checked", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_is_indeterminate :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_indeterminate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_propagate_check :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    emit_signal_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("propagate_check", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 972357352)
    }
    self := self
    column_ := column_
    emit_signal_ := emit_signal_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &emit_signal_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_set_text :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    column_ := column_
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_text :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_description :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_description", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    column_ := column_
    description_ := description_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &description_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_description :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_description", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_text_direction :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    direction_: Control_Text_Direction,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_text_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1707680378)
    }
    self := self
    column_ := column_
    direction_ := direction_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_text_direction :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Control_Text_Direction) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_text_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4235602388)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_autowrap_mode :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    autowrap_mode_: Text_Server_Autowrap_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_autowrap_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3633006561)
    }
    self := self
    column_ := column_
    autowrap_mode_ := autowrap_mode_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &autowrap_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_autowrap_mode :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Text_Server_Autowrap_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_autowrap_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2902757236)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_autowrap_trim_flags :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    flags_: Text_Server_Line_Break_Flag,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_autowrap_trim_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2186029660)
    }
    self := self
    column_ := column_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_autowrap_trim_flags :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Text_Server_Line_Break_Flag) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_autowrap_trim_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3513056523)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_text_overrun_behavior :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    overrun_behavior_: Text_Server_Overrun_Behavior,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_text_overrun_behavior", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1940772195)
    }
    self := self
    column_ := column_
    overrun_behavior_ := overrun_behavior_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &overrun_behavior_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_text_overrun_behavior :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Text_Server_Overrun_Behavior) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_text_overrun_behavior", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3782727860)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_structured_text_bidi_override :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    parser_: Text_Server_Structured_Text_Parser,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_structured_text_bidi_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 868756907)
    }
    self := self
    column_ := column_
    parser_ := parser_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &parser_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_structured_text_bidi_override :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Text_Server_Structured_Text_Parser) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_structured_text_bidi_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3377823772)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_structured_text_bidi_override_options :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    args_: Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_structured_text_bidi_override_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 537221740)
    }
    self := self
    column_ := column_
    args_ := args_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &args_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_structured_text_bidi_override_options :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_structured_text_bidi_override_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 663333327)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_language :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    language_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_language", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    column_ := column_
    language_ := language_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &language_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_language :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_language", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_suffix :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_suffix", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    column_ := column_
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_suffix :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_suffix", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_icon :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 666127730)
    }
    self := self
    column_ := column_
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_icon :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3536238170)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_icon_overlay :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_icon_overlay", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 666127730)
    }
    self := self
    column_ := column_
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_icon_overlay :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_icon_overlay", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3536238170)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_icon_region :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    region_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_icon_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1356297692)
    }
    self := self
    column_ := column_
    region_ := region_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &region_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_icon_region :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_icon_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3327874267)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_icon_max_width :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    width_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_icon_max_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    column_ := column_
    width_ := width_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &width_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_icon_max_width :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_icon_max_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_icon_modulate :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    modulate_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_icon_modulate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878471219)
    }
    self := self
    column_ := column_
    modulate_ := modulate_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &modulate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_icon_modulate :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_icon_modulate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3457211756)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_range :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    column_ := column_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_range :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_range_config :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    min_: f64,
    max_: f64,
    step_: f64,
    expr_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_range_config", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1547181014)
    }
    self := self
    column_ := column_
    min_ := min_
    max_ := max_
    step_ := step_
    expr_ := expr_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &min_,
        &max_,
        &step_,
        &expr_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_range_config :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_range_config", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3554694381)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_metadata :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    meta_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_metadata", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2152698145)
    }
    self := self
    column_ := column_
    meta_ := meta_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &meta_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_metadata :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_metadata", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4227898402)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_custom_draw :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    object_: Object,
    callback_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 272420368)
    }
    self := self
    column_ := column_
    object_ := object_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &object_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_set_custom_draw_callback :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_draw_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 957362965)
    }
    self := self
    column_ := column_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_custom_draw_callback :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_draw_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1317077508)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_custom_stylebox :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    stylebox_: Style_Box,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_stylebox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1433009359)
    }
    self := self
    column_ := column_
    stylebox_ := stylebox_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &stylebox_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_custom_stylebox :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Style_Box) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_stylebox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3362509644)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_collapsed :: proc "contextless" (
    self: Tree_Item,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collapsed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_is_collapsed :: proc "contextless" (
    self: Tree_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_collapsed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_collapsed_recursive :: proc "contextless" (
    self: Tree_Item,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collapsed_recursive", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_is_any_collapsed :: proc "contextless" (
    self: Tree_Item,
    only_visible_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_any_collapsed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2595650253)
    }
    self := self
    only_visible_ := only_visible_
    args := []__bindgen_gde.TypePtr {
        &only_visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_visible :: proc "contextless" (
    self: Tree_Item,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_is_visible :: proc "contextless" (
    self: Tree_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_is_visible_in_tree :: proc "contextless" (
    self: Tree_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_visible_in_tree", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_uncollapse_tree :: proc "contextless" (
    self: Tree_Item,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("uncollapse_tree", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_set_custom_minimum_height :: proc "contextless" (
    self: Tree_Item,
    height_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_minimum_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    height_ := height_
    args := []__bindgen_gde.TypePtr {
        &height_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_custom_minimum_height :: proc "contextless" (
    self: Tree_Item,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_minimum_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_selectable :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    selectable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_selectable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    column_ := column_
    selectable_ := selectable_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &selectable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_is_selectable :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_selectable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_is_selected :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_selected", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3067735520)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_select :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    set_as_cursor_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("select", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 972357352)
    }
    self := self
    column_ := column_
    set_as_cursor_ := set_as_cursor_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &set_as_cursor_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_deselect :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("deselect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_set_editable :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_editable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    column_ := column_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_is_editable :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_editable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3067735520)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_custom_color :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878471219)
    }
    self := self
    column_ := column_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_custom_color :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3457211756)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_clear_custom_color :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_custom_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_set_custom_font :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    font_: Font,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2637609184)
    }
    self := self
    column_ := column_
    font_ := font_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &font_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_custom_font :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Font) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4244553094)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_custom_font_size :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    font_size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    column_ := column_
    font_size_ := font_size_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &font_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_custom_font_size :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_custom_bg_color :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    color_: Color,
    just_outline_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_bg_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 894174518)
    }
    self := self
    column_ := column_
    color_ := color_
    just_outline_ := just_outline_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &color_,
        &just_outline_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_clear_custom_bg_color :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_custom_bg_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_custom_bg_color :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_bg_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3457211756)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_custom_as_button :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_as_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    column_ := column_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_is_custom_set_as_button :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_custom_set_as_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_clear_buttons :: proc "contextless" (
    self: Tree_Item,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_buttons", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_add_button :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    button_: Texture2d,
    id_: Int,
    disabled_: Bool,
    tooltip_text_: String,
    description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 973481897)
    }
    self := self
    column_ := column_
    button_ := button_
    id_ := id_
    disabled_ := disabled_
    tooltip_text_ := tooltip_text_
    description_ := description_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &button_,
        &id_,
        &disabled_,
        &tooltip_text_,
        &description_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_button_count :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_button_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_button_tooltip_text :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    button_index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_button_tooltip_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1391810591)
    }
    self := self
    column_ := column_
    button_index_ := button_index_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &button_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_button_id :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    button_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_button_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175239445)
    }
    self := self
    column_ := column_
    button_index_ := button_index_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &button_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_button_by_id :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    id_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_button_by_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175239445)
    }
    self := self
    column_ := column_
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_button_color :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    id_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_button_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2165839948)
    }
    self := self
    column_ := column_
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_button :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    button_index_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2584904275)
    }
    self := self
    column_ := column_
    button_index_ := button_index_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &button_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_button_tooltip_text :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    button_index_: Int,
    tooltip_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_button_tooltip_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2285447957)
    }
    self := self
    column_ := column_
    button_index_ := button_index_
    tooltip_ := tooltip_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &button_index_,
        &tooltip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_set_button :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    button_index_: Int,
    button_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 176101966)
    }
    self := self
    column_ := column_
    button_index_ := button_index_
    button_ := button_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &button_index_,
        &button_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_erase_button :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    button_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase_button", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    column_ := column_
    button_index_ := button_index_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &button_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_set_button_description :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    button_index_: Int,
    description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_button_description", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2285447957)
    }
    self := self
    column_ := column_
    button_index_ := button_index_
    description_ := description_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &button_index_,
        &description_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_set_button_disabled :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    button_index_: Int,
    disabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_button_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1383440665)
    }
    self := self
    column_ := column_
    button_index_ := button_index_
    disabled_ := disabled_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &button_index_,
        &disabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_set_button_color :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    button_index_: Int,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_button_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3733378741)
    }
    self := self
    column_ := column_
    button_index_ := button_index_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &button_index_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_is_button_disabled :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    button_index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_button_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2522259332)
    }
    self := self
    column_ := column_
    button_index_ := button_index_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &button_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_tooltip_text :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    tooltip_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tooltip_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    column_ := column_
    tooltip_ := tooltip_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &tooltip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_tooltip_text :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tooltip_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_text_alignment :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    text_alignment_: Horizontal_Alignment,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_text_alignment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3276431499)
    }
    self := self
    column_ := column_
    text_alignment_ := text_alignment_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &text_alignment_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_text_alignment :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Horizontal_Alignment) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_text_alignment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4171562184)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_expand_right :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_expand_right", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    column_ := column_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &column_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_expand_right :: proc "contextless" (
    self: Tree_Item,
    column_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_expand_right", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    column_ := column_
    args := []__bindgen_gde.TypePtr {
        &column_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_disable_folding :: proc "contextless" (
    self: Tree_Item,
    disable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_disable_folding", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    disable_ := disable_
    args := []__bindgen_gde.TypePtr {
        &disable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_is_folding_disabled :: proc "contextless" (
    self: Tree_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_folding_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_set_accept_children :: proc "contextless" (
    self: Tree_Item,
    allowed_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_accept_children", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    allowed_ := allowed_
    args := []__bindgen_gde.TypePtr {
        &allowed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_is_accepting_children :: proc "contextless" (
    self: Tree_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_accepting_children", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_create_child :: proc "contextless" (
    self: Tree_Item,
    index_: Int,
) -> (ret: Tree_Item) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_child", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 954243986)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_add_child :: proc "contextless" (
    self: Tree_Item,
    child_: Tree_Item,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_child", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1819951137)
    }
    self := self
    child_ := child_
    args := []__bindgen_gde.TypePtr {
        &child_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_remove_child :: proc "contextless" (
    self: Tree_Item,
    child_: Tree_Item,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_child", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1819951137)
    }
    self := self
    child_ := child_
    args := []__bindgen_gde.TypePtr {
        &child_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_get_tree :: proc "contextless" (
    self: Tree_Item,
) -> (ret: Tree) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tree", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2243340556)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_next :: proc "contextless" (
    self: Tree_Item,
) -> (ret: Tree_Item) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_next", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1514277247)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_prev :: proc "contextless" (
    self: Tree_Item,
) -> (ret: Tree_Item) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_prev", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2768121250)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_parent :: proc "contextless" (
    self: Tree_Item,
) -> (ret: Tree_Item) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_parent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1514277247)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_first_child :: proc "contextless" (
    self: Tree_Item,
) -> (ret: Tree_Item) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_first_child", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1514277247)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_next_in_tree :: proc "contextless" (
    self: Tree_Item,
    wrap_: Bool,
) -> (ret: Tree_Item) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_next_in_tree", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1666920593)
    }
    self := self
    wrap_ := wrap_
    args := []__bindgen_gde.TypePtr {
        &wrap_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_prev_in_tree :: proc "contextless" (
    self: Tree_Item,
    wrap_: Bool,
) -> (ret: Tree_Item) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_prev_in_tree", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1666920593)
    }
    self := self
    wrap_ := wrap_
    args := []__bindgen_gde.TypePtr {
        &wrap_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_next_visible :: proc "contextless" (
    self: Tree_Item,
    wrap_: Bool,
) -> (ret: Tree_Item) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_next_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1666920593)
    }
    self := self
    wrap_ := wrap_
    args := []__bindgen_gde.TypePtr {
        &wrap_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_prev_visible :: proc "contextless" (
    self: Tree_Item,
    wrap_: Bool,
) -> (ret: Tree_Item) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_prev_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1666920593)
    }
    self := self
    wrap_ := wrap_
    args := []__bindgen_gde.TypePtr {
        &wrap_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_child :: proc "contextless" (
    self: Tree_Item,
    index_: Int,
) -> (ret: Tree_Item) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_child", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 306700752)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_child_count :: proc "contextless" (
    self: Tree_Item,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_child_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_children :: proc "contextless" (
    self: Tree_Item,
) -> (ret: Typed_Array(Tree_Item)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_children", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_get_index :: proc "contextless" (
    self: Tree_Item,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tree_item_move_before :: proc "contextless" (
    self: Tree_Item,
    item_: Tree_Item,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_before", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1819951137)
    }
    self := self
    item_ := item_
    args := []__bindgen_gde.TypePtr {
        &item_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_move_after :: proc "contextless" (
    self: Tree_Item,
    item_: Tree_Item,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_after", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1819951137)
    }
    self := self
    item_ := item_
    args := []__bindgen_gde.TypePtr {
        &item_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tree_item_call_recursive :: proc "contextless" (
    self: Tree_Item,
    method_: String_Name,
    extra: ..Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("call_recursive", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2866548813)
    }
    self := self
    method_ := method_
    __fv_method := variant_from(&method_)
    __argv: [64]__bindgen_gde.VariantPtr
    __n := 0
    __argv[__n] = cast(__bindgen_gde.VariantPtr)&__fv_method
    __n += 1
    for __i in 0 ..< len(extra) {
        if __n >= 64 do break
        __argv[__n] = cast(__bindgen_gde.VariantPtr)&extra[__i]
        __n += 1
    }
    __ret: Variant
    __bindgen_gde.object_method_bind_call(__ptr, self, &__argv[0], i64(__n), cast(__bindgen_gde.VariantPtr)&__ret, nil)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__ret)
    __bindgen_gde.variant_destroy(cast(__bindgen_gde.VariantPtr)&__fv_method)
    return
}


// properties
tree_item_get_collapsed :: proc "contextless" (self: Tree_Item) -> Bool {
    return tree_item_is_collapsed(self)
}
tree_item_get_visible :: proc "contextless" (self: Tree_Item) -> Bool {
    return tree_item_is_visible(self)
}
tree_item_get_disable_folding :: proc "contextless" (self: Tree_Item) -> Bool {
    return tree_item_is_folding_disabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
tree_item_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("TreeItem", true)
}

@(private = "file")
__class_name: String_Name