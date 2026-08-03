package godot

import __bindgen_gde "godot:gdext"

Display_Server_Constants :: enum {
    INVALID_SCREEN = -1,
    SCREEN_WITH_MOUSE_FOCUS = -4,
    SCREEN_WITH_KEYBOARD_FOCUS = -3,
    SCREEN_PRIMARY = -2,
    SCREEN_OF_MAIN_WINDOW = -1,
    MAIN_WINDOW_ID = 0,
    INVALID_WINDOW_ID = -1,
    INVALID_INDICATOR_ID = -1,
}
Display_Server_Feature :: enum int {
    Feature_Global_Menu = 0,
    Feature_Subwindows = 1,
    Feature_Touchscreen = 2,
    Feature_Mouse = 3,
    Feature_Mouse_Warp = 4,
    Feature_Clipboard = 5,
    Feature_Virtual_Keyboard = 6,
    Feature_Cursor_Shape = 7,
    Feature_Custom_Cursor_Shape = 8,
    Feature_Native_Dialog = 9,
    Feature_Ime = 10,
    Feature_Window_Transparency = 11,
    Feature_Hidpi = 12,
    Feature_Icon = 13,
    Feature_Native_Icon = 14,
    Feature_Orientation = 15,
    Feature_Swap_Buffers = 16,
    Feature_Clipboard_Primary = 18,
    Feature_Text_To_Speech = 19,
    Feature_Extend_To_Title = 20,
    Feature_Screen_Capture = 21,
    Feature_Status_Indicator = 22,
    Feature_Native_Help = 23,
    Feature_Native_Dialog_Input = 24,
    Feature_Native_Dialog_File = 25,
    Feature_Native_Dialog_File_Extra = 26,
    Feature_Window_Drag = 27,
    Feature_Screen_Exclude_From_Capture = 28,
    Feature_Window_Embedding = 29,
    Feature_Native_Dialog_File_Mime = 30,
    Feature_Emoji_And_Symbol_Picker = 31,
    Feature_Native_Color_Picker = 32,
    Feature_Self_Fitting_Windows = 33,
    Feature_Accessibility_Screen_Reader = 34,
    Feature_Hdr_Output = 35,
    Feature_Pip_Mode = 36,
}
Display_Server_Accessibility_Role :: enum int {
    Role_Unknown = 0,
    Role_Default_Button = 1,
    Role_Audio = 2,
    Role_Video = 3,
    Role_Static_Text = 4,
    Role_Container = 5,
    Role_Panel = 6,
    Role_Button = 7,
    Role_Link = 8,
    Role_Check_Box = 9,
    Role_Radio_Button = 10,
    Role_Check_Button = 11,
    Role_Scroll_Bar = 12,
    Role_Scroll_View = 13,
    Role_Splitter = 14,
    Role_Slider = 15,
    Role_Spin_Button = 16,
    Role_Progress_Indicator = 17,
    Role_Text_Field = 18,
    Role_Multiline_Text_Field = 19,
    Role_Color_Picker = 20,
    Role_Table = 21,
    Role_Cell = 22,
    Role_Row = 23,
    Role_Row_Group = 24,
    Role_Row_Header = 25,
    Role_Column_Header = 26,
    Role_Tree = 27,
    Role_Tree_Item = 28,
    Role_List = 29,
    Role_List_Item = 30,
    Role_List_Box = 31,
    Role_List_Box_Option = 32,
    Role_Tab_Bar = 33,
    Role_Tab = 34,
    Role_Tab_Panel = 35,
    Role_Menu_Bar = 36,
    Role_Menu = 37,
    Role_Menu_Item = 38,
    Role_Menu_Item_Check_Box = 39,
    Role_Menu_Item_Radio = 40,
    Role_Image = 41,
    Role_Window = 42,
    Role_Title_Bar = 43,
    Role_Dialog = 44,
    Role_Tooltip = 45,
    Role_Region = 46,
    Role_Text_Run = 47,
}
Display_Server_Accessibility_Popup_Type :: enum int {
    Popup_Menu = 0,
    Popup_List = 1,
    Popup_Tree = 2,
    Popup_Dialog = 3,
}
Display_Server_Accessibility_Flags :: enum int {
    Flag_Hidden = 0,
    Flag_Multiselectable = 1,
    Flag_Required = 2,
    Flag_Visited = 3,
    Flag_Busy = 4,
    Flag_Modal = 5,
    Flag_Touch_Passthrough = 6,
    Flag_Readonly = 7,
    Flag_Disabled = 8,
    Flag_Clips_Children = 9,
}
Display_Server_Accessibility_Action :: enum int {
    Action_Click = 0,
    Action_Focus = 1,
    Action_Blur = 2,
    Action_Collapse = 3,
    Action_Expand = 4,
    Action_Decrement = 5,
    Action_Increment = 6,
    Action_Hide_Tooltip = 7,
    Action_Show_Tooltip = 8,
    Action_Set_Text_Selection = 9,
    Action_Replace_Selected_Text = 10,
    Action_Scroll_Backward = 11,
    Action_Scroll_Down = 12,
    Action_Scroll_Forward = 13,
    Action_Scroll_Left = 14,
    Action_Scroll_Right = 15,
    Action_Scroll_Up = 16,
    Action_Scroll_Into_View = 17,
    Action_Scroll_To_Point = 18,
    Action_Set_Scroll_Offset = 19,
    Action_Set_Value = 20,
    Action_Show_Context_Menu = 21,
    Action_Custom = 22,
}
Display_Server_Accessibility_Live_Mode :: enum int {
    Live_Off = 0,
    Live_Polite = 1,
    Live_Assertive = 2,
}
Display_Server_Accessibility_Scroll_Unit :: enum int {
    Scroll_Unit_Item = 0,
    Scroll_Unit_Page = 1,
}
Display_Server_Accessibility_Scroll_Hint :: enum int {
    Scroll_Hint_Top_Left = 0,
    Scroll_Hint_Bottom_Right = 1,
    Scroll_Hint_Top_Edge = 2,
    Scroll_Hint_Bottom_Edge = 3,
    Scroll_Hint_Left_Edge = 4,
    Scroll_Hint_Right_Edge = 5,
}
Display_Server_Mouse_Mode :: enum int {
    Mouse_Mode_Visible = 0,
    Mouse_Mode_Hidden = 1,
    Mouse_Mode_Captured = 2,
    Mouse_Mode_Confined = 3,
    Mouse_Mode_Confined_Hidden = 4,
    Mouse_Mode_Max = 5,
}
Display_Server_Screen_Orientation :: enum int {
    Screen_Landscape = 0,
    Screen_Portrait = 1,
    Screen_Reverse_Landscape = 2,
    Screen_Reverse_Portrait = 3,
    Screen_Sensor_Landscape = 4,
    Screen_Sensor_Portrait = 5,
    Screen_Sensor = 6,
}
Display_Server_Virtual_Keyboard_Type :: enum int {
    Keyboard_Type_Default = 0,
    Keyboard_Type_Multiline = 1,
    Keyboard_Type_Number = 2,
    Keyboard_Type_Number_Decimal = 3,
    Keyboard_Type_Phone = 4,
    Keyboard_Type_Email_Address = 5,
    Keyboard_Type_Password = 6,
    Keyboard_Type_Url = 7,
}
Display_Server_Cursor_Shape :: enum int {
    Cursor_Arrow = 0,
    Cursor_Ibeam = 1,
    Cursor_Pointing_Hand = 2,
    Cursor_Cross = 3,
    Cursor_Wait = 4,
    Cursor_Busy = 5,
    Cursor_Drag = 6,
    Cursor_Can_Drop = 7,
    Cursor_Forbidden = 8,
    Cursor_Vsize = 9,
    Cursor_Hsize = 10,
    Cursor_Bdiagsize = 11,
    Cursor_Fdiagsize = 12,
    Cursor_Move = 13,
    Cursor_Vsplit = 14,
    Cursor_Hsplit = 15,
    Cursor_Help = 16,
    Cursor_Max = 17,
}
Display_Server_File_Dialog_Mode :: enum int {
    File_Dialog_Mode_Open_File = 0,
    File_Dialog_Mode_Open_Files = 1,
    File_Dialog_Mode_Open_Dir = 2,
    File_Dialog_Mode_Open_Any = 3,
    File_Dialog_Mode_Save_File = 4,
}
Display_Server_Window_Mode :: enum int {
    Window_Mode_Windowed = 0,
    Window_Mode_Minimized = 1,
    Window_Mode_Maximized = 2,
    Window_Mode_Fullscreen = 3,
    Window_Mode_Exclusive_Fullscreen = 4,
}
Display_Server_Progress_State :: enum int {
    Progress_State_Noprogress = 0,
    Progress_State_Indeterminate = 1,
    Progress_State_Normal = 2,
    Progress_State_Error = 3,
    Progress_State_Paused = 4,
}
Display_Server_Window_Flags :: enum int {
    Window_Flag_Resize_Disabled = 0,
    Window_Flag_Borderless = 1,
    Window_Flag_Always_On_Top = 2,
    Window_Flag_Transparent = 3,
    Window_Flag_No_Focus = 4,
    Window_Flag_Popup = 5,
    Window_Flag_Extend_To_Title = 6,
    Window_Flag_Mouse_Passthrough = 7,
    Window_Flag_Sharp_Corners = 8,
    Window_Flag_Exclude_From_Capture = 9,
    Window_Flag_Popup_Wm_Hint = 10,
    Window_Flag_Minimize_Disabled = 11,
    Window_Flag_Maximize_Disabled = 12,
    Window_Flag_Max = 13,
}
Display_Server_Window_Event :: enum int {
    Window_Event_Mouse_Enter = 0,
    Window_Event_Mouse_Exit = 1,
    Window_Event_Focus_In = 2,
    Window_Event_Focus_Out = 3,
    Window_Event_Close_Request = 4,
    Window_Event_Go_Back_Request = 5,
    Window_Event_Dpi_Change = 6,
    Window_Event_Titlebar_Change = 7,
    Window_Event_Force_Close = 8,
    Window_Event_Output_Max_Linear_Value_Changed = 9,
}
Display_Server_Window_Resize_Edge :: enum int {
    Window_Edge_Top_Left = 0,
    Window_Edge_Top = 1,
    Window_Edge_Top_Right = 2,
    Window_Edge_Left = 3,
    Window_Edge_Right = 4,
    Window_Edge_Bottom_Left = 5,
    Window_Edge_Bottom = 6,
    Window_Edge_Bottom_Right = 7,
    Window_Edge_Max = 8,
}
Display_Server_V_Sync_Mode :: enum int {
    Vsync_Disabled = 0,
    Vsync_Enabled = 1,
    Vsync_Adaptive = 2,
    Vsync_Mailbox = 3,
}
Display_Server_Handle_Type :: enum int {
    Display_Handle = 0,
    Window_Handle = 1,
    Window_View = 2,
    Opengl_Context = 3,
    Egl_Display = 4,
    Egl_Config = 5,
    Glx_Visualid = 6,
    Glx_Fbconfig = 7,
}
Display_Server_Tts_Utterance_Event :: enum int {
    Tts_Utterance_Started = 0,
    Tts_Utterance_Ended = 1,
    Tts_Utterance_Canceled = 2,
    Tts_Utterance_Boundary = 3,
}



