package godot

import __bindgen_gde "godot:gdext"

Editor_Context_Menu_Plugin_Constants :: enum {
}
Editor_Context_Menu_Plugin_Context_Menu_Slot :: enum int {
    Context_Slot_Scene_Tree = 0,
    Context_Slot_Filesystem = 1,
    Context_Slot_Script_Editor = 2,
    Context_Slot_Filesystem_Create = 3,
    Context_Slot_Script_Editor_Code = 4,
    Context_Slot_Scene_Tabs = 5,
    Context_Slot_2d_Editor = 6,
    Context_Slot_Inspector_Property = 7,
}



editor_context_menu_plugin_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_context_menu_plugin_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_context_menu_plugin :: proc "contextless" () -> Editor_Context_Menu_Plugin {
    return cast(Editor_Context_Menu_Plugin)__bindgen_gde.classdb_construct_object(editor_context_menu_plugin_name_ref())
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

editor_context_menu_plugin__popup_menu :: proc "contextless" (
    self: Editor_Context_Menu_Plugin,
    paths_: Packed_String_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_popup_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4015028928)
    }
    self := self
    paths_ := paths_
    args := []__bindgen_gde.TypePtr {
        &paths_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_context_menu_plugin_add_menu_shortcut :: proc "contextless" (
    self: Editor_Context_Menu_Plugin,
    shortcut_: Shortcut,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_menu_shortcut", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 851596305)
    }
    self := self
    shortcut_ := shortcut_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &shortcut_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_context_menu_plugin_add_context_menu_item :: proc "contextless" (
    self: Editor_Context_Menu_Plugin,
    name_: String,
    callback_: Callable,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_context_menu_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2748336951)
    }
    self := self
    name_ := name_
    callback_ := callback_
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &callback_,
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_context_menu_plugin_add_context_menu_item_from_shortcut :: proc "contextless" (
    self: Editor_Context_Menu_Plugin,
    name_: String,
    shortcut_: Shortcut,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_context_menu_item_from_shortcut", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3799546916)
    }
    self := self
    name_ := name_
    shortcut_ := shortcut_
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &shortcut_,
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_context_menu_plugin_add_context_submenu_item :: proc "contextless" (
    self: Editor_Context_Menu_Plugin,
    name_: String,
    menu_: Popup_Menu,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_context_submenu_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1994674995)
    }
    self := self
    name_ := name_
    menu_ := menu_
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &menu_,
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_context_menu_plugin_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorContextMenuPlugin", true)
}

@(private = "file")
__class_name: String_Name