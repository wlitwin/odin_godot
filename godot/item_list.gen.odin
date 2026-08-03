package godot

import __bindgen_gde "godot:gdext"

Item_List_Constants :: enum {
}
Item_List_Icon_Mode :: enum int {
    Icon_Mode_Top = 0,
    Icon_Mode_Left = 1,
}
Item_List_Select_Mode :: enum int {
    Select_Single = 0,
    Select_Multi = 1,
    Select_Toggle = 2,
}
Item_List_Scroll_Hint_Mode :: enum int {
    Scroll_Hint_Mode_Disabled = 0,
    Scroll_Hint_Mode_Both = 1,
    Scroll_Hint_Mode_Top = 2,
    Scroll_Hint_Mode_Bottom = 3,
}



item_list_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

item_list_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_item_list :: proc "contextless" () -> Item_List {
    return cast(Item_List)__bindgen_gde.classdb_construct_object(item_list_name_ref())
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

item_list_add_item :: proc "contextless" (
    self: Item_List,
    text_: String,
    icon_: Texture2d,
    selectable_: Bool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 359861678)
    }
    self := self
    text_ := text_
    icon_ := icon_
    selectable_ := selectable_
    args := []__bindgen_gde.TypePtr {
        &text_,
        &icon_,
        &selectable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_add_icon_item :: proc "contextless" (
    self: Item_List,
    icon_: Texture2d,
    selectable_: Bool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_icon_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4256579627)
    }
    self := self
    icon_ := icon_
    selectable_ := selectable_
    args := []__bindgen_gde.TypePtr {
        &icon_,
        &selectable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_text :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    idx_ := idx_
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_item_text :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_icon :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 666127730)
    }
    self := self
    idx_ := idx_
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_item_icon :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3536238170)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_text_direction :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    direction_: Control_Text_Direction,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_text_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1707680378)
    }
    self := self
    idx_ := idx_
    direction_ := direction_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_item_text_direction :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: Control_Text_Direction) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_text_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4235602388)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_language :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    language_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_language", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    idx_ := idx_
    language_ := language_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &language_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_item_language :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_language", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_auto_translate_mode :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    mode_: Node_Auto_Translate_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_auto_translate_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 287402019)
    }
    self := self
    idx_ := idx_
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_item_auto_translate_mode :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: Node_Auto_Translate_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_auto_translate_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 906302372)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_icon_transposed :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    transposed_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_icon_transposed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    idx_ := idx_
    transposed_ := transposed_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &transposed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_is_item_icon_transposed :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_item_icon_transposed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_icon_region :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    rect_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_icon_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1356297692)
    }
    self := self
    idx_ := idx_
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_item_icon_region :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_icon_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3327874267)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_icon_modulate :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    modulate_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_icon_modulate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878471219)
    }
    self := self
    idx_ := idx_
    modulate_ := modulate_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &modulate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_item_icon_modulate :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_icon_modulate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3457211756)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_selectable :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    selectable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_selectable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    idx_ := idx_
    selectable_ := selectable_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &selectable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_is_item_selectable :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_item_selectable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_disabled :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    disabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    idx_ := idx_
    disabled_ := disabled_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &disabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_is_item_disabled :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_item_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_metadata :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    metadata_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_metadata", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2152698145)
    }
    self := self
    idx_ := idx_
    metadata_ := metadata_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &metadata_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_item_metadata :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_metadata", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4227898402)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_custom_bg_color :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    custom_bg_color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_custom_bg_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878471219)
    }
    self := self
    idx_ := idx_
    custom_bg_color_ := custom_bg_color_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &custom_bg_color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_item_custom_bg_color :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_custom_bg_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3457211756)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_custom_fg_color :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    custom_fg_color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_custom_fg_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878471219)
    }
    self := self
    idx_ := idx_
    custom_fg_color_ := custom_fg_color_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &custom_fg_color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_item_custom_fg_color :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_custom_fg_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3457211756)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_get_item_rect :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    expand_: Bool,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 159227807)
    }
    self := self
    idx_ := idx_
    expand_ := expand_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &expand_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_tooltip_enabled :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_tooltip_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    idx_ := idx_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_is_item_tooltip_enabled :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_item_tooltip_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_item_tooltip :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    tooltip_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    idx_ := idx_
    tooltip_ := tooltip_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &tooltip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_item_tooltip :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_select :: proc "contextless" (
    self: Item_List,
    idx_: Int,
    single_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("select", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 972357352)
    }
    self := self
    idx_ := idx_
    single_ := single_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &single_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_deselect :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("deselect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_deselect_all :: proc "contextless" (
    self: Item_List,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("deselect_all", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_is_selected :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_selected", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_get_selected_items :: proc "contextless" (
    self: Item_List,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selected_items", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 969006518)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_move_item :: proc "contextless" (
    self: Item_List,
    from_idx_: Int,
    to_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    from_idx_ := from_idx_
    to_idx_ := to_idx_
    args := []__bindgen_gde.TypePtr {
        &from_idx_,
        &to_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_set_item_count :: proc "contextless" (
    self: Item_List,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_item_count :: proc "contextless" (
    self: Item_List,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_remove_item :: proc "contextless" (
    self: Item_List,
    idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_clear :: proc "contextless" (
    self: Item_List,
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

item_list_sort_items_by_text :: proc "contextless" (
    self: Item_List,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sort_items_by_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_set_fixed_column_width :: proc "contextless" (
    self: Item_List,
    width_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fixed_column_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    width_ := width_
    args := []__bindgen_gde.TypePtr {
        &width_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_fixed_column_width :: proc "contextless" (
    self: Item_List,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fixed_column_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_same_column_width :: proc "contextless" (
    self: Item_List,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_same_column_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_is_same_column_width :: proc "contextless" (
    self: Item_List,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_same_column_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_max_text_lines :: proc "contextless" (
    self: Item_List,
    lines_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_text_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    lines_ := lines_
    args := []__bindgen_gde.TypePtr {
        &lines_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_max_text_lines :: proc "contextless" (
    self: Item_List,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_text_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_max_columns :: proc "contextless" (
    self: Item_List,
    amount_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_columns", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_max_columns :: proc "contextless" (
    self: Item_List,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_columns", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_select_mode :: proc "contextless" (
    self: Item_List,
    mode_: Item_List_Select_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_select_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 928267388)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_select_mode :: proc "contextless" (
    self: Item_List,
) -> (ret: Item_List_Select_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_select_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1191945842)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_icon_mode :: proc "contextless" (
    self: Item_List,
    mode_: Item_List_Icon_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_icon_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2025053633)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_icon_mode :: proc "contextless" (
    self: Item_List,
) -> (ret: Item_List_Icon_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_icon_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3353929232)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_fixed_icon_size :: proc "contextless" (
    self: Item_List,
    size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fixed_icon_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_fixed_icon_size :: proc "contextless" (
    self: Item_List,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fixed_icon_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_icon_scale :: proc "contextless" (
    self: Item_List,
    scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_icon_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_icon_scale :: proc "contextless" (
    self: Item_List,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_icon_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_allow_rmb_select :: proc "contextless" (
    self: Item_List,
    allow_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_allow_rmb_select", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    allow_ := allow_
    args := []__bindgen_gde.TypePtr {
        &allow_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_allow_rmb_select :: proc "contextless" (
    self: Item_List,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_allow_rmb_select", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_allow_reselect :: proc "contextless" (
    self: Item_List,
    allow_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_allow_reselect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    allow_ := allow_
    args := []__bindgen_gde.TypePtr {
        &allow_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_allow_reselect :: proc "contextless" (
    self: Item_List,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_allow_reselect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_allow_search :: proc "contextless" (
    self: Item_List,
    allow_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_allow_search", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    allow_ := allow_
    args := []__bindgen_gde.TypePtr {
        &allow_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_allow_search :: proc "contextless" (
    self: Item_List,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_allow_search", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_auto_width :: proc "contextless" (
    self: Item_List,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_has_auto_width :: proc "contextless" (
    self: Item_List,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_auto_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_auto_height :: proc "contextless" (
    self: Item_List,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_has_auto_height :: proc "contextless" (
    self: Item_List,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_auto_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_is_anything_selected :: proc "contextless" (
    self: Item_List,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_anything_selected", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_get_item_at_position :: proc "contextless" (
    self: Item_List,
    position_: Vector2,
    exact_: Bool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_at_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2300324924)
    }
    self := self
    position_ := position_
    exact_ := exact_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &exact_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_ensure_current_is_visible :: proc "contextless" (
    self: Item_List,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ensure_current_is_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_center_on_current :: proc "contextless" (
    self: Item_List,
    center_verically_: Bool,
    center_horizontally_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("center_on_current", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3058350285)
    }
    self := self
    center_verically_ := center_verically_
    center_horizontally_ := center_horizontally_
    args := []__bindgen_gde.TypePtr {
        &center_verically_,
        &center_horizontally_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_v_scroll_bar :: proc "contextless" (
    self: Item_List,
) -> (ret: V_Scroll_Bar) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_v_scroll_bar", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2630340773)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_get_h_scroll_bar :: proc "contextless" (
    self: Item_List,
) -> (ret: H_Scroll_Bar) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_h_scroll_bar", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4004517983)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_scroll_hint_mode :: proc "contextless" (
    self: Item_List,
    scroll_hint_mode_: Item_List_Scroll_Hint_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scroll_hint_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2917787337)
    }
    self := self
    scroll_hint_mode_ := scroll_hint_mode_
    args := []__bindgen_gde.TypePtr {
        &scroll_hint_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_scroll_hint_mode :: proc "contextless" (
    self: Item_List,
) -> (ret: Item_List_Scroll_Hint_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scroll_hint_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2522227939)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_tile_scroll_hint :: proc "contextless" (
    self: Item_List,
    tile_scroll_hint_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tile_scroll_hint", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    tile_scroll_hint_ := tile_scroll_hint_
    args := []__bindgen_gde.TypePtr {
        &tile_scroll_hint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_is_scroll_hint_tiled :: proc "contextless" (
    self: Item_List,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_scroll_hint_tiled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_text_overrun_behavior :: proc "contextless" (
    self: Item_List,
    overrun_behavior_: Text_Server_Overrun_Behavior,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_text_overrun_behavior", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1008890932)
    }
    self := self
    overrun_behavior_ := overrun_behavior_
    args := []__bindgen_gde.TypePtr {
        &overrun_behavior_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_get_text_overrun_behavior :: proc "contextless" (
    self: Item_List,
) -> (ret: Text_Server_Overrun_Behavior) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_text_overrun_behavior", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3779142101)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_set_wraparound_items :: proc "contextless" (
    self: Item_List,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_wraparound_items", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

item_list_has_wraparound_items :: proc "contextless" (
    self: Item_List,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_wraparound_items", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

item_list_force_update_list_size :: proc "contextless" (
    self: Item_List,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("force_update_list_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
item_list_get_auto_width :: proc "contextless" (self: Item_List) -> Bool {
    return item_list_has_auto_width(self)
}
item_list_get_auto_height :: proc "contextless" (self: Item_List) -> Bool {
    return item_list_has_auto_height(self)
}
item_list_get_wraparound_items :: proc "contextless" (self: Item_List) -> Bool {
    return item_list_has_wraparound_items(self)
}
item_list_get_tile_scroll_hint :: proc "contextless" (self: Item_List) -> Bool {
    return item_list_is_scroll_hint_tiled(self)
}
item_list_get_same_column_width :: proc "contextless" (self: Item_List) -> Bool {
    return item_list_is_same_column_width(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
item_list_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ItemList", true)
}

@(private = "file")
__class_name: String_Name