display_server_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

display_server_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_display_server :: proc "contextless" () -> Display_Server {
    return cast(Display_Server)__bindgen_gde.classdb_construct_object(display_server_name_ref())
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

display_server_has_feature :: proc "contextless" (
    self: Display_Server,
    feature_: Display_Server_Feature,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_feature", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 334065950)
    }
    self := self
    feature_ := feature_
    args := []__bindgen_gde.TypePtr {
        &feature_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_get_name :: proc "contextless" (
    self: Display_Server,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_help_set_search_callbacks :: proc "contextless" (
    self: Display_Server,
    search_callback_: Callable,
    action_callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("help_set_search_callbacks", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1687350599)
    }
    self := self
    search_callback_ := search_callback_
    action_callback_ := action_callback_
    args := []__bindgen_gde.TypePtr {
        &search_callback_,
        &action_callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_popup_callbacks :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    open_callback_: Callable,
    close_callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_popup_callbacks", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3893727526)
    }
    self := self
    menu_root_ := menu_root_
    open_callback_ := open_callback_
    close_callback_ := close_callback_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &open_callback_,
        &close_callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_add_submenu_item :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    label_: String,
    submenu_: String,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_add_submenu_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2828985934)
    }
    self := self
    menu_root_ := menu_root_
    label_ := label_
    submenu_ := submenu_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &label_,
        &submenu_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_add_item :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    label_: String,
    callback_: Callable,
    key_callback_: Callable,
    tag_: Variant,
    accelerator_: Key,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_add_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3616842746)
    }
    self := self
    menu_root_ := menu_root_
    label_ := label_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
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

display_server_global_menu_add_check_item :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    label_: String,
    callback_: Callable,
    key_callback_: Callable,
    tag_: Variant,
    accelerator_: Key,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_add_check_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3616842746)
    }
    self := self
    menu_root_ := menu_root_
    label_ := label_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
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

display_server_global_menu_add_icon_item :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
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
        _gde_name := new_string_name_cstring("global_menu_add_icon_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3867083847)
    }
    self := self
    menu_root_ := menu_root_
    icon_ := icon_
    label_ := label_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
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

display_server_global_menu_add_icon_check_item :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
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
        _gde_name := new_string_name_cstring("global_menu_add_icon_check_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3867083847)
    }
    self := self
    menu_root_ := menu_root_
    icon_ := icon_
    label_ := label_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
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

