package godot

import __bindgen_gde "godot:gdext"

Native_Menu_Constants :: enum {
}
Native_Menu_Feature :: enum int {
    Feature_Global_Menu = 0,
    Feature_Popup_Menu = 1,
    Feature_Open_Close_Callback = 2,
    Feature_Hover_Callback = 3,
    Feature_Key_Callback = 4,
}
Native_Menu_System_Menus :: enum int {
    Invalid_Menu_Id = 0,
    Main_Menu_Id = 1,
    Application_Menu_Id = 2,
    Window_Menu_Id = 3,
    Help_Menu_Id = 4,
    Dock_Menu_Id = 5,
}



native_menu_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

native_menu_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_native_menu :: proc "contextless" () -> Native_Menu {
    return __bindgen_gde.classdb_construct_object(native_menu_name_ref())
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

native_menu_has_feature :: proc "contextless" (
    self: Native_Menu,
    feature_: Native_Menu_Feature,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_feature", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1708975490)
    }
    self := self
    feature_ := feature_
    args := []__bindgen_gde.TypePtr {
        &feature_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_has_system_menu :: proc "contextless" (
    self: Native_Menu,
    menu_id_: Native_Menu_System_Menus,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_system_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 718213027)
    }
    self := self
    menu_id_ := menu_id_
    args := []__bindgen_gde.TypePtr {
        &menu_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_system_menu :: proc "contextless" (
    self: Native_Menu,
    menu_id_: Native_Menu_System_Menus,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_system_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 469707506)
    }
    self := self
    menu_id_ := menu_id_
    args := []__bindgen_gde.TypePtr {
        &menu_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_system_menu_name :: proc "contextless" (
    self: Native_Menu,
    menu_id_: Native_Menu_System_Menus,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_system_menu_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1281499290)
    }
    self := self
    menu_id_ := menu_id_
    args := []__bindgen_gde.TypePtr {
        &menu_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_system_menu_text :: proc "contextless" (
    self: Native_Menu,
    menu_id_: Native_Menu_System_Menus,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_system_menu_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1281499290)
    }
    self := self
    menu_id_ := menu_id_
    args := []__bindgen_gde.TypePtr {
        &menu_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_set_system_menu_text :: proc "contextless" (
    self: Native_Menu,
    menu_id_: Native_Menu_System_Menus,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_system_menu_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3925225603)
    }
    self := self
    menu_id_ := menu_id_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &menu_id_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_create_menu :: proc "contextless" (
    self: Native_Menu,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_has_menu :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155700596)
    }
    self := self
    rid_ := rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_free_menu :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("free_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    rid_ := rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_get_size :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2440833711)
    }
    self := self
    rid_ := rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_popup :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    position_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2450610377)
    }
    self := self
    rid_ := rid_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_interface_direction :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    is_rtl_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_interface_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    rid_ := rid_
    is_rtl_ := is_rtl_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &is_rtl_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_popup_open_callback :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_popup_open_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3379118538)
    }
    self := self
    rid_ := rid_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_get_popup_open_callback :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_popup_open_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3170603026)
    }
    self := self
    rid_ := rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_set_popup_close_callback :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_popup_close_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3379118538)
    }
    self := self
    rid_ := rid_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_get_popup_close_callback :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_popup_close_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3170603026)
    }
    self := self
    rid_ := rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_set_minimum_width :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    width_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_minimum_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    rid_ := rid_
    width_ := width_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &width_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_get_minimum_width :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_minimum_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866169185)
    }
    self := self
    rid_ := rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_is_opened :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_opened", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155700596)
    }
    self := self
    rid_ := rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_add_submenu_item :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    label_: String,
    submenu_rid_: Rid,
    tag_: Variant,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_submenu_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1002030223)
    }
    self := self
    rid_ := rid_
    label_ := label_
    submenu_rid_ := submenu_rid_
    tag_ := tag_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &label_,
        &submenu_rid_,
        &tag_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_add_item :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    label_: String,
    callback_: Callable,
    key_callback_: Callable,
    tag_: Variant,
    accelerator_: Key,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 980552939)
    }
    self := self
    rid_ := rid_
    label_ := label_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &label_,
        &callback_,
        &key_callback_,
        &tag_,
        &accelerator_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_add_check_item :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    label_: String,
    callback_: Callable,
    key_callback_: Callable,
    tag_: Variant,
    accelerator_: Key,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_check_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 980552939)
    }
    self := self
    rid_ := rid_
    label_ := label_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &label_,
        &callback_,
        &key_callback_,
        &tag_,
        &accelerator_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_add_icon_item :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    icon_: Texture2d,
    label_: String,
    callback_: Callable,
    key_callback_: Callable,
    tag_: Variant,
    accelerator_: Key,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_icon_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1372188274)
    }
    self := self
    rid_ := rid_
    icon_ := icon_
    label_ := label_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &icon_,
        &label_,
        &callback_,
        &key_callback_,
        &tag_,
        &accelerator_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_add_icon_check_item :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    icon_: Texture2d,
    label_: String,
    callback_: Callable,
    key_callback_: Callable,
    tag_: Variant,
    accelerator_: Key,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_icon_check_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1372188274)
    }
    self := self
    rid_ := rid_
    icon_ := icon_
    label_ := label_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &icon_,
        &label_,
        &callback_,
        &key_callback_,
        &tag_,
        &accelerator_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_add_radio_check_item :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    label_: String,
    callback_: Callable,
    key_callback_: Callable,
    tag_: Variant,
    accelerator_: Key,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_radio_check_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 980552939)
    }
    self := self
    rid_ := rid_
    label_ := label_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &label_,
        &callback_,
        &key_callback_,
        &tag_,
        &accelerator_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_add_icon_radio_check_item :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    icon_: Texture2d,
    label_: String,
    callback_: Callable,
    key_callback_: Callable,
    tag_: Variant,
    accelerator_: Key,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_icon_radio_check_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1372188274)
    }
    self := self
    rid_ := rid_
    icon_ := icon_
    label_ := label_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &icon_,
        &label_,
        &callback_,
        &key_callback_,
        &tag_,
        &accelerator_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_add_multistate_item :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    label_: String,
    max_states_: Int,
    default_state_: Int,
    callback_: Callable,
    key_callback_: Callable,
    tag_: Variant,
    accelerator_: Key,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_multistate_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2674635658)
    }
    self := self
    rid_ := rid_
    label_ := label_
    max_states_ := max_states_
    default_state_ := default_state_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &label_,
        &max_states_,
        &default_state_,
        &callback_,
        &key_callback_,
        &tag_,
        &accelerator_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_add_separator :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_separator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 448810126)
    }
    self := self
    rid_ := rid_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_find_item_index_with_text :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    text_: String,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_item_index_with_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1362438794)
    }
    self := self
    rid_ := rid_
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_find_item_index_with_tag :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    tag_: Variant,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_item_index_with_tag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1260085030)
    }
    self := self
    rid_ := rid_
    tag_ := tag_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &tag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_find_item_index_with_submenu :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    submenu_rid_: Rid,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_item_index_with_submenu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 893635918)
    }
    self := self
    rid_ := rid_
    submenu_rid_ := submenu_rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &submenu_rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_is_item_checked :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_item_checked", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3120086654)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_is_item_checkable :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_item_checkable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3120086654)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_is_item_radio_checkable :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_item_radio_checkable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3120086654)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_item_callback :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1639989698)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_item_key_callback :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_key_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1639989698)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_item_tag :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_tag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4069510997)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_item_text :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1464764419)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_item_submenu :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_submenu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1066463050)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_item_accelerator :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: Key) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_accelerator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 316800700)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_is_item_disabled :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_item_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3120086654)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_is_item_hidden :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_item_hidden", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3120086654)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_item_tooltip :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1464764419)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_item_state :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1120910005)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_item_max_states :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_max_states", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1120910005)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_item_icon :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3391850701)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_get_item_indentation_level :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_indentation_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1120910005)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_set_item_checked :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    checked_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_checked", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2658558584)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    checked_ := checked_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &checked_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_checkable :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    checkable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_checkable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2658558584)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    checkable_ := checkable_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &checkable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_radio_checkable :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    checkable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_radio_checkable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2658558584)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    checkable_ := checkable_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &checkable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_callback :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2779810226)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_hover_callbacks :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_hover_callbacks", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2779810226)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_key_callback :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    key_callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_key_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2779810226)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    key_callback_ := key_callback_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &key_callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_tag :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    tag_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_tag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2706844827)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    tag_ := tag_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &tag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_text :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4153150897)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_submenu :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    submenu_rid_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_submenu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2310537182)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    submenu_rid_ := submenu_rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &submenu_rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_accelerator :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    keycode_: Key,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_accelerator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 786300043)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    keycode_ := keycode_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &keycode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_disabled :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    disabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2658558584)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    disabled_ := disabled_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &disabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_hidden :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    hidden_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_hidden", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2658558584)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    hidden_ := hidden_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &hidden_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_tooltip :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    tooltip_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4153150897)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    tooltip_ := tooltip_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &tooltip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_state :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    state_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4288446313)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    state_ := state_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &state_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_max_states :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    max_states_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_max_states", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4288446313)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    max_states_ := max_states_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &max_states_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_icon :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1388763257)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_set_item_indentation_level :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
    level_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_indentation_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4288446313)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    level_ := level_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
        &level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_get_item_count :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    rid_ := rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_is_system_menu :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_system_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155700596)
    }
    self := self
    rid_ := rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

native_menu_remove_item :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
    idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    rid_ := rid_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &rid_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

native_menu_clear :: proc "contextless" (
    self: Native_Menu,
    rid_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    rid_ := rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
native_menu_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("NativeMenu", true)
}

@(private = "file")
__class_name: String_Name