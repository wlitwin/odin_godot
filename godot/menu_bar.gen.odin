package godot

import __bindgen_gde "godot:gdext"

Menu_Bar_Constants :: enum {
}



menu_bar_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

menu_bar_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_menu_bar :: proc "contextless" () -> Menu_Bar {
    return cast(Menu_Bar)__bindgen_gde.classdb_construct_object(menu_bar_name_ref())
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

menu_bar_set_switch_on_hover :: proc "contextless" (
    self: Menu_Bar,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_switch_on_hover", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

menu_bar_is_switch_on_hover :: proc "contextless" (
    self: Menu_Bar,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_switch_on_hover", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

menu_bar_set_disable_shortcuts :: proc "contextless" (
    self: Menu_Bar,
    disabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_disable_shortcuts", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    disabled_ := disabled_
    args := []__bindgen_gde.TypePtr {
        &disabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

menu_bar_set_prefer_global_menu :: proc "contextless" (
    self: Menu_Bar,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_prefer_global_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

menu_bar_is_prefer_global_menu :: proc "contextless" (
    self: Menu_Bar,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_prefer_global_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

menu_bar_is_native_menu :: proc "contextless" (
    self: Menu_Bar,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_native_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

menu_bar_get_menu_count :: proc "contextless" (
    self: Menu_Bar,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_menu_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

menu_bar_set_text_direction :: proc "contextless" (
    self: Menu_Bar,
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

menu_bar_get_text_direction :: proc "contextless" (
    self: Menu_Bar,
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

menu_bar_set_language :: proc "contextless" (
    self: Menu_Bar,
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

menu_bar_get_language :: proc "contextless" (
    self: Menu_Bar,
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

menu_bar_set_flat :: proc "contextless" (
    self: Menu_Bar,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

menu_bar_is_flat :: proc "contextless" (
    self: Menu_Bar,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_flat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

menu_bar_set_start_index :: proc "contextless" (
    self: Menu_Bar,
    enabled_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_start_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

menu_bar_get_start_index :: proc "contextless" (
    self: Menu_Bar,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_start_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

menu_bar_set_menu_title :: proc "contextless" (
    self: Menu_Bar,
    menu_: Int,
    title_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_menu_title", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    menu_ := menu_
    title_ := title_
    args := []__bindgen_gde.TypePtr {
        &menu_,
        &title_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

menu_bar_get_menu_title :: proc "contextless" (
    self: Menu_Bar,
    menu_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_menu_title", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    menu_ := menu_
    args := []__bindgen_gde.TypePtr {
        &menu_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

menu_bar_set_menu_tooltip :: proc "contextless" (
    self: Menu_Bar,
    menu_: Int,
    tooltip_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_menu_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    menu_ := menu_
    tooltip_ := tooltip_
    args := []__bindgen_gde.TypePtr {
        &menu_,
        &tooltip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

menu_bar_get_menu_tooltip :: proc "contextless" (
    self: Menu_Bar,
    menu_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_menu_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    menu_ := menu_
    args := []__bindgen_gde.TypePtr {
        &menu_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

menu_bar_set_menu_disabled :: proc "contextless" (
    self: Menu_Bar,
    menu_: Int,
    disabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_menu_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    menu_ := menu_
    disabled_ := disabled_
    args := []__bindgen_gde.TypePtr {
        &menu_,
        &disabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

menu_bar_is_menu_disabled :: proc "contextless" (
    self: Menu_Bar,
    menu_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_menu_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    menu_ := menu_
    args := []__bindgen_gde.TypePtr {
        &menu_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

menu_bar_set_menu_hidden :: proc "contextless" (
    self: Menu_Bar,
    menu_: Int,
    hidden_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_menu_hidden", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    menu_ := menu_
    hidden_ := hidden_
    args := []__bindgen_gde.TypePtr {
        &menu_,
        &hidden_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

menu_bar_is_menu_hidden :: proc "contextless" (
    self: Menu_Bar,
    menu_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_menu_hidden", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    menu_ := menu_
    args := []__bindgen_gde.TypePtr {
        &menu_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

menu_bar_get_menu_popup :: proc "contextless" (
    self: Menu_Bar,
    menu_: Int,
) -> (ret: Popup_Menu) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_menu_popup", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2100501353)
    }
    self := self
    menu_ := menu_
    args := []__bindgen_gde.TypePtr {
        &menu_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
menu_bar_get_flat :: proc "contextless" (self: Menu_Bar) -> Bool {
    return menu_bar_is_flat(self)
}
menu_bar_get_switch_on_hover :: proc "contextless" (self: Menu_Bar) -> Bool {
    return menu_bar_is_switch_on_hover(self)
}
menu_bar_get_prefer_global_menu :: proc "contextless" (self: Menu_Bar) -> Bool {
    return menu_bar_is_prefer_global_menu(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
menu_bar_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("MenuBar", true)
}

@(private = "file")
__class_name: String_Name