display_server_global_menu_add_radio_check_item :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    label_: String,
    callback_: Callable,
    key_callback_: Callable,
    tag_: Variant,
    accelerator_: Key,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_add_radio_check_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3616842746)
    }
    self := self
    menu_root_ := menu_root_
    label_ := label_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
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

display_server_global_menu_add_icon_radio_check_item :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
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
        _gde_name := new_string_name_cstring("global_menu_add_icon_radio_check_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3867083847)
    }
    self := self
    menu_root_ := menu_root_
    icon_ := icon_
    label_ := label_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
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

display_server_global_menu_add_multistate_item :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
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
        _gde_name := new_string_name_cstring("global_menu_add_multistate_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3297554655)
    }
    self := self
    menu_root_ := menu_root_
    label_ := label_
    max_states_ := max_states_
    default_state_ := default_state_
    callback_ := callback_
    key_callback_ := key_callback_
    tag_ := tag_
    accelerator_ := accelerator_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
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

display_server_global_menu_add_separator :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_add_separator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3214812433)
    }
    self := self
    menu_root_ := menu_root_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_get_item_index_from_text :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    text_: String,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_index_from_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878152881)
    }
    self := self
    menu_root_ := menu_root_
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_get_item_index_from_tag :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    tag_: Variant,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_index_from_tag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2941063483)
    }
    self := self
    menu_root_ := menu_root_
    tag_ := tag_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &tag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_is_item_checked :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_is_item_checked", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3511468594)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_is_item_checkable :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_is_item_checkable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3511468594)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_is_item_radio_checkable :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_is_item_radio_checkable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3511468594)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_get_item_callback :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 748666903)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_get_item_key_callback :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_key_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 748666903)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_get_item_tag :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_tag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 330672633)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_get_item_text :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 591067909)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_get_item_submenu :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_submenu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 591067909)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_get_item_accelerator :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: Key) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_accelerator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 936065394)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_is_item_disabled :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_is_item_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3511468594)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_is_item_hidden :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_is_item_hidden", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3511468594)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_get_item_tooltip :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 591067909)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_get_item_state :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3422818498)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_get_item_max_states :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_max_states", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3422818498)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_get_item_icon :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3591713183)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_get_item_indentation_level :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_indentation_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3422818498)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_set_item_checked :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    checked_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_checked", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4108344793)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    checked_ := checked_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &checked_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_checkable :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    checkable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_checkable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4108344793)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    checkable_ := checkable_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &checkable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_radio_checkable :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    checkable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_radio_checkable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4108344793)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    checkable_ := checkable_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &checkable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_callback :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3809915389)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_hover_callbacks :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_hover_callbacks", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3809915389)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_key_callback :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    key_callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_key_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3809915389)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    key_callback_ := key_callback_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &key_callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_tag :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    tag_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_tag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 453659863)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    tag_ := tag_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &tag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_text :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 965966136)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    text_ := text_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_submenu :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    submenu_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_submenu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 965966136)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    submenu_ := submenu_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &submenu_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_accelerator :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    keycode_: Key,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_accelerator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 566943293)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    keycode_ := keycode_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &keycode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_disabled :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    disabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4108344793)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    disabled_ := disabled_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &disabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_hidden :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    hidden_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_hidden", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4108344793)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    hidden_ := hidden_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &hidden_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_tooltip :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    tooltip_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 965966136)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    tooltip_ := tooltip_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &tooltip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_state :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    state_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3474840532)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    state_ := state_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &state_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_max_states :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    max_states_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_max_states", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3474840532)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    max_states_ := max_states_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &max_states_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_icon :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3201338066)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_set_item_indentation_level :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
    level_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_set_item_indentation_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3474840532)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    level_ := level_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
        &level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_get_item_count :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_item_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1321353865)
    }
    self := self
    menu_root_ := menu_root_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_global_menu_remove_item :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
    idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_remove_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2956805083)
    }
    self := self
    menu_root_ := menu_root_
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_clear :: proc "contextless" (
    self: Display_Server,
    menu_root_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    menu_root_ := menu_root_
    args := []__bindgen_gde.TypePtr {
        &menu_root_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_global_menu_get_system_menu_roots :: proc "contextless" (
    self: Display_Server,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_menu_get_system_menu_roots", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_tts_is_speaking :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tts_is_speaking", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_tts_is_paused :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tts_is_paused", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_tts_get_voices :: proc "contextless" (
    self: Display_Server,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tts_get_voices", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_tts_get_voices_for_language :: proc "contextless" (
    self: Display_Server,
    language_: String,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tts_get_voices_for_language", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4291131558)
    }
    self := self
    language_ := language_
    args := []__bindgen_gde.TypePtr {
        &language_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_tts_speak :: proc "contextless" (
    self: Display_Server,
    text_: String,
    voice_: String,
    volume_: Int,
    pitch_: f64,
    rate_: f64,
    utterance_id_: Int,
    interrupt_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tts_speak", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 903992738)
    }
    self := self
    text_ := text_
    voice_ := voice_
    volume_ := volume_
    pitch_ := pitch_
    rate_ := rate_
    utterance_id_ := utterance_id_
    interrupt_ := interrupt_
    args := []__bindgen_gde.TypePtr {
        &text_,
        &voice_,
        &volume_,
        &pitch_,
        &rate_,
        &utterance_id_,
        &interrupt_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_tts_pause :: proc "contextless" (
    self: Display_Server,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tts_pause", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_tts_resume :: proc "contextless" (
    self: Display_Server,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tts_resume", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_tts_stop :: proc "contextless" (
    self: Display_Server,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tts_stop", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_tts_set_utterance_callback :: proc "contextless" (
    self: Display_Server,
    event_: Display_Server_Tts_Utterance_Event,
    callable_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tts_set_utterance_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 109679083)
    }
    self := self
    event_ := event_
    callable_ := callable_
    args := []__bindgen_gde.TypePtr {
        &event_,
        &callable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_is_dark_mode_supported :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_dark_mode_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_is_dark_mode :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_dark_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_get_accent_color :: proc "contextless" (
    self: Display_Server,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_accent_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_get_base_color :: proc "contextless" (
    self: Display_Server,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_base_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_set_system_theme_change_callback :: proc "contextless" (
    self: Display_Server,
    callable_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_system_theme_change_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1611583062)
    }
    self := self
    callable_ := callable_
    args := []__bindgen_gde.TypePtr {
        &callable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_mouse_set_mode :: proc "contextless" (
    self: Display_Server,
    mouse_mode_: Display_Server_Mouse_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("mouse_set_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 348288463)
    }
    self := self
    mouse_mode_ := mouse_mode_
    args := []__bindgen_gde.TypePtr {
        &mouse_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_mouse_get_mode :: proc "contextless" (
    self: Display_Server,
) -> (ret: Display_Server_Mouse_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("mouse_get_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1353961651)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_warp_mouse :: proc "contextless" (
    self: Display_Server,
    position_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("warp_mouse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_mouse_get_position :: proc "contextless" (
    self: Display_Server,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("mouse_get_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_mouse_get_button_state :: proc "contextless" (
    self: Display_Server,
) -> (ret: Mouse_Button_Mask) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("mouse_get_button_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2512161324)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_clipboard_set :: proc "contextless" (
    self: Display_Server,
    clipboard_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clipboard_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    clipboard_ := clipboard_
    args := []__bindgen_gde.TypePtr {
        &clipboard_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_clipboard_get :: proc "contextless" (
    self: Display_Server,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clipboard_get", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_clipboard_get_image :: proc "contextless" (
    self: Display_Server,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clipboard_get_image", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4190603485)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_clipboard_has :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clipboard_has", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_clipboard_has_image :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clipboard_has_image", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_clipboard_set_primary :: proc "contextless" (
    self: Display_Server,
    clipboard_primary_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clipboard_set_primary", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    clipboard_primary_ := clipboard_primary_
    args := []__bindgen_gde.TypePtr {
        &clipboard_primary_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_clipboard_get_primary :: proc "contextless" (
    self: Display_Server,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clipboard_get_primary", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_get_display_cutouts :: proc "contextless" (
    self: Display_Server,
) -> (ret: Typed_Array(Rect2)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_display_cutouts", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_get_display_safe_area :: proc "contextless" (
    self: Display_Server,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_display_safe_area", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 410525958)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_get_screen_count :: proc "contextless" (
    self: Display_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_screen_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_get_primary_screen :: proc "contextless" (
    self: Display_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_primary_screen", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_get_keyboard_focus_screen :: proc "contextless" (
    self: Display_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_keyboard_focus_screen", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_get_screen_from_rect :: proc "contextless" (
    self: Display_Server,
    rect_: Rect2,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_screen_from_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 741354659)
    }
    self := self
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_screen_get_position :: proc "contextless" (
    self: Display_Server,
    screen_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1725937825)
    }
    self := self
    screen_ := screen_
    args := []__bindgen_gde.TypePtr {
        &screen_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_screen_get_size :: proc "contextless" (
    self: Display_Server,
    screen_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1725937825)
    }
    self := self
    screen_ := screen_
    args := []__bindgen_gde.TypePtr {
        &screen_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_screen_get_usable_rect :: proc "contextless" (
    self: Display_Server,
    screen_: Int,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_usable_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2439012528)
    }
    self := self
    screen_ := screen_
    args := []__bindgen_gde.TypePtr {
        &screen_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_screen_get_dpi :: proc "contextless" (
    self: Display_Server,
    screen_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_dpi", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 181039630)
    }
    self := self
    screen_ := screen_
    args := []__bindgen_gde.TypePtr {
        &screen_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_screen_get_scale :: proc "contextless" (
    self: Display_Server,
    screen_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 909105437)
    }
    self := self
    screen_ := screen_
    args := []__bindgen_gde.TypePtr {
        &screen_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_is_touchscreen_available :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_touchscreen_available", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_screen_get_max_scale :: proc "contextless" (
    self: Display_Server,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_max_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_screen_get_refresh_rate :: proc "contextless" (
    self: Display_Server,
    screen_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_refresh_rate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 909105437)
    }
    self := self
    screen_ := screen_
    args := []__bindgen_gde.TypePtr {
        &screen_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_screen_get_pixel :: proc "contextless" (
    self: Display_Server,
    position_: Vector2i,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_pixel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1532707496)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_screen_get_image :: proc "contextless" (
    self: Display_Server,
    screen_: Int,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_image", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3813388802)
    }
    self := self
    screen_ := screen_
    args := []__bindgen_gde.TypePtr {
        &screen_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_screen_get_image_rect :: proc "contextless" (
    self: Display_Server,
    rect_: Rect2i,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_image_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2601441065)
    }
    self := self
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_screen_set_orientation :: proc "contextless" (
    self: Display_Server,
    orientation_: Display_Server_Screen_Orientation,
    screen_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_set_orientation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2211511631)
    }
    self := self
    orientation_ := orientation_
    screen_ := screen_
    args := []__bindgen_gde.TypePtr {
        &orientation_,
        &screen_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_screen_get_orientation :: proc "contextless" (
    self: Display_Server,
    screen_: Int,
) -> (ret: Display_Server_Screen_Orientation) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_get_orientation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 133818562)
    }
    self := self
    screen_ := screen_
    args := []__bindgen_gde.TypePtr {
        &screen_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_screen_set_keep_on :: proc "contextless" (
    self: Display_Server,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_set_keep_on", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_screen_is_kept_on :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("screen_is_kept_on", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_get_window_list :: proc "contextless" (
    self: Display_Server,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_window_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1930428628)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_get_window_at_screen_position :: proc "contextless" (
    self: Display_Server,
    position_: Vector2i,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_window_at_screen_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2485466453)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_get_native_handle :: proc "contextless" (
    self: Display_Server,
    handle_type_: Display_Server_Handle_Type,
    window_id_: Int,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_native_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1096425680)
    }
    self := self
    handle_type_ := handle_type_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &handle_type_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_get_active_popup :: proc "contextless" (
    self: Display_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_active_popup", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_set_popup_safe_rect :: proc "contextless" (
    self: Display_Server,
    window_: Int,
    rect_: Rect2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_popup_safe_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3317281434)
    }
    self := self
    window_ := window_
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &window_,
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_get_popup_safe_rect :: proc "contextless" (
    self: Display_Server,
    window_: Int,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_popup_safe_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2161169500)
    }
    self := self
    window_ := window_
    args := []__bindgen_gde.TypePtr {
        &window_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_set_title :: proc "contextless" (
    self: Display_Server,
    title_: String,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_title", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 441246282)
    }
    self := self
    title_ := title_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &title_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_get_title_size :: proc "contextless" (
    self: Display_Server,
    title_: String,
    window_id_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_title_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2925301799)
    }
    self := self
    title_ := title_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &title_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_set_mouse_passthrough :: proc "contextless" (
    self: Display_Server,
    region_: Packed_Vector2_Array,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_mouse_passthrough", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1993637420)
    }
    self := self
    region_ := region_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &region_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_get_current_screen :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_current_screen", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_set_current_screen :: proc "contextless" (
    self: Display_Server,
    screen_: Int,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_current_screen", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2230941749)
    }
    self := self
    screen_ := screen_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &screen_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_get_position :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 763922886)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_get_position_with_decorations :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_position_with_decorations", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 763922886)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_set_position :: proc "contextless" (
    self: Display_Server,
    position_: Vector2i,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2019273902)
    }
    self := self
    position_ := position_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_get_size :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 763922886)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_set_size :: proc "contextless" (
    self: Display_Server,
    size_: Vector2i,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2019273902)
    }
    self := self
    size_ := size_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &size_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_rect_changed_callback :: proc "contextless" (
    self: Display_Server,
    callback_: Callable,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_rect_changed_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1091192925)
    }
    self := self
    callback_ := callback_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &callback_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_window_event_callback :: proc "contextless" (
    self: Display_Server,
    callback_: Callable,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_window_event_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1091192925)
    }
    self := self
    callback_ := callback_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &callback_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_input_event_callback :: proc "contextless" (
    self: Display_Server,
    callback_: Callable,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_input_event_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1091192925)
    }
    self := self
    callback_ := callback_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &callback_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_input_text_callback :: proc "contextless" (
    self: Display_Server,
    callback_: Callable,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_input_text_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1091192925)
    }
    self := self
    callback_ := callback_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &callback_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_drop_files_callback :: proc "contextless" (
    self: Display_Server,
    callback_: Callable,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_drop_files_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1091192925)
    }
    self := self
    callback_ := callback_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &callback_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_get_attached_instance_id :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_attached_instance_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_get_max_size :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_max_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 763922886)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_set_max_size :: proc "contextless" (
    self: Display_Server,
    max_size_: Vector2i,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_max_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2019273902)
    }
    self := self
    max_size_ := max_size_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &max_size_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_get_min_size :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_min_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 763922886)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_set_min_size :: proc "contextless" (
    self: Display_Server,
    min_size_: Vector2i,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_min_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2019273902)
    }
    self := self
    min_size_ := min_size_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &min_size_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_get_size_with_decorations :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_size_with_decorations", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 763922886)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_get_mode :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Display_Server_Window_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2185728461)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_set_mode :: proc "contextless" (
    self: Display_Server,
    mode_: Display_Server_Window_Mode,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1319965401)
    }
    self := self
    mode_ := mode_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &mode_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_flag :: proc "contextless" (
    self: Display_Server,
    flag_: Display_Server_Window_Flags,
    enabled_: Bool,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 254894155)
    }
    self := self
    flag_ := flag_
    enabled_ := enabled_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &flag_,
        &enabled_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_get_flag :: proc "contextless" (
    self: Display_Server,
    flag_: Display_Server_Window_Flags,
    window_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 802816991)
    }
    self := self
    flag_ := flag_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &flag_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_set_icon :: proc "contextless" (
    self: Display_Server,
    icon_: Image,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2457502155)
    }
    self := self
    icon_ := icon_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &icon_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_window_buttons_offset :: proc "contextless" (
    self: Display_Server,
    offset_: Vector2i,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_window_buttons_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2019273902)
    }
    self := self
    offset_ := offset_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &offset_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_get_safe_title_margins :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_safe_title_margins", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2295066620)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_request_attention :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_request_attention", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1995695955)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_taskbar_progress_value :: proc "contextless" (
    self: Display_Server,
    value_: f64,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_taskbar_progress_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506631519)
    }
    self := self
    value_ := value_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &value_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_taskbar_progress_state :: proc "contextless" (
    self: Display_Server,
    state_: Display_Server_Progress_State,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_taskbar_progress_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4119882768)
    }
    self := self
    state_ := state_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &state_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_move_to_foreground :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_move_to_foreground", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1995695955)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_is_focused :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_is_focused", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1051549951)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_can_draw :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_can_draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1051549951)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_set_transient :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
    parent_window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_transient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    window_id_ := window_id_
    parent_window_id_ := parent_window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
        &parent_window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_exclusive :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
    exclusive_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_exclusive", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    window_id_ := window_id_
    exclusive_ := exclusive_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
        &exclusive_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_ime_active :: proc "contextless" (
    self: Display_Server,
    active_: Bool,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_ime_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1661950165)
    }
    self := self
    active_ := active_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &active_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_ime_position :: proc "contextless" (
    self: Display_Server,
    position_: Vector2i,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_ime_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2019273902)
    }
    self := self
    position_ := position_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_vsync_mode :: proc "contextless" (
    self: Display_Server,
    vsync_mode_: Display_Server_V_Sync_Mode,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_vsync_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2179333492)
    }
    self := self
    vsync_mode_ := vsync_mode_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &vsync_mode_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_get_vsync_mode :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Display_Server_V_Sync_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_vsync_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 578873795)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_is_hdr_output_supported :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_is_hdr_output_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1051549951)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_request_hdr_output :: proc "contextless" (
    self: Display_Server,
    enable_: Bool,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_request_hdr_output", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1661950165)
    }
    self := self
    enable_ := enable_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &enable_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_is_hdr_output_requested :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_is_hdr_output_requested", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1051549951)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_is_hdr_output_enabled :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_is_hdr_output_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1051549951)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_set_hdr_output_reference_luminance :: proc "contextless" (
    self: Display_Server,
    reference_luminance_: f64,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_hdr_output_reference_luminance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506631519)
    }
    self := self
    reference_luminance_ := reference_luminance_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &reference_luminance_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_get_hdr_output_reference_luminance :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_hdr_output_reference_luminance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 218038398)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_get_hdr_output_current_reference_luminance :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_hdr_output_current_reference_luminance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 218038398)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_set_hdr_output_max_luminance :: proc "contextless" (
    self: Display_Server,
    max_luminance_: f64,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_hdr_output_max_luminance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506631519)
    }
    self := self
    max_luminance_ := max_luminance_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &max_luminance_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_get_hdr_output_max_luminance :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_hdr_output_max_luminance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 218038398)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_get_hdr_output_current_max_luminance :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_hdr_output_current_max_luminance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 218038398)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_get_output_max_linear_value :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_get_output_max_linear_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 218038398)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_is_maximize_allowed :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_is_maximize_allowed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1051549951)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_maximize_on_title_dbl_click :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_maximize_on_title_dbl_click", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_minimize_on_title_dbl_click :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_minimize_on_title_dbl_click", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_window_start_drag :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_start_drag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1995695955)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_start_resize :: proc "contextless" (
    self: Display_Server,
    edge_: Display_Server_Window_Resize_Edge,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_start_resize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4009722312)
    }
    self := self
    edge_ := edge_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &edge_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_window_set_color :: proc "contextless" (
    self: Display_Server,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("window_set_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_should_increase_contrast :: proc "contextless" (
    self: Display_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_should_increase_contrast", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_accessibility_should_reduce_animation :: proc "contextless" (
    self: Display_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_should_reduce_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_accessibility_should_reduce_transparency :: proc "contextless" (
    self: Display_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_should_reduce_transparency", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_accessibility_screen_reader_active :: proc "contextless" (
    self: Display_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_screen_reader_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_accessibility_create_element :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
    role_: Display_Server_Accessibility_Role,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_create_element", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2968347744)
    }
    self := self
    window_id_ := window_id_
    role_ := role_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
        &role_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_accessibility_create_sub_element :: proc "contextless" (
    self: Display_Server,
    parent_rid_: Rid,
    role_: Display_Server_Accessibility_Role,
    insert_pos_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_create_sub_element", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1949948826)
    }
    self := self
    parent_rid_ := parent_rid_
    role_ := role_
    insert_pos_ := insert_pos_
    args := []__bindgen_gde.TypePtr {
        &parent_rid_,
        &role_,
        &insert_pos_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_accessibility_create_sub_text_edit_elements :: proc "contextless" (
    self: Display_Server,
    parent_rid_: Rid,
    shaped_text_: Rid,
    min_height_: f64,
    insert_pos_: Int,
    is_last_line_: Bool,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_create_sub_text_edit_elements", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2702009895)
    }
    self := self
    parent_rid_ := parent_rid_
    shaped_text_ := shaped_text_
    min_height_ := min_height_
    insert_pos_ := insert_pos_
    is_last_line_ := is_last_line_
    args := []__bindgen_gde.TypePtr {
        &parent_rid_,
        &shaped_text_,
        &min_height_,
        &insert_pos_,
        &is_last_line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_accessibility_has_element :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_has_element", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155700596)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_accessibility_free_element :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_free_element", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_element_set_meta :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    meta_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_element_set_meta", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175752987)
    }
    self := self
    id_ := id_
    meta_ := meta_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &meta_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_element_get_meta :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_element_get_meta", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4171304767)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_accessibility_set_window_rect :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
    rect_out_: Rect2,
    rect_in_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_set_window_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2386961724)
    }
    self := self
    window_id_ := window_id_
    rect_out_ := rect_out_
    rect_in_ := rect_in_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
        &rect_out_,
        &rect_in_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_set_window_focused :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
    focused_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_set_window_focused", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    window_id_ := window_id_
    focused_ := focused_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
        &focused_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_focus :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_focus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_get_window_root :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_get_window_root", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 495598643)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_accessibility_update_set_role :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    role_: Display_Server_Accessibility_Role,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_role", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3352768215)
    }
    self := self
    id_ := id_
    role_ := role_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &role_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_name :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726140452)
    }
    self := self
    id_ := id_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_extra_info :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_extra_info", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726140452)
    }
    self := self
    id_ := id_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_description :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_description", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726140452)
    }
    self := self
    id_ := id_
    description_ := description_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &description_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_value :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    value_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726140452)
    }
    self := self
    id_ := id_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_tooltip :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    tooltip_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726140452)
    }
    self := self
    id_ := id_
    tooltip_ := tooltip_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &tooltip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_bounds :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    rect_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_bounds", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1378122625)
    }
    self := self
    id_ := id_
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_transform :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    transform_: Transform2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1246044741)
    }
    self := self
    id_ := id_
    transform_ := transform_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &transform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_add_child :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    child_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_add_child", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    id_ := id_
    child_id_ := child_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &child_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_add_related_controls :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    related_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_add_related_controls", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    id_ := id_
    related_id_ := related_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &related_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_add_related_details :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    related_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_add_related_details", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    id_ := id_
    related_id_ := related_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &related_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_add_related_described_by :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    related_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_add_related_described_by", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    id_ := id_
    related_id_ := related_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &related_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_add_related_flow_to :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    related_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_add_related_flow_to", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    id_ := id_
    related_id_ := related_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &related_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_add_related_labeled_by :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    related_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_add_related_labeled_by", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    id_ := id_
    related_id_ := related_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &related_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_add_related_radio_group :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    related_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_add_related_radio_group", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    id_ := id_
    related_id_ := related_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &related_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_active_descendant :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    other_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_active_descendant", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    id_ := id_
    other_id_ := other_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &other_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_next_on_line :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    other_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_next_on_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    id_ := id_
    other_id_ := other_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &other_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_previous_on_line :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    other_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_previous_on_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    id_ := id_
    other_id_ := other_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &other_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_member_of :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    group_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_member_of", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    id_ := id_
    group_id_ := group_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &group_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_in_page_link_target :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    other_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_in_page_link_target", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    id_ := id_
    other_id_ := other_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &other_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_error_message :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    other_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_error_message", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    id_ := id_
    other_id_ := other_id_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &other_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_live :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    live_: Display_Server_Accessibility_Live_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_live", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2683302212)
    }
    self := self
    id_ := id_
    live_ := live_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &live_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_add_action :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    action_: Display_Server_Accessibility_Action,
    callable_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_add_action", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2898696987)
    }
    self := self
    id_ := id_
    action_ := action_
    callable_ := callable_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &action_,
        &callable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_add_custom_action :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    action_id_: Int,
    action_description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_add_custom_action", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4153150897)
    }
    self := self
    id_ := id_
    action_id_ := action_id_
    action_description_ := action_description_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &action_id_,
        &action_description_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_table_row_count :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_table_row_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    id_ := id_
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_table_column_count :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_table_column_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    id_ := id_
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_table_row_index :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_table_row_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    id_ := id_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_table_column_index :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_table_column_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    id_ := id_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_table_cell_position :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    row_index_: Int,
    column_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_table_cell_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4288446313)
    }
    self := self
    id_ := id_
    row_index_ := row_index_
    column_index_ := column_index_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &row_index_,
        &column_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_table_cell_span :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    row_span_: Int,
    column_span_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_table_cell_span", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4288446313)
    }
    self := self
    id_ := id_
    row_span_ := row_span_
    column_span_ := column_span_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &row_span_,
        &column_span_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_list_item_count :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_list_item_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    id_ := id_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_list_item_index :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_list_item_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    id_ := id_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_list_item_level :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    level_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_list_item_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    id_ := id_
    level_ := level_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &level_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_list_item_selected :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    selected_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_list_item_selected", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    id_ := id_
    selected_ := selected_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &selected_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_list_item_expanded :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    expanded_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_list_item_expanded", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    id_ := id_
    expanded_ := expanded_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &expanded_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_popup_type :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    popup_: Display_Server_Accessibility_Popup_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_popup_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2040885448)
    }
    self := self
    id_ := id_
    popup_ := popup_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &popup_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_checked :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    checekd_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_checked", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    id_ := id_
    checekd_ := checekd_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &checekd_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_num_value :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    position_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_num_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    id_ := id_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_num_range :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    min_: f64,
    max_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_num_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2513314492)
    }
    self := self
    id_ := id_
    min_ := min_
    max_ := max_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &min_,
        &max_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_num_step :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    step_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_num_step", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    id_ := id_
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &step_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_num_jump :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    jump_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_num_jump", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    id_ := id_
    jump_ := jump_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &jump_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_scroll_x :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    position_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_scroll_x", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    id_ := id_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_scroll_x_range :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    min_: f64,
    max_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_scroll_x_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2513314492)
    }
    self := self
    id_ := id_
    min_ := min_
    max_ := max_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &min_,
        &max_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_scroll_y :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    position_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_scroll_y", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    id_ := id_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_scroll_y_range :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    min_: f64,
    max_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_scroll_y_range", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2513314492)
    }
    self := self
    id_ := id_
    min_ := min_
    max_ := max_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &min_,
        &max_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_text_decorations :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    underline_: Bool,
    strikethrough_: Bool,
    overline_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_text_decorations", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1672422386)
    }
    self := self
    id_ := id_
    underline_ := underline_
    strikethrough_ := strikethrough_
    overline_ := overline_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &underline_,
        &strikethrough_,
        &overline_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_text_align :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    align_: Horizontal_Alignment,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_text_align", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3725995085)
    }
    self := self
    id_ := id_
    align_ := align_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &align_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_text_selection :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    text_start_id_: Rid,
    start_char_: Int,
    text_end_id_: Rid,
    end_char_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_text_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3119144029)
    }
    self := self
    id_ := id_
    text_start_id_ := text_start_id_
    start_char_ := start_char_
    text_end_id_ := text_end_id_
    end_char_ := end_char_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &text_start_id_,
        &start_char_,
        &text_end_id_,
        &end_char_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_flag :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    flag_: Display_Server_Accessibility_Flags,
    value_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3758675396)
    }
    self := self
    id_ := id_
    flag_ := flag_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &flag_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_classname :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    classname_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_classname", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726140452)
    }
    self := self
    id_ := id_
    classname_ := classname_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &classname_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_placeholder :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    placeholder_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_placeholder", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726140452)
    }
    self := self
    id_ := id_
    placeholder_ := placeholder_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &placeholder_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_language :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    language_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_language", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726140452)
    }
    self := self
    id_ := id_
    language_ := language_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &language_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_text_orientation :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    vertical_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_text_orientation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    id_ := id_
    vertical_ := vertical_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &vertical_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_list_orientation :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    vertical_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_list_orientation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    id_ := id_
    vertical_ := vertical_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &vertical_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_shortcut :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    shortcut_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_shortcut", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726140452)
    }
    self := self
    id_ := id_
    shortcut_ := shortcut_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &shortcut_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_url :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    url_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_url", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726140452)
    }
    self := self
    id_ := id_
    url_ := url_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &url_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_role_description :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_role_description", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726140452)
    }
    self := self
    id_ := id_
    description_ := description_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &description_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_state_description :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_state_description", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2726140452)
    }
    self := self
    id_ := id_
    description_ := description_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &description_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_color_value :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_color_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2948539648)
    }
    self := self
    id_ := id_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_background_color :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_background_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2948539648)
    }
    self := self
    id_ := id_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_accessibility_update_set_foreground_color :: proc "contextless" (
    self: Display_Server,
    id_: Rid,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("accessibility_update_set_foreground_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2948539648)
    }
    self := self
    id_ := id_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_ime_get_selection :: proc "contextless" (
    self: Display_Server,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ime_get_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_ime_get_text :: proc "contextless" (
    self: Display_Server,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ime_get_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_virtual_keyboard_show :: proc "contextless" (
    self: Display_Server,
    existing_text_: String,
    position_: Rect2,
    type_: Display_Server_Virtual_Keyboard_Type,
    max_length_: Int,
    cursor_start_: Int,
    cursor_end_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("virtual_keyboard_show", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3042891259)
    }
    self := self
    existing_text_ := existing_text_
    position_ := position_
    type_ := type_
    max_length_ := max_length_
    cursor_start_ := cursor_start_
    cursor_end_ := cursor_end_
    args := []__bindgen_gde.TypePtr {
        &existing_text_,
        &position_,
        &type_,
        &max_length_,
        &cursor_start_,
        &cursor_end_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_virtual_keyboard_hide :: proc "contextless" (
    self: Display_Server,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("virtual_keyboard_hide", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_virtual_keyboard_get_height :: proc "contextless" (
    self: Display_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("virtual_keyboard_get_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_has_hardware_keyboard :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_hardware_keyboard", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_set_hardware_keyboard_connection_change_callback :: proc "contextless" (
    self: Display_Server,
    callable_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hardware_keyboard_connection_change_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1611583062)
    }
    self := self
    callable_ := callable_
    args := []__bindgen_gde.TypePtr {
        &callable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_cursor_set_shape :: proc "contextless" (
    self: Display_Server,
    shape_: Display_Server_Cursor_Shape,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cursor_set_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2026291549)
    }
    self := self
    shape_ := shape_
    args := []__bindgen_gde.TypePtr {
        &shape_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_cursor_get_shape :: proc "contextless" (
    self: Display_Server,
) -> (ret: Display_Server_Cursor_Shape) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cursor_get_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1087724927)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_cursor_set_custom_image :: proc "contextless" (
    self: Display_Server,
    cursor_: Resource,
    shape_: Display_Server_Cursor_Shape,
    hotspot_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cursor_set_custom_image", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1816663697)
    }
    self := self
    cursor_ := cursor_
    shape_ := shape_
    hotspot_ := hotspot_
    args := []__bindgen_gde.TypePtr {
        &cursor_,
        &shape_,
        &hotspot_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_get_swap_cancel_ok :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_swap_cancel_ok", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_enable_for_stealing_focus :: proc "contextless" (
    self: Display_Server,
    process_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("enable_for_stealing_focus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    process_id_ := process_id_
    args := []__bindgen_gde.TypePtr {
        &process_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_dialog_show :: proc "contextless" (
    self: Display_Server,
    title_: String,
    description_: String,
    buttons_: Packed_String_Array,
    callback_: Callable,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("dialog_show", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4115553226)
    }
    self := self
    title_ := title_
    description_ := description_
    buttons_ := buttons_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &title_,
        &description_,
        &buttons_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_dialog_input_text :: proc "contextless" (
    self: Display_Server,
    title_: String,
    description_: String,
    existing_text_: String,
    callback_: Callable,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("dialog_input_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3088703427)
    }
    self := self
    title_ := title_
    description_ := description_
    existing_text_ := existing_text_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &title_,
        &description_,
        &existing_text_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_file_dialog_show :: proc "contextless" (
    self: Display_Server,
    title_: String,
    current_directory_: String,
    filename_: String,
    show_hidden_: Bool,
    mode_: Display_Server_File_Dialog_Mode,
    filters_: Packed_String_Array,
    callback_: Callable,
    parent_window_id_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("file_dialog_show", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1386825884)
    }
    self := self
    title_ := title_
    current_directory_ := current_directory_
    filename_ := filename_
    show_hidden_ := show_hidden_
    mode_ := mode_
    filters_ := filters_
    callback_ := callback_
    parent_window_id_ := parent_window_id_
    args := []__bindgen_gde.TypePtr {
        &title_,
        &current_directory_,
        &filename_,
        &show_hidden_,
        &mode_,
        &filters_,
        &callback_,
        &parent_window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_file_dialog_with_options_show :: proc "contextless" (
    self: Display_Server,
    title_: String,
    current_directory_: String,
    root_: String,
    filename_: String,
    show_hidden_: Bool,
    mode_: Display_Server_File_Dialog_Mode,
    filters_: Packed_String_Array,
    options_: Typed_Array(Dictionary),
    callback_: Callable,
    parent_window_id_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("file_dialog_with_options_show", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1448789813)
    }
    self := self
    title_ := title_
    current_directory_ := current_directory_
    root_ := root_
    filename_ := filename_
    show_hidden_ := show_hidden_
    mode_ := mode_
    filters_ := filters_
    options_ := options_
    callback_ := callback_
    parent_window_id_ := parent_window_id_
    args := []__bindgen_gde.TypePtr {
        &title_,
        &current_directory_,
        &root_,
        &filename_,
        &show_hidden_,
        &mode_,
        &filters_,
        &options_,
        &callback_,
        &parent_window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_beep :: proc "contextless" (
    self: Display_Server,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("beep", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051624405)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_keyboard_get_layout_count :: proc "contextless" (
    self: Display_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("keyboard_get_layout_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_keyboard_get_current_layout :: proc "contextless" (
    self: Display_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("keyboard_get_current_layout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_keyboard_set_current_layout :: proc "contextless" (
    self: Display_Server,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("keyboard_set_current_layout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_keyboard_get_layout_language :: proc "contextless" (
    self: Display_Server,
    index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("keyboard_get_layout_language", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_keyboard_get_layout_name :: proc "contextless" (
    self: Display_Server,
    index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("keyboard_get_layout_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_keyboard_get_keycode_from_physical :: proc "contextless" (
    self: Display_Server,
    keycode_: Key,
) -> (ret: Key) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("keyboard_get_keycode_from_physical", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3447613187)
    }
    self := self
    keycode_ := keycode_
    args := []__bindgen_gde.TypePtr {
        &keycode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_keyboard_get_label_from_physical :: proc "contextless" (
    self: Display_Server,
    keycode_: Key,
) -> (ret: Key) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("keyboard_get_label_from_physical", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3447613187)
    }
    self := self
    keycode_ := keycode_
    args := []__bindgen_gde.TypePtr {
        &keycode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_show_emoji_and_symbol_picker :: proc "contextless" (
    self: Display_Server,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("show_emoji_and_symbol_picker", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051624405)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_color_picker :: proc "contextless" (
    self: Display_Server,
    callback_: Callable,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("color_picker", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 151643214)
    }
    self := self
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_process_events :: proc "contextless" (
    self: Display_Server,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("process_events", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_force_process_and_drop_events :: proc "contextless" (
    self: Display_Server,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("force_process_and_drop_events", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_set_native_icon :: proc "contextless" (
    self: Display_Server,
    filename_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_native_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    filename_ := filename_
    args := []__bindgen_gde.TypePtr {
        &filename_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_set_icon :: proc "contextless" (
    self: Display_Server,
    image_: Image,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 532598488)
    }
    self := self
    image_ := image_
    args := []__bindgen_gde.TypePtr {
        &image_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_create_status_indicator :: proc "contextless" (
    self: Display_Server,
    icon_: Texture2d,
    tooltip_: String,
    callback_: Callable,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_status_indicator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1904285171)
    }
    self := self
    icon_ := icon_
    tooltip_ := tooltip_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &icon_,
        &tooltip_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_status_indicator_set_icon :: proc "contextless" (
    self: Display_Server,
    id_: Int,
    icon_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("status_indicator_set_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 666127730)
    }
    self := self
    id_ := id_
    icon_ := icon_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &icon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_status_indicator_set_tooltip :: proc "contextless" (
    self: Display_Server,
    id_: Int,
    tooltip_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("status_indicator_set_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    id_ := id_
    tooltip_ := tooltip_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &tooltip_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_status_indicator_set_menu :: proc "contextless" (
    self: Display_Server,
    id_: Int,
    menu_rid_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("status_indicator_set_menu", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4040184819)
    }
    self := self
    id_ := id_
    menu_rid_ := menu_rid_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &menu_rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_status_indicator_set_callback :: proc "contextless" (
    self: Display_Server,
    id_: Int,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("status_indicator_set_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 957362965)
    }
    self := self
    id_ := id_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_status_indicator_get_rect :: proc "contextless" (
    self: Display_Server,
    id_: Int,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("status_indicator_get_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3327874267)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_delete_status_indicator :: proc "contextless" (
    self: Display_Server,
    id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("delete_status_indicator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_tablet_get_driver_count :: proc "contextless" (
    self: Display_Server,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tablet_get_driver_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_tablet_get_driver_name :: proc "contextless" (
    self: Display_Server,
    idx_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tablet_get_driver_name", true)
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

display_server_tablet_get_current_driver :: proc "contextless" (
    self: Display_Server,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tablet_get_current_driver", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_tablet_set_current_driver :: proc "contextless" (
    self: Display_Server,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tablet_set_current_driver", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_is_window_transparency_available :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_window_transparency_available", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_register_additional_output :: proc "contextless" (
    self: Display_Server,
    object_: Object,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_additional_output", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3975164845)
    }
    self := self
    object_ := object_
    args := []__bindgen_gde.TypePtr {
        &object_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_unregister_additional_output :: proc "contextless" (
    self: Display_Server,
    object_: Object,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unregister_additional_output", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3975164845)
    }
    self := self
    object_ := object_
    args := []__bindgen_gde.TypePtr {
        &object_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_has_additional_outputs :: proc "contextless" (
    self: Display_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_additional_outputs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_is_in_pip_mode :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_in_pip_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1885608816)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

display_server_pip_mode_enter :: proc "contextless" (
    self: Display_Server,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pip_mode_enter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1995695955)
    }
    self := self
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_pip_mode_set_aspect_ratio :: proc "contextless" (
    self: Display_Server,
    numerator_: Int,
    denominator_: Int,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pip_mode_set_aspect_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3471927553)
    }
    self := self
    numerator_ := numerator_
    denominator_ := denominator_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &numerator_,
        &denominator_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

display_server_pip_mode_set_auto_enter_on_background :: proc "contextless" (
    self: Display_Server,
    auto_enter_on_background_: Bool,
    window_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pip_mode_set_auto_enter_on_background", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1661950165)
    }
    self := self
    auto_enter_on_background_ := auto_enter_on_background_
    window_id_ := window_id_
    args := []__bindgen_gde.TypePtr {
        &auto_enter_on_background_,
        &window_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
display_server_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("DisplayServer", true)
}

@(private = "file")
__class_name: String_Name