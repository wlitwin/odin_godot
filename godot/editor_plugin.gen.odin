package godot

import __bindgen_gde "godot:gdext"

Editor_Plugin_Constants :: enum {
}
Editor_Plugin_Custom_Control_Container :: enum int {
    Container_Toolbar = 0,
    Container_Spatial_Editor_Menu = 1,
    Container_Spatial_Editor_Side_Left = 2,
    Container_Spatial_Editor_Side_Right = 3,
    Container_Spatial_Editor_Bottom = 4,
    Container_Canvas_Editor_Menu = 5,
    Container_Canvas_Editor_Side_Left = 6,
    Container_Canvas_Editor_Side_Right = 7,
    Container_Canvas_Editor_Bottom = 8,
    Container_Inspector_Bottom = 9,
    Container_Project_Setting_Tab_Left = 10,
    Container_Project_Setting_Tab_Right = 11,
}
Editor_Plugin_Dock_Slot :: enum int {
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
    Dock_Slot_Max = 9,
}
Editor_Plugin_After_Gui_Input :: enum int {
    After_Gui_Input_Pass = 0,
    After_Gui_Input_Stop = 1,
    After_Gui_Input_Custom = 2,
}



editor_plugin_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_plugin_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_plugin :: proc "contextless" () -> Editor_Plugin {
    return cast(Editor_Plugin)__bindgen_gde.classdb_construct_object(editor_plugin_name_ref())
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

editor_plugin__forward_canvas_gui_input :: proc "contextless" (
    self: Editor_Plugin,
    event_: Input_Event,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_forward_canvas_gui_input", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1062211774)
    }
    self := self
    event_ := event_
    args := []__bindgen_gde.TypePtr {
        &event_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin__forward_canvas_draw_over_viewport :: proc "contextless" (
    self: Editor_Plugin,
    viewport_control_: Control,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_forward_canvas_draw_over_viewport", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1496901182)
    }
    self := self
    viewport_control_ := viewport_control_
    args := []__bindgen_gde.TypePtr {
        &viewport_control_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin__forward_canvas_force_draw_over_viewport :: proc "contextless" (
    self: Editor_Plugin,
    viewport_control_: Control,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_forward_canvas_force_draw_over_viewport", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1496901182)
    }
    self := self
    viewport_control_ := viewport_control_
    args := []__bindgen_gde.TypePtr {
        &viewport_control_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin__forward_3d_gui_input :: proc "contextless" (
    self: Editor_Plugin,
    viewport_camera_: Camera3d,
    event_: Input_Event,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_forward_3d_gui_input", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1018736637)
    }
    self := self
    viewport_camera_ := viewport_camera_
    event_ := event_
    args := []__bindgen_gde.TypePtr {
        &viewport_camera_,
        &event_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin__forward_3d_draw_over_viewport :: proc "contextless" (
    self: Editor_Plugin,
    viewport_control_: Control,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_forward_3d_draw_over_viewport", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1496901182)
    }
    self := self
    viewport_control_ := viewport_control_
    args := []__bindgen_gde.TypePtr {
        &viewport_control_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin__forward_3d_force_draw_over_viewport :: proc "contextless" (
    self: Editor_Plugin,
    viewport_control_: Control,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_forward_3d_force_draw_over_viewport", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1496901182)
    }
    self := self
    viewport_control_ := viewport_control_
    args := []__bindgen_gde.TypePtr {
        &viewport_control_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin__get_plugin_name :: proc "contextless" (
    self: Editor_Plugin,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_plugin_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin__get_plugin_icon :: proc "contextless" (
    self: Editor_Plugin,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_plugin_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin__has_main_screen :: proc "contextless" (
    self: Editor_Plugin,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_has_main_screen", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin__make_visible :: proc "contextless" (
    self: Editor_Plugin,
    visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_make_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    visible_ := visible_
    args := []__bindgen_gde.TypePtr {
        &visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin__edit :: proc "contextless" (
    self: Editor_Plugin,
    object_: Object,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_edit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3975164845)
    }
    self := self
    object_ := object_
    args := []__bindgen_gde.TypePtr {
        &object_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin__handles :: proc "contextless" (
    self: Editor_Plugin,
    object_: Object,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_handles", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 397768994)
    }
    self := self
    object_ := object_
    args := []__bindgen_gde.TypePtr {
        &object_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin__get_state :: proc "contextless" (
    self: Editor_Plugin,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin__set_state :: proc "contextless" (
    self: Editor_Plugin,
    state_: Dictionary,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155329257)
    }
    self := self
    state_ := state_
    args := []__bindgen_gde.TypePtr {
        &state_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin__clear :: proc "contextless" (
    self: Editor_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin__get_unsaved_status :: proc "contextless" (
    self: Editor_Plugin,
    for_scene_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_unsaved_status", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3135753539)
    }
    self := self
    for_scene_ := for_scene_
    args := []__bindgen_gde.TypePtr {
        &for_scene_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin__save_external_data :: proc "contextless" (
    self: Editor_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_save_external_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin__apply_changes :: proc "contextless" (
    self: Editor_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_apply_changes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin__get_breakpoints :: proc "contextless" (
    self: Editor_Plugin,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_breakpoints", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin__set_window_layout :: proc "contextless" (
    self: Editor_Plugin,
    configuration_: Config_File,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_window_layout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 853519107)
    }
    self := self
    configuration_ := configuration_
    args := []__bindgen_gde.TypePtr {
        &configuration_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin__get_window_layout :: proc "contextless" (
    self: Editor_Plugin,
    configuration_: Config_File,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_window_layout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 853519107)
    }
    self := self
    configuration_ := configuration_
    args := []__bindgen_gde.TypePtr {
        &configuration_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin__build :: proc "contextless" (
    self: Editor_Plugin,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_build", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin__run_scene :: proc "contextless" (
    self: Editor_Plugin,
    scene_: String,
    args_: Packed_String_Array,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_run_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3911848509)
    }
    self := self
    scene_ := scene_
    args_ := args_
    args := []__bindgen_gde.TypePtr {
        &scene_,
        &args_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin__enable_plugin :: proc "contextless" (
    self: Editor_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_enable_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin__disable_plugin :: proc "contextless" (
    self: Editor_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_disable_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_dock :: proc "contextless" (
    self: Editor_Plugin,
    dock_: Editor_Dock,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_dock", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 158651717)
    }
    self := self
    dock_ := dock_
    args := []__bindgen_gde.TypePtr {
        &dock_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_dock :: proc "contextless" (
    self: Editor_Plugin,
    dock_: Editor_Dock,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_dock", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 158651717)
    }
    self := self
    dock_ := dock_
    args := []__bindgen_gde.TypePtr {
        &dock_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_control_to_container :: proc "contextless" (
    self: Editor_Plugin,
    container_: Editor_Plugin_Custom_Control_Container,
    control_: Control,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_control_to_container", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3092750152)
    }
    self := self
    container_ := container_
    control_ := control_
    args := []__bindgen_gde.TypePtr {
        &container_,
        &control_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_control_from_container :: proc "contextless" (
    self: Editor_Plugin,
    container_: Editor_Plugin_Custom_Control_Container,
    control_: Control,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_control_from_container", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3092750152)
    }
    self := self
    container_ := container_
    control_ := control_
    args := []__bindgen_gde.TypePtr {
        &container_,
        &control_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_tool_menu_item :: proc "contextless" (
    self: Editor_Plugin,
    name_: String,
    callable_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_tool_menu_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2137474292)
    }
    self := self
    name_ := name_
    callable_ := callable_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &callable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_tool_submenu_item :: proc "contextless" (
    self: Editor_Plugin,
    name_: String,
    submenu_: Popup_Menu,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_tool_submenu_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1019428915)
    }
    self := self
    name_ := name_
    submenu_ := submenu_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &submenu_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_tool_menu_item :: proc "contextless" (
    self: Editor_Plugin,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_tool_menu_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_get_export_as_menu :: proc "contextless" (
    self: Editor_Plugin,
) -> (ret: Popup_Menu) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_export_as_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1775878644)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin_add_custom_type :: proc "contextless" (
    self: Editor_Plugin,
    type_: String,
    base_: String,
    script_: Script,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_custom_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1986814599)
    }
    self := self
    type_ := type_
    base_ := base_
    script_ := script_
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &base_,
        &script_,
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_custom_type :: proc "contextless" (
    self: Editor_Plugin,
    type_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_custom_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_control_to_dock :: proc "contextless" (
    self: Editor_Plugin,
    slot_: Editor_Plugin_Dock_Slot,
    control_: Control,
    shortcut_: Shortcut,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_control_to_dock", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2994930786)
    }
    self := self
    slot_ := slot_
    control_ := control_
    shortcut_ := shortcut_
    args := []__bindgen_gde.TypePtr {
        &slot_,
        &control_,
        &shortcut_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_control_from_docks :: proc "contextless" (
    self: Editor_Plugin,
    control_: Control,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_control_from_docks", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1496901182)
    }
    self := self
    control_ := control_
    args := []__bindgen_gde.TypePtr {
        &control_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_set_dock_tab_icon :: proc "contextless" (
    self: Editor_Plugin,
    control_: Control,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_dock_tab_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3450529724)
    }
    self := self
    control_ := control_
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &control_,
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_control_to_bottom_panel :: proc "contextless" (
    self: Editor_Plugin,
    control_: Control,
    title_: String,
    shortcut_: Shortcut,
) -> (ret: Button) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_control_to_bottom_panel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 111032269)
    }
    self := self
    control_ := control_
    title_ := title_
    shortcut_ := shortcut_
    args := []__bindgen_gde.TypePtr {
        &control_,
        &title_,
        &shortcut_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin_remove_control_from_bottom_panel :: proc "contextless" (
    self: Editor_Plugin,
    control_: Control,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_control_from_bottom_panel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1496901182)
    }
    self := self
    control_ := control_
    args := []__bindgen_gde.TypePtr {
        &control_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_autoload_singleton :: proc "contextless" (
    self: Editor_Plugin,
    name_: String,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_autoload_singleton", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3186203200)
    }
    self := self
    name_ := name_
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_autoload_singleton :: proc "contextless" (
    self: Editor_Plugin,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_autoload_singleton", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_update_overlays :: proc "contextless" (
    self: Editor_Plugin,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_overlays", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin_make_bottom_panel_item_visible :: proc "contextless" (
    self: Editor_Plugin,
    item_: Control,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_bottom_panel_item_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1496901182)
    }
    self := self
    item_ := item_
    args := []__bindgen_gde.TypePtr {
        &item_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_hide_bottom_panel :: proc "contextless" (
    self: Editor_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hide_bottom_panel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_get_undo_redo :: proc "contextless" (
    self: Editor_Plugin,
) -> (ret: Editor_Undo_Redo_Manager) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_undo_redo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 773492341)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin_add_undo_redo_inspector_hook_callback :: proc "contextless" (
    self: Editor_Plugin,
    callable_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_undo_redo_inspector_hook_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1611583062)
    }
    self := self
    callable_ := callable_
    args := []__bindgen_gde.TypePtr {
        &callable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_undo_redo_inspector_hook_callback :: proc "contextless" (
    self: Editor_Plugin,
    callable_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_undo_redo_inspector_hook_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1611583062)
    }
    self := self
    callable_ := callable_
    args := []__bindgen_gde.TypePtr {
        &callable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_queue_save_layout :: proc "contextless" (
    self: Editor_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("queue_save_layout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_translation_parser_plugin :: proc "contextless" (
    self: Editor_Plugin,
    parser_: Editor_Translation_Parser_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_translation_parser_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3116463128)
    }
    self := self
    parser_ := parser_
    args := []__bindgen_gde.TypePtr {
        &parser_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_translation_parser_plugin :: proc "contextless" (
    self: Editor_Plugin,
    parser_: Editor_Translation_Parser_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_translation_parser_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3116463128)
    }
    self := self
    parser_ := parser_
    args := []__bindgen_gde.TypePtr {
        &parser_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_import_plugin :: proc "contextless" (
    self: Editor_Plugin,
    importer_: Editor_Import_Plugin,
    first_priority_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_import_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3113975762)
    }
    self := self
    importer_ := importer_
    first_priority_ := first_priority_
    args := []__bindgen_gde.TypePtr {
        &importer_,
        &first_priority_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_import_plugin :: proc "contextless" (
    self: Editor_Plugin,
    importer_: Editor_Import_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_import_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2312482773)
    }
    self := self
    importer_ := importer_
    args := []__bindgen_gde.TypePtr {
        &importer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_scene_format_importer_plugin :: proc "contextless" (
    self: Editor_Plugin,
    scene_format_importer_: Editor_Scene_Format_Importer,
    first_priority_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_scene_format_importer_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2764104752)
    }
    self := self
    scene_format_importer_ := scene_format_importer_
    first_priority_ := first_priority_
    args := []__bindgen_gde.TypePtr {
        &scene_format_importer_,
        &first_priority_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_scene_format_importer_plugin :: proc "contextless" (
    self: Editor_Plugin,
    scene_format_importer_: Editor_Scene_Format_Importer,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_scene_format_importer_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2637776123)
    }
    self := self
    scene_format_importer_ := scene_format_importer_
    args := []__bindgen_gde.TypePtr {
        &scene_format_importer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_scene_post_import_plugin :: proc "contextless" (
    self: Editor_Plugin,
    scene_import_plugin_: Editor_Scene_Post_Import_Plugin,
    first_priority_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_scene_post_import_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3492436322)
    }
    self := self
    scene_import_plugin_ := scene_import_plugin_
    first_priority_ := first_priority_
    args := []__bindgen_gde.TypePtr {
        &scene_import_plugin_,
        &first_priority_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_scene_post_import_plugin :: proc "contextless" (
    self: Editor_Plugin,
    scene_import_plugin_: Editor_Scene_Post_Import_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_scene_post_import_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3045178206)
    }
    self := self
    scene_import_plugin_ := scene_import_plugin_
    args := []__bindgen_gde.TypePtr {
        &scene_import_plugin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_export_plugin :: proc "contextless" (
    self: Editor_Plugin,
    plugin_: Editor_Export_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_export_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4095952207)
    }
    self := self
    plugin_ := plugin_
    args := []__bindgen_gde.TypePtr {
        &plugin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_export_plugin :: proc "contextless" (
    self: Editor_Plugin,
    plugin_: Editor_Export_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_export_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4095952207)
    }
    self := self
    plugin_ := plugin_
    args := []__bindgen_gde.TypePtr {
        &plugin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_export_platform :: proc "contextless" (
    self: Editor_Plugin,
    platform_: Editor_Export_Platform,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_export_platform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3431312373)
    }
    self := self
    platform_ := platform_
    args := []__bindgen_gde.TypePtr {
        &platform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_export_platform :: proc "contextless" (
    self: Editor_Plugin,
    platform_: Editor_Export_Platform,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_export_platform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3431312373)
    }
    self := self
    platform_ := platform_
    args := []__bindgen_gde.TypePtr {
        &platform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_node_3d_gizmo_plugin :: proc "contextless" (
    self: Editor_Plugin,
    plugin_: Editor_Node3d_Gizmo_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_node_3d_gizmo_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1541015022)
    }
    self := self
    plugin_ := plugin_
    args := []__bindgen_gde.TypePtr {
        &plugin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_node_3d_gizmo_plugin :: proc "contextless" (
    self: Editor_Plugin,
    plugin_: Editor_Node3d_Gizmo_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_node_3d_gizmo_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1541015022)
    }
    self := self
    plugin_ := plugin_
    args := []__bindgen_gde.TypePtr {
        &plugin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_inspector_plugin :: proc "contextless" (
    self: Editor_Plugin,
    plugin_: Editor_Inspector_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_inspector_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 546395733)
    }
    self := self
    plugin_ := plugin_
    args := []__bindgen_gde.TypePtr {
        &plugin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_inspector_plugin :: proc "contextless" (
    self: Editor_Plugin,
    plugin_: Editor_Inspector_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_inspector_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 546395733)
    }
    self := self
    plugin_ := plugin_
    args := []__bindgen_gde.TypePtr {
        &plugin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_resource_conversion_plugin :: proc "contextless" (
    self: Editor_Plugin,
    plugin_: Editor_Resource_Conversion_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_resource_conversion_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2124849111)
    }
    self := self
    plugin_ := plugin_
    args := []__bindgen_gde.TypePtr {
        &plugin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_resource_conversion_plugin :: proc "contextless" (
    self: Editor_Plugin,
    plugin_: Editor_Resource_Conversion_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_resource_conversion_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2124849111)
    }
    self := self
    plugin_ := plugin_
    args := []__bindgen_gde.TypePtr {
        &plugin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_set_input_event_forwarding_always_enabled :: proc "contextless" (
    self: Editor_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_input_event_forwarding_always_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_set_force_draw_over_forwarding_enabled :: proc "contextless" (
    self: Editor_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_force_draw_over_forwarding_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_add_context_menu_plugin :: proc "contextless" (
    self: Editor_Plugin,
    slot_: Editor_Context_Menu_Plugin_Context_Menu_Slot,
    plugin_: Editor_Context_Menu_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_context_menu_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1904221872)
    }
    self := self
    slot_ := slot_
    plugin_ := plugin_
    args := []__bindgen_gde.TypePtr {
        &slot_,
        &plugin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_context_menu_plugin :: proc "contextless" (
    self: Editor_Plugin,
    plugin_: Editor_Context_Menu_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_context_menu_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2281511854)
    }
    self := self
    plugin_ := plugin_
    args := []__bindgen_gde.TypePtr {
        &plugin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_get_editor_interface :: proc "contextless" (
    self: Editor_Plugin,
) -> (ret: Editor_Interface) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_editor_interface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4223731786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin_get_script_create_dialog :: proc "contextless" (
    self: Editor_Plugin,
) -> (ret: Script_Create_Dialog) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_script_create_dialog", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3121871482)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_plugin_add_debugger_plugin :: proc "contextless" (
    self: Editor_Plugin,
    script_: Editor_Debugger_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_debugger_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3749880309)
    }
    self := self
    script_ := script_
    args := []__bindgen_gde.TypePtr {
        &script_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_remove_debugger_plugin :: proc "contextless" (
    self: Editor_Plugin,
    script_: Editor_Debugger_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_debugger_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3749880309)
    }
    self := self
    script_ := script_
    args := []__bindgen_gde.TypePtr {
        &script_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_plugin_get_plugin_version :: proc "contextless" (
    self: Editor_Plugin,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_plugin_version", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_plugin_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorPlugin", true)
}

@(private = "file")
__class_name: String_Name