package godot

import __bindgen_gde "godot:gdext"

Accessibility_Server_Constants :: enum {
}
Accessibility_Server_Accessibility_Role :: enum int {
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
Accessibility_Server_Accessibility_Popup_Type :: enum int {
    Popup_Menu = 0,
    Popup_List = 1,
    Popup_Tree = 2,
    Popup_Dialog = 3,
}
Accessibility_Server_Accessibility_Flags :: enum int {
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
Accessibility_Server_Accessibility_Action :: enum int {
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
Accessibility_Server_Accessibility_Live_Mode :: enum int {
    Live_Off = 0,
    Live_Polite = 1,
    Live_Assertive = 2,
}
Accessibility_Server_Accessibility_Scroll_Unit :: enum int {
    Scroll_Unit_Item = 0,
    Scroll_Unit_Page = 1,
}
Accessibility_Server_Accessibility_Scroll_Hint :: enum int {
    Scroll_Hint_Top_Left = 0,
    Scroll_Hint_Bottom_Right = 1,
    Scroll_Hint_Top_Edge = 2,
    Scroll_Hint_Bottom_Edge = 3,
    Scroll_Hint_Left_Edge = 4,
    Scroll_Hint_Right_Edge = 5,
}



accessibility_server_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

accessibility_server_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_accessibility_server :: proc "contextless" () -> Accessibility_Server {
    return cast(Accessibility_Server)__bindgen_gde.classdb_construct_object(accessibility_server_name_ref())
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

accessibility_server_is_supported :: proc "contextless" (
    self: Accessibility_Server,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

accessibility_server_create_element :: proc "contextless" (
    self: Accessibility_Server,
    window_id_: Int,
    role_: Accessibility_Server_Accessibility_Role,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_element", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3846965249)
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

accessibility_server_create_sub_element :: proc "contextless" (
    self: Accessibility_Server,
    parent_rid_: Rid,
    role_: Accessibility_Server_Accessibility_Role,
    insert_pos_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_sub_element", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1151690429)
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

accessibility_server_create_sub_text_edit_elements :: proc "contextless" (
    self: Accessibility_Server,
    parent_rid_: Rid,
    shaped_text_: Rid,
    min_height_: f64,
    insert_pos_: Int,
    is_last_line_: Bool,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_sub_text_edit_elements", true)
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

accessibility_server_has_element :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_element", true)
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

accessibility_server_free_element :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("free_element", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

accessibility_server_element_set_meta :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    meta_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("element_set_meta", true)
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

accessibility_server_element_get_meta :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("element_get_meta", true)
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

accessibility_server_set_window_rect :: proc "contextless" (
    self: Accessibility_Server,
    window_id_: Int,
    rect_out_: Rect2,
    rect_in_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_window_rect", true)
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

accessibility_server_set_window_focused :: proc "contextless" (
    self: Accessibility_Server,
    window_id_: Int,
    focused_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_window_focused", true)
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

accessibility_server_update_set_focus :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_focus", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

accessibility_server_get_window_root :: proc "contextless" (
    self: Accessibility_Server,
    window_id_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_window_root", true)
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

accessibility_server_update_set_role :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    role_: Accessibility_Server_Accessibility_Role,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_role", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3747886520)
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

accessibility_server_update_set_name :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_name", true)
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

accessibility_server_update_set_braille_label :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_braille_label", true)
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

accessibility_server_update_set_braille_role_description :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_braille_role_description", true)
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

accessibility_server_update_set_extra_info :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_extra_info", true)
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

accessibility_server_update_set_description :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_description", true)
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

accessibility_server_update_set_value :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    value_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_value", true)
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

accessibility_server_update_set_tooltip :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    tooltip_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_tooltip", true)
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

accessibility_server_update_set_bounds :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    rect_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_bounds", true)
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

accessibility_server_update_set_transform :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    transform_: Transform2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_transform", true)
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

accessibility_server_update_add_child :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    child_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_add_child", true)
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

accessibility_server_update_add_related_controls :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    related_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_add_related_controls", true)
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

accessibility_server_update_add_related_details :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    related_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_add_related_details", true)
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

accessibility_server_update_add_related_described_by :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    related_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_add_related_described_by", true)
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

accessibility_server_update_add_related_flow_to :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    related_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_add_related_flow_to", true)
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

accessibility_server_update_add_related_labeled_by :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    related_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_add_related_labeled_by", true)
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

accessibility_server_update_add_related_radio_group :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    related_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_add_related_radio_group", true)
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

accessibility_server_update_set_active_descendant :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    other_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_active_descendant", true)
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

accessibility_server_update_set_next_on_line :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    other_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_next_on_line", true)
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

accessibility_server_update_set_previous_on_line :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    other_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_previous_on_line", true)
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

accessibility_server_update_set_member_of :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    group_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_member_of", true)
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

accessibility_server_update_set_in_page_link_target :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    other_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_in_page_link_target", true)
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

accessibility_server_update_set_error_message :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    other_id_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_error_message", true)
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

accessibility_server_update_set_live :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    live_: Accessibility_Server_Accessibility_Live_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_live", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2993365237)
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

accessibility_server_update_add_action :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    action_: Accessibility_Server_Accessibility_Action,
    callable_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_add_action", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3960092835)
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

accessibility_server_update_add_custom_action :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    action_id_: Int,
    action_description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_add_custom_action", true)
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

accessibility_server_update_set_table_row_count :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_table_row_count", true)
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

accessibility_server_update_set_table_column_count :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_table_column_count", true)
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

accessibility_server_update_set_table_row_index :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_table_row_index", true)
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

accessibility_server_update_set_table_column_index :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_table_column_index", true)
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

accessibility_server_update_set_table_cell_position :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    row_index_: Int,
    column_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_table_cell_position", true)
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

accessibility_server_update_set_table_cell_span :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    row_span_: Int,
    column_span_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_table_cell_span", true)
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

accessibility_server_update_set_list_item_count :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_list_item_count", true)
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

accessibility_server_update_set_list_item_index :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_list_item_index", true)
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

accessibility_server_update_set_list_item_level :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    level_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_list_item_level", true)
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

accessibility_server_update_set_list_item_selected :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    selected_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_list_item_selected", true)
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

accessibility_server_update_set_list_item_expanded :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    expanded_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_list_item_expanded", true)
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

accessibility_server_update_set_popup_type :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    popup_: Accessibility_Server_Accessibility_Popup_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_popup_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 690307634)
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

accessibility_server_update_set_checked :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    checekd_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_checked", true)
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

accessibility_server_update_set_num_value :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    position_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_num_value", true)
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

accessibility_server_update_set_num_range :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    min_: f64,
    max_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_num_range", true)
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

accessibility_server_update_set_num_step :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    step_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_num_step", true)
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

accessibility_server_update_set_num_jump :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    jump_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_num_jump", true)
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

accessibility_server_update_set_scroll_x :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    position_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_scroll_x", true)
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

accessibility_server_update_set_scroll_x_range :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    min_: f64,
    max_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_scroll_x_range", true)
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

accessibility_server_update_set_scroll_y :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    position_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_scroll_y", true)
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

accessibility_server_update_set_scroll_y_range :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    min_: f64,
    max_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_scroll_y_range", true)
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

accessibility_server_update_set_text_decorations :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    underline_: Bool,
    strikethrough_: Bool,
    overline_: Bool,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_text_decorations", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 457503484)
    }
    self := self
    id_ := id_
    underline_ := underline_
    strikethrough_ := strikethrough_
    overline_ := overline_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &underline_,
        &strikethrough_,
        &overline_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

accessibility_server_update_set_text_align :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    align_: Horizontal_Alignment,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_text_align", true)
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

accessibility_server_update_set_text_selection :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    text_start_id_: Rid,
    start_char_: Int,
    text_end_id_: Rid,
    end_char_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_text_selection", true)
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

accessibility_server_update_set_flag :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    flag_: Accessibility_Server_Accessibility_Flags,
    value_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1473043386)
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

accessibility_server_update_set_classname :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    classname_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_classname", true)
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

accessibility_server_update_set_placeholder :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    placeholder_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_placeholder", true)
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

accessibility_server_update_set_language :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    language_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_language", true)
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

accessibility_server_update_set_text_orientation :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    vertical_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_text_orientation", true)
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

accessibility_server_update_set_list_orientation :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    vertical_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_list_orientation", true)
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

accessibility_server_update_set_shortcut :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    shortcut_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_shortcut", true)
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

accessibility_server_update_set_url :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    url_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_url", true)
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

accessibility_server_update_set_role_description :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_role_description", true)
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

accessibility_server_update_set_state_description :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    description_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_state_description", true)
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

accessibility_server_update_set_color_value :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_color_value", true)
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

accessibility_server_update_set_background_color :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_background_color", true)
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

accessibility_server_update_set_foreground_color :: proc "contextless" (
    self: Accessibility_Server,
    id_: Rid,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_set_foreground_color", true)
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


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
accessibility_server_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AccessibilityServer", true)
}

@(private = "file")
__class_name: String_Name