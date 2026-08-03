package godot

import __bindgen_gde "godot:gdext"

Window_Constants :: enum {
    NOTIFICATION_VISIBILITY_CHANGED = 30,
    NOTIFICATION_THEME_CHANGED = 32,
}
Window_Mode :: enum int {
    Mode_Windowed = 0,
    Mode_Minimized = 1,
    Mode_Maximized = 2,
    Mode_Fullscreen = 3,
    Mode_Exclusive_Fullscreen = 4,
}
Window_Flags :: enum int {
    Flag_Resize_Disabled = 0,
    Flag_Borderless = 1,
    Flag_Always_On_Top = 2,
    Flag_Transparent = 3,
    Flag_No_Focus = 4,
    Flag_Popup = 5,
    Flag_Extend_To_Title = 6,
    Flag_Mouse_Passthrough = 7,
    Flag_Sharp_Corners = 8,
    Flag_Exclude_From_Capture = 9,
    Flag_Popup_Wm_Hint = 10,
    Flag_Minimize_Disabled = 11,
    Flag_Maximize_Disabled = 12,
    Flag_Max = 13,
}
Window_Content_Scale_Mode :: enum int {
    Content_Scale_Mode_Disabled = 0,
    Content_Scale_Mode_Canvas_Items = 1,
    Content_Scale_Mode_Viewport = 2,
}
Window_Content_Scale_Aspect :: enum int {
    Content_Scale_Aspect_Ignore = 0,
    Content_Scale_Aspect_Keep = 1,
    Content_Scale_Aspect_Keep_Width = 2,
    Content_Scale_Aspect_Keep_Height = 3,
    Content_Scale_Aspect_Expand = 4,
}
Window_Content_Scale_Stretch :: enum int {
    Content_Scale_Stretch_Fractional = 0,
    Content_Scale_Stretch_Integer = 1,
}
Window_Layout_Direction :: enum int {
    Layout_Direction_Inherited = 0,
    Layout_Direction_Application_Locale = 1,
    Layout_Direction_Ltr = 2,
    Layout_Direction_Rtl = 3,
    Layout_Direction_System_Locale = 4,
    Layout_Direction_Max = 5,
    Layout_Direction_Locale = 1,
}
Window_Window_Initial_Position :: enum int {
    Window_Initial_Position_Absolute = 0,
    Window_Initial_Position_Center_Primary_Screen = 1,
    Window_Initial_Position_Center_Main_Window_Screen = 2,
    Window_Initial_Position_Center_Other_Screen = 3,
    Window_Initial_Position_Center_Screen_With_Mouse_Focus = 4,
    Window_Initial_Position_Center_Screen_With_Keyboard_Focus = 5,
}



window_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

