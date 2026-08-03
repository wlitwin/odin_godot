package godot

import __bindgen_gde "godot:gdext"

Tab_Container_Constants :: enum {
}
Tab_Container_Tab_Position :: enum int {
    Position_Top = 0,
    Position_Bottom = 1,
    Position_Max = 2,
}



tab_container_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

tab_container_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_tab_container :: proc "contextless" () -> Tab_Container {
    return cast(Tab_Container)__bindgen_gde.classdb_construct_object(tab_container_name_ref())
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

tab_container_get_tab_count :: proc "contextless" (
    self: Tab_Container,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_current_tab :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_current_tab", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    tab_idx_ := tab_idx_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_current_tab :: proc "contextless" (
    self: Tab_Container,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_tab", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_get_previous_tab :: proc "contextless" (
    self: Tab_Container,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_previous_tab", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_select_previous_available :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("select_previous_available", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_select_next_available :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("select_next_available", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_get_current_tab_control :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Control) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_tab_control", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2783021301)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_get_tab_bar :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Tab_Bar) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_bar", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1865451809)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_get_tab_control :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
) -> (ret: Control) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_control", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1065994134)
    }
    self := self
    tab_idx_ := tab_idx_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_tab_alignment :: proc "contextless" (
    self: Tab_Container,
    alignment_: Tab_Bar_Alignment_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tab_alignment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2413632353)
    }
    self := self
    alignment_ := alignment_
    args := []__bindgen_gde.TypePtr {
        &alignment_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_tab_alignment :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Tab_Bar_Alignment_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_alignment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2178122193)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_tabs_position :: proc "contextless" (
    self: Tab_Container,
    tabs_position_: Tab_Container_Tab_Position,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tabs_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 256673370)
    }
    self := self
    tabs_position_ := tabs_position_
    args := []__bindgen_gde.TypePtr {
        &tabs_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_tabs_position :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Tab_Container_Tab_Position) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tabs_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 919937023)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_clip_tabs :: proc "contextless" (
    self: Tab_Container,
    clip_tabs_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_clip_tabs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    clip_tabs_ := clip_tabs_
    args := []__bindgen_gde.TypePtr {
        &clip_tabs_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_clip_tabs :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_clip_tabs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_tabs_visible :: proc "contextless" (
    self: Tab_Container,
    visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tabs_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    visible_ := visible_
    args := []__bindgen_gde.TypePtr {
        &visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_are_tabs_visible :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("are_tabs_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_all_tabs_in_front :: proc "contextless" (
    self: Tab_Container,
    is_front_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_all_tabs_in_front", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    is_front_ := is_front_
    args := []__bindgen_gde.TypePtr {
        &is_front_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_is_all_tabs_in_front :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_all_tabs_in_front", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_tab_title :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
    title_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tab_title", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    tab_idx_ := tab_idx_
    title_ := title_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
        &title_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_tab_title :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_title", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    tab_idx_ := tab_idx_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_tab_tooltip :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
    tooltip_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tab_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    tab_idx_ := tab_idx_
    tooltip_ := tooltip_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
        &tooltip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_tab_tooltip :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    tab_idx_ := tab_idx_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_tab_icon :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tab_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 666127730)
    }
    self := self
    tab_idx_ := tab_idx_
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_tab_icon :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3536238170)
    }
    self := self
    tab_idx_ := tab_idx_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_tab_icon_max_width :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
    width_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tab_icon_max_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    tab_idx_ := tab_idx_
    width_ := width_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
        &width_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_tab_icon_max_width :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_icon_max_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    tab_idx_ := tab_idx_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_tab_disabled :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
    disabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tab_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    tab_idx_ := tab_idx_
    disabled_ := disabled_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
        &disabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_is_tab_disabled :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_tab_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    tab_idx_ := tab_idx_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_tab_hidden :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
    hidden_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tab_hidden", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    tab_idx_ := tab_idx_
    hidden_ := hidden_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
        &hidden_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_is_tab_hidden :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_tab_hidden", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    tab_idx_ := tab_idx_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_tab_metadata :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
    metadata_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tab_metadata", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2152698145)
    }
    self := self
    tab_idx_ := tab_idx_
    metadata_ := metadata_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
        &metadata_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_tab_metadata :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_metadata", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4227898402)
    }
    self := self
    tab_idx_ := tab_idx_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_tab_button_icon :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tab_button_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 666127730)
    }
    self := self
    tab_idx_ := tab_idx_
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_tab_button_icon :: proc "contextless" (
    self: Tab_Container,
    tab_idx_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_button_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3536238170)
    }
    self := self
    tab_idx_ := tab_idx_
    args := []__bindgen_gde.TypePtr {
        &tab_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_get_tab_idx_at_point :: proc "contextless" (
    self: Tab_Container,
    point_: Vector2,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_idx_at_point", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3820158470)
    }
    self := self
    point_ := point_
    args := []__bindgen_gde.TypePtr {
        &point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_get_tab_idx_from_control :: proc "contextless" (
    self: Tab_Container,
    control_: Control,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_idx_from_control", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2787397975)
    }
    self := self
    control_ := control_
    args := []__bindgen_gde.TypePtr {
        &control_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_popup :: proc "contextless" (
    self: Tab_Container,
    popup_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_popup", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    popup_ := popup_
    args := []__bindgen_gde.TypePtr {
        &popup_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_popup :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Popup) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_popup", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 111095082)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_switch_on_drag_hover :: proc "contextless" (
    self: Tab_Container,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_switch_on_drag_hover", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_switch_on_drag_hover :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_switch_on_drag_hover", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_drag_to_rearrange_enabled :: proc "contextless" (
    self: Tab_Container,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_drag_to_rearrange_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_drag_to_rearrange_enabled :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_drag_to_rearrange_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_tabs_rearrange_group :: proc "contextless" (
    self: Tab_Container,
    group_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tabs_rearrange_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    group_id_ := group_id_
    args := []__bindgen_gde.TypePtr {
        &group_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_tabs_rearrange_group :: proc "contextless" (
    self: Tab_Container,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tabs_rearrange_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_use_hidden_tabs_for_min_size :: proc "contextless" (
    self: Tab_Container,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_hidden_tabs_for_min_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_use_hidden_tabs_for_min_size :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_use_hidden_tabs_for_min_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_tab_focus_mode :: proc "contextless" (
    self: Tab_Container,
    focus_mode_: Control_Focus_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tab_focus_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3232914922)
    }
    self := self
    focus_mode_ := focus_mode_
    args := []__bindgen_gde.TypePtr {
        &focus_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_tab_focus_mode :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Control_Focus_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tab_focus_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2132829277)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tab_container_set_deselect_enabled :: proc "contextless" (
    self: Tab_Container,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_deselect_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tab_container_get_deselect_enabled :: proc "contextless" (
    self: Tab_Container,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_deselect_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
tab_container_get_tabs_visible :: proc "contextless" (self: Tab_Container) -> Bool {
    return tab_container_are_tabs_visible(self)
}
tab_container_get_all_tabs_in_front :: proc "contextless" (self: Tab_Container) -> Bool {
    return tab_container_is_all_tabs_in_front(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
tab_container_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("TabContainer", true)
}

@(private = "file")
__class_name: String_Name