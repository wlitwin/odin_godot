package godot

import __bindgen_gde "godot:gdext"

Editor_Dock_Constants :: enum {
}
Editor_Dock_Dock_Slot :: enum int {
    Dock_Slot_None = -1,
    Dock_Slot_Left_Ul = 0,
    Dock_Slot_Left_Bl = 1,
    Dock_Slot_Left_Ur = 2,
    Dock_Slot_Left_Br = 3,
    Dock_Slot_Right_Ul = 4,
    Dock_Slot_Right_Bl = 5,
    Dock_Slot_Right_Ur = 6,
    Dock_Slot_Right_Br = 7,
    Dock_Slot_Bottom = 8,
    Dock_Slot_Bottom_L = 9,
    Dock_Slot_Bottom_R = 10,
    Dock_Slot_Max = 11,
}

Editor_Dock_Dock_Layout :: enum i64 {
    Dock_Layout_Vertical = 1,
    Dock_Layout_Horizontal = 2,
    Dock_Layout_Floating = 4,
    Dock_Layout_All = 7,
}


editor_dock_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_dock_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_dock :: proc "contextless" () -> Editor_Dock {
    return cast(Editor_Dock)__bindgen_gde.classdb_construct_object(editor_dock_name_ref())
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

editor_dock__update_layout :: proc "contextless" (
    self: Editor_Dock,
    layout_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_update_layout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layout_ := layout_
    args := []__bindgen_gde.TypePtr {
        &layout_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock__save_layout_to_config :: proc "contextless" (
    self: Editor_Dock,
    config_: Config_File,
    section_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_save_layout_to_config", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3076455711)
    }
    self := self
    config_ := config_
    section_ := section_
    args := []__bindgen_gde.TypePtr {
        &config_,
        &section_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock__load_layout_from_config :: proc "contextless" (
    self: Editor_Dock,
    config_: Config_File,
    section_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_load_layout_from_config", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2838822993)
    }
    self := self
    config_ := config_
    section_ := section_
    args := []__bindgen_gde.TypePtr {
        &config_,
        &section_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_open :: proc "contextless" (
    self: Editor_Dock,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("open", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_make_visible :: proc "contextless" (
    self: Editor_Dock,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_close :: proc "contextless" (
    self: Editor_Dock,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("close", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_set_title :: proc "contextless" (
    self: Editor_Dock,
    title_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_title", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    title_ := title_
    args := []__bindgen_gde.TypePtr {
        &title_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_get_title :: proc "contextless" (
    self: Editor_Dock,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_title", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_dock_set_layout_key :: proc "contextless" (
    self: Editor_Dock,
    layout_key_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layout_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    layout_key_ := layout_key_
    args := []__bindgen_gde.TypePtr {
        &layout_key_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_get_layout_key :: proc "contextless" (
    self: Editor_Dock,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_layout_key", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_dock_set_global :: proc "contextless" (
    self: Editor_Dock,
    global_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_global", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    global_ := global_
    args := []__bindgen_gde.TypePtr {
        &global_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_is_global :: proc "contextless" (
    self: Editor_Dock,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_global", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_dock_set_transient :: proc "contextless" (
    self: Editor_Dock,
    transient_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    transient_ := transient_
    args := []__bindgen_gde.TypePtr {
        &transient_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_is_transient :: proc "contextless" (
    self: Editor_Dock,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_transient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_dock_set_closable :: proc "contextless" (
    self: Editor_Dock,
    closable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_closable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    closable_ := closable_
    args := []__bindgen_gde.TypePtr {
        &closable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_is_closable :: proc "contextless" (
    self: Editor_Dock,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_closable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_dock_set_icon_name :: proc "contextless" (
    self: Editor_Dock,
    icon_name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_icon_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    icon_name_ := icon_name_
    args := []__bindgen_gde.TypePtr {
        &icon_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_get_icon_name :: proc "contextless" (
    self: Editor_Dock,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_icon_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2002593661)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_dock_set_dock_icon :: proc "contextless" (
    self: Editor_Dock,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_dock_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_get_dock_icon :: proc "contextless" (
    self: Editor_Dock,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_dock_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_dock_set_force_show_icon :: proc "contextless" (
    self: Editor_Dock,
    force_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_force_show_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_get_force_show_icon :: proc "contextless" (
    self: Editor_Dock,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_force_show_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_dock_set_title_color :: proc "contextless" (
    self: Editor_Dock,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_title_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_get_title_color :: proc "contextless" (
    self: Editor_Dock,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_title_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_dock_set_dock_shortcut :: proc "contextless" (
    self: Editor_Dock,
    shortcut_: Shortcut,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_dock_shortcut", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 857163497)
    }
    self := self
    shortcut_ := shortcut_
    args := []__bindgen_gde.TypePtr {
        &shortcut_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_get_dock_shortcut :: proc "contextless" (
    self: Editor_Dock,
) -> (ret: Shortcut) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_dock_shortcut", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3415666916)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_dock_set_default_slot :: proc "contextless" (
    self: Editor_Dock,
    slot_: Editor_Dock_Dock_Slot,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_default_slot", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4142995464)
    }
    self := self
    slot_ := slot_
    args := []__bindgen_gde.TypePtr {
        &slot_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_get_default_slot :: proc "contextless" (
    self: Editor_Dock,
) -> (ret: Editor_Dock_Dock_Slot) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_default_slot", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3298961740)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_dock_set_available_layouts :: proc "contextless" (
    self: Editor_Dock,
    layouts_: Editor_Dock_Dock_Layout,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_available_layouts", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3440531249)
    }
    self := self
    layouts_ := layouts_
    args := []__bindgen_gde.TypePtr {
        &layouts_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_dock_get_available_layouts :: proc "contextless" (
    self: Editor_Dock,
) -> (ret: Editor_Dock_Dock_Layout) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_available_layouts", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 495015512)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
editor_dock_get_global :: proc "contextless" (self: Editor_Dock) -> Bool {
    return editor_dock_is_global(self)
}
editor_dock_get_transient :: proc "contextless" (self: Editor_Dock) -> Bool {
    return editor_dock_is_transient(self)
}
editor_dock_get_closable :: proc "contextless" (self: Editor_Dock) -> Bool {
    return editor_dock_is_closable(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_dock_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorDock", true)
}

@(private = "file")
__class_name: String_Name