window_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_window :: proc "contextless" () -> Window {
    return cast(Window)__bindgen_gde.classdb_construct_object(window_name_ref())
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
window_get_focused_window :: proc "contextless" (
) -> (ret: Window) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_focused_window", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1835468782)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}


window__get_contents_minimum_size :: proc "contextless" (
    self: Window,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_contents_minimum_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_title :: proc "contextless" (
    self: Window,
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

window_get_title :: proc "contextless" (
    self: Window,
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

window_set_initial_position :: proc "contextless" (
    self: Window,
    initial_position_: Window_Window_Initial_Position,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_initial_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4084468099)
    }
    self := self
    initial_position_ := initial_position_
    args := []__bindgen_gde.TypePtr {
        &initial_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_initial_position :: proc "contextless" (
    self: Window,
) -> (ret: Window_Window_Initial_Position) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_initial_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4294066647)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_current_screen :: proc "contextless" (
    self: Window,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_current_screen", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_current_screen :: proc "contextless" (
    self: Window,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_screen", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_position :: proc "contextless" (
    self: Window,
    position_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_position :: proc "contextless" (
    self: Window,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_move_to_center :: proc "contextless" (
    self: Window,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_to_center", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_set_size :: proc "contextless" (
    self: Window,
    size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_size :: proc "contextless" (
    self: Window,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_reset_size :: proc "contextless" (
    self: Window,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reset_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_position_with_decorations :: proc "contextless" (
    self: Window,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_position_with_decorations", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_get_size_with_decorations :: proc "contextless" (
    self: Window,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_size_with_decorations", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_max_size :: proc "contextless" (
    self: Window,
    max_size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    max_size_ := max_size_
    args := []__bindgen_gde.TypePtr {
        &max_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_max_size :: proc "contextless" (
    self: Window,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_min_size :: proc "contextless" (
    self: Window,
    min_size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_min_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    min_size_ := min_size_
    args := []__bindgen_gde.TypePtr {
        &min_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_min_size :: proc "contextless" (
    self: Window,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_min_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_mode :: proc "contextless" (
    self: Window,
    mode_: Window_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3095236531)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_mode :: proc "contextless" (
    self: Window,
) -> (ret: Window_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2566346114)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_flag :: proc "contextless" (
    self: Window,
    flag_: Window_Flags,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3426449779)
    }
    self := self
    flag_ := flag_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &flag_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_flag :: proc "contextless" (
    self: Window,
    flag_: Window_Flags,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3062752289)
    }
    self := self
    flag_ := flag_
    args := []__bindgen_gde.TypePtr {
        &flag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_hdr_output_requested :: proc "contextless" (
    self: Window,
    requested_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hdr_output_requested", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    requested_ := requested_
    args := []__bindgen_gde.TypePtr {
        &requested_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_is_hdr_output_requested :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_hdr_output_requested", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_get_output_max_linear_value :: proc "contextless" (
    self: Window,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_output_max_linear_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_is_maximize_allowed :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_maximize_allowed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_request_attention :: proc "contextless" (
    self: Window,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("request_attention", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_set_taskbar_progress_value :: proc "contextless" (
    self: Window,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_taskbar_progress_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_set_taskbar_progress_state :: proc "contextless" (
    self: Window,
    state_: Display_Server_Progress_State,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_taskbar_progress_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 824071031)
    }
    self := self
    state_ := state_
    args := []__bindgen_gde.TypePtr {
        &state_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_move_to_foreground :: proc "contextless" (
    self: Window,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_to_foreground", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_set_visible :: proc "contextless" (
    self: Window,
    visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    visible_ := visible_
    args := []__bindgen_gde.TypePtr {
        &visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_is_visible :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_hide :: proc "contextless" (
    self: Window,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hide", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_show :: proc "contextless" (
    self: Window,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("show", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_set_transient :: proc "contextless" (
    self: Window,
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

window_is_transient :: proc "contextless" (
    self: Window,
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

window_set_transient_to_focused :: proc "contextless" (
    self: Window,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transient_to_focused", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_is_transient_to_focused :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_transient_to_focused", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_exclusive :: proc "contextless" (
    self: Window,
    exclusive_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_exclusive", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    exclusive_ := exclusive_
    args := []__bindgen_gde.TypePtr {
        &exclusive_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_is_exclusive :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_exclusive", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_unparent_when_invisible :: proc "contextless" (
    self: Window,
    unparent_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_unparent_when_invisible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    unparent_ := unparent_
    args := []__bindgen_gde.TypePtr {
        &unparent_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_can_draw :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("can_draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_has_focus :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_focus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_grab_focus :: proc "contextless" (
    self: Window,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("grab_focus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_start_drag :: proc "contextless" (
    self: Window,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("start_drag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_start_resize :: proc "contextless" (
    self: Window,
    edge_: Display_Server_Window_Resize_Edge,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("start_resize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 122288853)
    }
    self := self
    edge_ := edge_
    args := []__bindgen_gde.TypePtr {
        &edge_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_set_ime_active :: proc "contextless" (
    self: Window,
    active_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_ime_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    active_ := active_
    args := []__bindgen_gde.TypePtr {
        &active_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_set_ime_position :: proc "contextless" (
    self: Window,
    position_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_ime_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_is_embedded :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_embedded", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_get_contents_minimum_size :: proc "contextless" (
    self: Window,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_contents_minimum_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_force_native :: proc "contextless" (
    self: Window,
    force_native_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_force_native", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    force_native_ := force_native_
    args := []__bindgen_gde.TypePtr {
        &force_native_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_force_native :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_force_native", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_content_scale_size :: proc "contextless" (
    self: Window,
    size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_content_scale_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_content_scale_size :: proc "contextless" (
    self: Window,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_content_scale_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_content_scale_mode :: proc "contextless" (
    self: Window,
    mode_: Window_Content_Scale_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_content_scale_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2937716473)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_content_scale_mode :: proc "contextless" (
    self: Window,
) -> (ret: Window_Content_Scale_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_content_scale_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 161585230)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_content_scale_aspect :: proc "contextless" (
    self: Window,
    aspect_: Window_Content_Scale_Aspect,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_content_scale_aspect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2370399418)
    }
    self := self
    aspect_ := aspect_
    args := []__bindgen_gde.TypePtr {
        &aspect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_content_scale_aspect :: proc "contextless" (
    self: Window,
) -> (ret: Window_Content_Scale_Aspect) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_content_scale_aspect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4158790715)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_content_scale_stretch :: proc "contextless" (
    self: Window,
    stretch_: Window_Content_Scale_Stretch,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_content_scale_stretch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 349355940)
    }
    self := self
    stretch_ := stretch_
    args := []__bindgen_gde.TypePtr {
        &stretch_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_content_scale_stretch :: proc "contextless" (
    self: Window,
) -> (ret: Window_Content_Scale_Stretch) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_content_scale_stretch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 536857316)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_nonclient_area :: proc "contextless" (
    self: Window,
    area_: Rect2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_nonclient_area", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1763793166)
    }
    self := self
    area_ := area_
    args := []__bindgen_gde.TypePtr {
        &area_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_nonclient_area :: proc "contextless" (
    self: Window,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_nonclient_area", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 410525958)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_keep_title_visible :: proc "contextless" (
    self: Window,
    title_visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_keep_title_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    title_visible_ := title_visible_
    args := []__bindgen_gde.TypePtr {
        &title_visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_keep_title_visible :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_keep_title_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_content_scale_factor :: proc "contextless" (
    self: Window,
    factor_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_content_scale_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    factor_ := factor_
    args := []__bindgen_gde.TypePtr {
        &factor_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_content_scale_factor :: proc "contextless" (
    self: Window,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_content_scale_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_mouse_passthrough_polygon :: proc "contextless" (
    self: Window,
    polygon_: Packed_Vector2_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mouse_passthrough_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1509147220)
    }
    self := self
    polygon_ := polygon_
    args := []__bindgen_gde.TypePtr {
        &polygon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_mouse_passthrough_polygon :: proc "contextless" (
    self: Window,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mouse_passthrough_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2961356807)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_wrap_controls :: proc "contextless" (
    self: Window,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_wrap_controls", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_is_wrapping_controls :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_wrapping_controls", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_child_controls_changed :: proc "contextless" (
    self: Window,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("child_controls_changed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_set_theme :: proc "contextless" (
    self: Window,
    theme_: Theme,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_theme", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2326690814)
    }
    self := self
    theme_ := theme_
    args := []__bindgen_gde.TypePtr {
        &theme_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_theme :: proc "contextless" (
    self: Window,
) -> (ret: Theme) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3846893731)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_theme_type_variation :: proc "contextless" (
    self: Window,
    theme_type_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_theme_type_variation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_theme_type_variation :: proc "contextless" (
    self: Window,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme_type_variation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2002593661)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_begin_bulk_theme_override :: proc "contextless" (
    self: Window,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("begin_bulk_theme_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_end_bulk_theme_override :: proc "contextless" (
    self: Window,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("end_bulk_theme_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_add_theme_icon_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_theme_icon_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1373065600)
    }
    self := self
    name_ := name_
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_add_theme_stylebox_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
    stylebox_: Style_Box,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_theme_stylebox_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4188838905)
    }
    self := self
    name_ := name_
    stylebox_ := stylebox_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &stylebox_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_add_theme_font_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
    font_: Font,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_theme_font_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3518018674)
    }
    self := self
    name_ := name_
    font_ := font_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &font_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_add_theme_font_size_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
    font_size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_theme_font_size_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2415702435)
    }
    self := self
    name_ := name_
    font_size_ := font_size_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &font_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_add_theme_color_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_theme_color_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4260178595)
    }
    self := self
    name_ := name_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_add_theme_constant_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
    constant_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_theme_constant_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2415702435)
    }
    self := self
    name_ := name_
    constant_ := constant_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &constant_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_remove_theme_icon_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_theme_icon_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_remove_theme_stylebox_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_theme_stylebox_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_remove_theme_font_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_theme_font_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_remove_theme_font_size_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_theme_font_size_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_remove_theme_color_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_theme_color_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_remove_theme_constant_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_theme_constant_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_theme_icon :: proc "contextless" (
    self: Window,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3163973443)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_get_theme_stylebox :: proc "contextless" (
    self: Window,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Style_Box) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme_stylebox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 604739069)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_get_theme_font :: proc "contextless" (
    self: Window,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Font) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2826986490)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_get_theme_font_size :: proc "contextless" (
    self: Window,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1327056374)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_get_theme_color :: proc "contextless" (
    self: Window,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2798751242)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_get_theme_constant :: proc "contextless" (
    self: Window,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1327056374)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_has_theme_icon_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_theme_icon_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_has_theme_stylebox_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_theme_stylebox_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_has_theme_font_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_theme_font_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_has_theme_font_size_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_theme_font_size_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_has_theme_color_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_theme_color_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_has_theme_constant_override :: proc "contextless" (
    self: Window,
    name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_theme_constant_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_has_theme_icon :: proc "contextless" (
    self: Window,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_theme_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866386512)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_has_theme_stylebox :: proc "contextless" (
    self: Window,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_theme_stylebox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866386512)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_has_theme_font :: proc "contextless" (
    self: Window,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_theme_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866386512)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_has_theme_font_size :: proc "contextless" (
    self: Window,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_theme_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866386512)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_has_theme_color :: proc "contextless" (
    self: Window,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_theme_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866386512)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_has_theme_constant :: proc "contextless" (
    self: Window,
    name_: String_Name,
    theme_type_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_theme_constant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866386512)
    }
    self := self
    name_ := name_
    theme_type_ := theme_type_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &theme_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_get_theme_default_base_scale :: proc "contextless" (
    self: Window,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme_default_base_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_get_theme_default_font :: proc "contextless" (
    self: Window,
) -> (ret: Font) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme_default_font", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3229501585)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_get_theme_default_font_size :: proc "contextless" (
    self: Window,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_theme_default_font_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_get_window_id :: proc "contextless" (
    self: Window,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_window_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_accessibility_name :: proc "contextless" (
    self: Window,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_accessibility_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_accessibility_name :: proc "contextless" (
    self: Window,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_accessibility_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_accessibility_description :: proc "contextless" (
    self: Window,
    description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_accessibility_description", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    description_ := description_
    args := []__bindgen_gde.TypePtr {
        &description_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_accessibility_description :: proc "contextless" (
    self: Window,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_accessibility_description", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_layout_direction :: proc "contextless" (
    self: Window,
    direction_: Window_Layout_Direction,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layout_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3094704184)
    }
    self := self
    direction_ := direction_
    args := []__bindgen_gde.TypePtr {
        &direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_get_layout_direction :: proc "contextless" (
    self: Window,
) -> (ret: Window_Layout_Direction) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_layout_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3909617982)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_is_layout_rtl :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_layout_rtl", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_auto_translate :: proc "contextless" (
    self: Window,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_translate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_is_auto_translating :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_auto_translating", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_set_use_font_oversampling :: proc "contextless" (
    self: Window,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_font_oversampling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_is_using_font_oversampling :: proc "contextless" (
    self: Window,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_font_oversampling", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

window_popup :: proc "contextless" (
    self: Window,
    rect_: Rect2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1680304321)
    }
    self := self
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_popup_on_parent :: proc "contextless" (
    self: Window,
    parent_rect_: Rect2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_on_parent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1763793166)
    }
    self := self
    parent_rect_ := parent_rect_
    args := []__bindgen_gde.TypePtr {
        &parent_rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_popup_centered :: proc "contextless" (
    self: Window,
    minsize_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_centered", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3447975422)
    }
    self := self
    minsize_ := minsize_
    args := []__bindgen_gde.TypePtr {
        &minsize_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_popup_centered_ratio :: proc "contextless" (
    self: Window,
    ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_centered_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1014814997)
    }
    self := self
    ratio_ := ratio_
    args := []__bindgen_gde.TypePtr {
        &ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_popup_centered_clamped :: proc "contextless" (
    self: Window,
    minsize_: Vector2i,
    fallback_ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_centered_clamped", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2613752477)
    }
    self := self
    minsize_ := minsize_
    fallback_ratio_ := fallback_ratio_
    args := []__bindgen_gde.TypePtr {
        &minsize_,
        &fallback_ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_popup_exclusive :: proc "contextless" (
    self: Window,
    from_node_: Node,
    rect_: Rect2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_exclusive", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2134721627)
    }
    self := self
    from_node_ := from_node_
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &from_node_,
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_popup_exclusive_on_parent :: proc "contextless" (
    self: Window,
    from_node_: Node,
    parent_rect_: Rect2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_exclusive_on_parent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2344671043)
    }
    self := self
    from_node_ := from_node_
    parent_rect_ := parent_rect_
    args := []__bindgen_gde.TypePtr {
        &from_node_,
        &parent_rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_popup_exclusive_centered :: proc "contextless" (
    self: Window,
    from_node_: Node,
    minsize_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_exclusive_centered", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3357594017)
    }
    self := self
    from_node_ := from_node_
    minsize_ := minsize_
    args := []__bindgen_gde.TypePtr {
        &from_node_,
        &minsize_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_popup_exclusive_centered_ratio :: proc "contextless" (
    self: Window,
    from_node_: Node,
    ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_exclusive_centered_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2284776287)
    }
    self := self
    from_node_ := from_node_
    ratio_ := ratio_
    args := []__bindgen_gde.TypePtr {
        &from_node_,
        &ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

window_popup_exclusive_centered_clamped :: proc "contextless" (
    self: Window,
    from_node_: Node,
    minsize_: Vector2i,
    fallback_ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_exclusive_centered_clamped", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2612708785)
    }
    self := self
    from_node_ := from_node_
    minsize_ := minsize_
    fallback_ratio_ := fallback_ratio_
    args := []__bindgen_gde.TypePtr {
        &from_node_,
        &minsize_,
        &fallback_ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
window_get_visible :: proc "contextless" (self: Window) -> Bool {
    return window_is_visible(self)
}
window_get_wrap_controls :: proc "contextless" (self: Window) -> Bool {
    return window_is_wrapping_controls(self)
}
window_get_transient :: proc "contextless" (self: Window) -> Bool {
    return window_is_transient(self)
}
window_get_transient_to_focused :: proc "contextless" (self: Window) -> Bool {
    return window_is_transient_to_focused(self)
}
window_get_exclusive :: proc "contextless" (self: Window) -> Bool {
    return window_is_exclusive(self)
}
window_get_unresizable :: proc "contextless" (self: Window) -> Bool {
    return window_get_flag(self, Window_Flags(0))
}
window_set_unresizable :: proc "contextless" (self: Window, value: Bool) {
    window_set_flag(self, Window_Flags(0), value)
}
window_get_borderless :: proc "contextless" (self: Window) -> Bool {
    return window_get_flag(self, Window_Flags(1))
}
window_set_borderless :: proc "contextless" (self: Window, value: Bool) {
    window_set_flag(self, Window_Flags(1), value)
}
window_get_always_on_top :: proc "contextless" (self: Window) -> Bool {
    return window_get_flag(self, Window_Flags(2))
}
window_set_always_on_top :: proc "contextless" (self: Window, value: Bool) {
    window_set_flag(self, Window_Flags(2), value)
}
window_get_transparent :: proc "contextless" (self: Window) -> Bool {
    return window_get_flag(self, Window_Flags(3))
}
window_set_transparent :: proc "contextless" (self: Window, value: Bool) {
    window_set_flag(self, Window_Flags(3), value)
}
window_get_unfocusable :: proc "contextless" (self: Window) -> Bool {
    return window_get_flag(self, Window_Flags(4))
}
window_set_unfocusable :: proc "contextless" (self: Window, value: Bool) {
    window_set_flag(self, Window_Flags(4), value)
}
window_get_popup_window :: proc "contextless" (self: Window) -> Bool {
    return window_get_flag(self, Window_Flags(5))
}
window_set_popup_window :: proc "contextless" (self: Window, value: Bool) {
    window_set_flag(self, Window_Flags(5), value)
}
window_get_extend_to_title :: proc "contextless" (self: Window) -> Bool {
    return window_get_flag(self, Window_Flags(6))
}
window_set_extend_to_title :: proc "contextless" (self: Window, value: Bool) {
    window_set_flag(self, Window_Flags(6), value)
}
window_get_mouse_passthrough :: proc "contextless" (self: Window) -> Bool {
    return window_get_flag(self, Window_Flags(7))
}
window_set_mouse_passthrough :: proc "contextless" (self: Window, value: Bool) {
    window_set_flag(self, Window_Flags(7), value)
}
window_get_sharp_corners :: proc "contextless" (self: Window) -> Bool {
    return window_get_flag(self, Window_Flags(8))
}
window_set_sharp_corners :: proc "contextless" (self: Window, value: Bool) {
    window_set_flag(self, Window_Flags(8), value)
}
window_get_exclude_from_capture :: proc "contextless" (self: Window) -> Bool {
    return window_get_flag(self, Window_Flags(9))
}
window_set_exclude_from_capture :: proc "contextless" (self: Window, value: Bool) {
    window_set_flag(self, Window_Flags(9), value)
}
window_get_popup_wm_hint :: proc "contextless" (self: Window) -> Bool {
    return window_get_flag(self, Window_Flags(10))
}
window_set_popup_wm_hint :: proc "contextless" (self: Window, value: Bool) {
    window_set_flag(self, Window_Flags(10), value)
}
window_get_minimize_disabled :: proc "contextless" (self: Window) -> Bool {
    return window_get_flag(self, Window_Flags(11))
}
window_set_minimize_disabled :: proc "contextless" (self: Window, value: Bool) {
    window_set_flag(self, Window_Flags(11), value)
}
window_get_maximize_disabled :: proc "contextless" (self: Window) -> Bool {
    return window_get_flag(self, Window_Flags(12))
}
window_set_maximize_disabled :: proc "contextless" (self: Window, value: Bool) {
    window_set_flag(self, Window_Flags(12), value)
}
window_get_hdr_output_requested :: proc "contextless" (self: Window) -> Bool {
    return window_is_hdr_output_requested(self)
}
window_get_auto_translate :: proc "contextless" (self: Window) -> Bool {
    return window_is_auto_translating(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
window_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Window", true)
}

@(private = "file")
__class_name: String_Name