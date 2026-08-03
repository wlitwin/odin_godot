package godot

import __bindgen_gde "godot:gdext"

Editor_Interface_Constants :: enum {
}



editor_interface_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_interface_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_interface :: proc "contextless" () -> Editor_Interface {
    return cast(Editor_Interface)__bindgen_gde.classdb_construct_object(editor_interface_name_ref())
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

editor_interface_restart_editor :: proc "contextless" (
    self: Editor_Interface,
    save_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("restart_editor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3216645846)
    }
    self := self
    save_ := save_
    args := []__bindgen_gde.TypePtr {
        &save_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_get_command_palette :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Editor_Command_Palette) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_command_palette", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2471163807)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_resource_filesystem :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Editor_File_System) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_resource_filesystem", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 780151678)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_editor_paths :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Editor_Paths) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_editor_paths", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1595760068)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_resource_previewer :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Editor_Resource_Preview) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_resource_previewer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 943486957)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_selection :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Editor_Selection) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2690272531)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_editor_settings :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Editor_Settings) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_editor_settings", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4086932459)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_editor_toaster :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Editor_Toaster) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_editor_toaster", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3612675797)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_editor_undo_redo :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Editor_Undo_Redo_Manager) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_editor_undo_redo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3819628421)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_make_mesh_previews :: proc "contextless" (
    self: Editor_Interface,
    meshes_: Typed_Array(Mesh),
    preview_size_: Int,
) -> (ret: Typed_Array(Texture2d)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_mesh_previews", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 878078554)
    }
    self := self
    meshes_ := meshes_
    preview_size_ := preview_size_
    args := []__bindgen_gde.TypePtr {
        &meshes_,
        &preview_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_set_plugin_enabled :: proc "contextless" (
    self: Editor_Interface,
    plugin_: String,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_plugin_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2678287736)
    }
    self := self
    plugin_ := plugin_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &plugin_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_is_plugin_enabled :: proc "contextless" (
    self: Editor_Interface,
    plugin_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_plugin_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    plugin_ := plugin_
    args := []__bindgen_gde.TypePtr {
        &plugin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_editor_theme :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Theme) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_editor_theme", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3846893731)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_base_control :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Control) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_base_control", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2783021301)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_editor_main_screen :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: V_Box_Container) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_editor_main_screen", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1706218421)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_script_editor :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Script_Editor) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_script_editor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 90868003)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_editor_viewport_2d :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Sub_Viewport) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_editor_viewport_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3750751911)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_editor_viewport_3d :: proc "contextless" (
    self: Editor_Interface,
    idx_: Int,
) -> (ret: Sub_Viewport) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_editor_viewport_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1970834490)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_set_main_screen_editor :: proc "contextless" (
    self: Editor_Interface,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_main_screen_editor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_set_distraction_free_mode :: proc "contextless" (
    self: Editor_Interface,
    enter_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_distraction_free_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enter_ := enter_
    args := []__bindgen_gde.TypePtr {
        &enter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_is_distraction_free_mode_enabled :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_distraction_free_mode_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_is_multi_window_enabled :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_multi_window_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_editor_scale :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_editor_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_editor_language :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_editor_language", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_is_node_3d_snap_enabled :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_node_3d_snap_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_node_3d_translate_snap :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node_3d_translate_snap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_node_3d_rotate_snap :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node_3d_rotate_snap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_node_3d_scale_snap :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node_3d_scale_snap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_popup_dialog :: proc "contextless" (
    self: Editor_Interface,
    dialog_: Window,
    rect_: Rect2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_dialog", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2015770942)
    }
    self := self
    dialog_ := dialog_
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &dialog_,
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_popup_dialog_centered :: proc "contextless" (
    self: Editor_Interface,
    dialog_: Window,
    minsize_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_dialog_centered", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 346557367)
    }
    self := self
    dialog_ := dialog_
    minsize_ := minsize_
    args := []__bindgen_gde.TypePtr {
        &dialog_,
        &minsize_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_popup_dialog_centered_ratio :: proc "contextless" (
    self: Editor_Interface,
    dialog_: Window,
    ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_dialog_centered_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2093669136)
    }
    self := self
    dialog_ := dialog_
    ratio_ := ratio_
    args := []__bindgen_gde.TypePtr {
        &dialog_,
        &ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_popup_dialog_centered_clamped :: proc "contextless" (
    self: Editor_Interface,
    dialog_: Window,
    minsize_: Vector2i,
    fallback_ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_dialog_centered_clamped", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3763385571)
    }
    self := self
    dialog_ := dialog_
    minsize_ := minsize_
    fallback_ratio_ := fallback_ratio_
    args := []__bindgen_gde.TypePtr {
        &dialog_,
        &minsize_,
        &fallback_ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_get_current_feature_profile :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_feature_profile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_set_current_feature_profile :: proc "contextless" (
    self: Editor_Interface,
    profile_name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_current_feature_profile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    profile_name_ := profile_name_
    args := []__bindgen_gde.TypePtr {
        &profile_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_popup_node_selector :: proc "contextless" (
    self: Editor_Interface,
    callback_: Callable,
    valid_types_: Typed_Array(String_Name),
    current_value_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_node_selector", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2444591477)
    }
    self := self
    callback_ := callback_
    valid_types_ := valid_types_
    current_value_ := current_value_
    args := []__bindgen_gde.TypePtr {
        &callback_,
        &valid_types_,
        &current_value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_popup_property_selector :: proc "contextless" (
    self: Editor_Interface,
    object_: Object,
    callback_: Callable,
    type_filter_: Packed_Int32_Array,
    current_value_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_property_selector", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2955609011)
    }
    self := self
    object_ := object_
    callback_ := callback_
    type_filter_ := type_filter_
    current_value_ := current_value_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &callback_,
        &type_filter_,
        &current_value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_popup_method_selector :: proc "contextless" (
    self: Editor_Interface,
    object_: Object,
    callback_: Callable,
    current_value_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_method_selector", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3585505226)
    }
    self := self
    object_ := object_
    callback_ := callback_
    current_value_ := current_value_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &callback_,
        &current_value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_popup_quick_open :: proc "contextless" (
    self: Editor_Interface,
    callback_: Callable,
    base_types_: Typed_Array(String_Name),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_quick_open", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2271411043)
    }
    self := self
    callback_ := callback_
    base_types_ := base_types_
    args := []__bindgen_gde.TypePtr {
        &callback_,
        &base_types_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_popup_create_dialog :: proc "contextless" (
    self: Editor_Interface,
    callback_: Callable,
    base_type_: String_Name,
    current_type_: String,
    dialog_title_: String,
    type_blocklist_: Typed_Array(String_Name),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_create_dialog", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 495277124)
    }
    self := self
    callback_ := callback_
    base_type_ := base_type_
    current_type_ := current_type_
    dialog_title_ := dialog_title_
    type_blocklist_ := type_blocklist_
    args := []__bindgen_gde.TypePtr {
        &callback_,
        &base_type_,
        &current_type_,
        &dialog_title_,
        &type_blocklist_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_get_file_system_dock :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: File_System_Dock) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_file_system_dock", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3751012327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_select_file :: proc "contextless" (
    self: Editor_Interface,
    file_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("select_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    file_ := file_
    args := []__bindgen_gde.TypePtr {
        &file_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_get_selected_paths :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selected_paths", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_current_path :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_current_directory :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_directory", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_inspector :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Editor_Inspector) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_inspector", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3517113938)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_inspect_object :: proc "contextless" (
    self: Editor_Interface,
    object_: Object,
    for_property_: String,
    inspector_only_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("inspect_object", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 127962172)
    }
    self := self
    object_ := object_
    for_property_ := for_property_
    inspector_only_ := inspector_only_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &for_property_,
        &inspector_only_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_edit_resource :: proc "contextless" (
    self: Editor_Interface,
    resource_: Resource,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("edit_resource", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 968641751)
    }
    self := self
    resource_ := resource_
    args := []__bindgen_gde.TypePtr {
        &resource_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_edit_node :: proc "contextless" (
    self: Editor_Interface,
    node_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("edit_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    node_ := node_
    args := []__bindgen_gde.TypePtr {
        &node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_edit_script :: proc "contextless" (
    self: Editor_Interface,
    script_: Script,
    line_: Int,
    column_: Int,
    grab_focus_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("edit_script", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 219829402)
    }
    self := self
    script_ := script_
    line_ := line_
    column_ := column_
    grab_focus_ := grab_focus_
    args := []__bindgen_gde.TypePtr {
        &script_,
        &line_,
        &column_,
        &grab_focus_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_open_scene_from_path :: proc "contextless" (
    self: Editor_Interface,
    scene_filepath_: String,
    set_inherited_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("open_scene_from_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1168363258)
    }
    self := self
    scene_filepath_ := scene_filepath_
    set_inherited_ := set_inherited_
    args := []__bindgen_gde.TypePtr {
        &scene_filepath_,
        &set_inherited_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_reload_scene_from_path :: proc "contextless" (
    self: Editor_Interface,
    scene_filepath_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reload_scene_from_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    scene_filepath_ := scene_filepath_
    args := []__bindgen_gde.TypePtr {
        &scene_filepath_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_set_object_edited :: proc "contextless" (
    self: Editor_Interface,
    object_: Object,
    edited_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_object_edited", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1462101905)
    }
    self := self
    object_ := object_
    edited_ := edited_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &edited_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_is_object_edited :: proc "contextless" (
    self: Editor_Interface,
    object_: Object,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_object_edited", true)
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

editor_interface_get_open_scenes :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_open_scenes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_unsaved_scenes :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_unsaved_scenes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_open_scene_roots :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Typed_Array(Node)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_open_scene_roots", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_edited_scene_root :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Node) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_edited_scene_root", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3160264692)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_add_root_node :: proc "contextless" (
    self: Editor_Interface,
    node_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_root_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    node_ := node_
    args := []__bindgen_gde.TypePtr {
        &node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_save_scene :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_save_scene_as :: proc "contextless" (
    self: Editor_Interface,
    path_: String,
    with_preview_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_scene_as", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3647332257)
    }
    self := self
    path_ := path_
    with_preview_ := with_preview_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &with_preview_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_save_all_scenes :: proc "contextless" (
    self: Editor_Interface,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_all_scenes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_close_scene :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("close_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166280745)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_mark_scene_as_unsaved :: proc "contextless" (
    self: Editor_Interface,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("mark_scene_as_unsaved", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_play_main_scene :: proc "contextless" (
    self: Editor_Interface,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("play_main_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_play_current_scene :: proc "contextless" (
    self: Editor_Interface,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("play_current_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_play_custom_scene :: proc "contextless" (
    self: Editor_Interface,
    scene_filepath_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("play_custom_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    scene_filepath_ := scene_filepath_
    args := []__bindgen_gde.TypePtr {
        &scene_filepath_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_stop_playing_scene :: proc "contextless" (
    self: Editor_Interface,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("stop_playing_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_is_playing_scene :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_playing_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_get_playing_scene :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_playing_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_interface_set_movie_maker_enabled :: proc "contextless" (
    self: Editor_Interface,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_movie_maker_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_interface_is_movie_maker_enabled :: proc "contextless" (
    self: Editor_Interface,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_movie_maker_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
editor_interface_get_distraction_free_mode :: proc "contextless" (self: Editor_Interface) -> Bool {
    return editor_interface_is_distraction_free_mode_enabled(self)
}
editor_interface_get_movie_maker_enabled :: proc "contextless" (self: Editor_Interface) -> Bool {
    return editor_interface_is_movie_maker_enabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_interface_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorInterface", true)
}

@(private = "file")
__class_name: String_Name