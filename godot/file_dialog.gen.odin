package godot

import __bindgen_gde "godot:gdext"

File_Dialog_Constants :: enum {
}
File_Dialog_File_Mode :: enum int {
    File_Mode_Open_File = 0,
    File_Mode_Open_Files = 1,
    File_Mode_Open_Dir = 2,
    File_Mode_Open_Any = 3,
    File_Mode_Save_File = 4,
}
File_Dialog_Access :: enum int {
    Access_Resources = 0,
    Access_Userdata = 1,
    Access_Filesystem = 2,
}
File_Dialog_Display_Mode :: enum int {
    Display_Thumbnails = 0,
    Display_List = 1,
}
File_Dialog_Customization :: enum int {
    Customization_Hidden_Files = 0,
    Customization_Create_Folder = 1,
    Customization_File_Filter = 2,
    Customization_File_Sort = 3,
    Customization_Favorites = 4,
    Customization_Recent = 5,
    Customization_Layout = 6,
    Customization_Overwrite_Warning = 7,
    Customization_Delete = 8,
}



file_dialog_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

file_dialog_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_file_dialog :: proc "contextless" () -> File_Dialog {
    return cast(File_Dialog)__bindgen_gde.classdb_construct_object(file_dialog_name_ref())
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
file_dialog_set_favorite_list :: proc "contextless" (
    favorites_: Packed_String_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_favorite_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4015028928)
    }
    favorites_ := favorites_
    args := []__bindgen_gde.TypePtr {
        &favorites_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), nil)
}

file_dialog_get_favorite_list :: proc "contextless" (
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_favorite_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2981934095)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}

file_dialog_set_recent_list :: proc "contextless" (
    recents_: Packed_String_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_recent_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4015028928)
    }
    recents_ := recents_
    args := []__bindgen_gde.TypePtr {
        &recents_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), nil)
}

file_dialog_get_recent_list :: proc "contextless" (
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_recent_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2981934095)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}

file_dialog_set_get_icon_callback :: proc "contextless" (
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_get_icon_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1611583062)
    }
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), nil)
}

file_dialog_set_get_thumbnail_callback :: proc "contextless" (
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_get_thumbnail_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1611583062)
    }
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), nil)
}


file_dialog_clear_filters :: proc "contextless" (
    self: File_Dialog,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_filters", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_add_filter :: proc "contextless" (
    self: File_Dialog,
    filter_: String,
    description_: String,
    mime_type_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 914921954)
    }
    self := self
    filter_ := filter_
    description_ := description_
    mime_type_ := mime_type_
    args := []__bindgen_gde.TypePtr {
        &filter_,
        &description_,
        &mime_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_set_filters :: proc "contextless" (
    self: File_Dialog,
    filters_: Packed_String_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_filters", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4015028928)
    }
    self := self
    filters_ := filters_
    args := []__bindgen_gde.TypePtr {
        &filters_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_get_filters :: proc "contextless" (
    self: File_Dialog,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_filters", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_clear_filename_filter :: proc "contextless" (
    self: File_Dialog,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_filename_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_set_filename_filter :: proc "contextless" (
    self: File_Dialog,
    filter_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_filename_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    filter_ := filter_
    args := []__bindgen_gde.TypePtr {
        &filter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_get_filename_filter :: proc "contextless" (
    self: File_Dialog,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_filename_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_get_option_name :: proc "contextless" (
    self: File_Dialog,
    option_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_option_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    option_ := option_
    args := []__bindgen_gde.TypePtr {
        &option_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_get_option_values :: proc "contextless" (
    self: File_Dialog,
    option_: Int,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_option_values", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 647634434)
    }
    self := self
    option_ := option_
    args := []__bindgen_gde.TypePtr {
        &option_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_get_option_default :: proc "contextless" (
    self: File_Dialog,
    option_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_option_default", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    option_ := option_
    args := []__bindgen_gde.TypePtr {
        &option_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_set_option_name :: proc "contextless" (
    self: File_Dialog,
    option_: Int,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_option_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    option_ := option_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &option_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_set_option_values :: proc "contextless" (
    self: File_Dialog,
    option_: Int,
    values_: Packed_String_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_option_values", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3353661094)
    }
    self := self
    option_ := option_
    values_ := values_
    args := []__bindgen_gde.TypePtr {
        &option_,
        &values_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_set_option_default :: proc "contextless" (
    self: File_Dialog,
    option_: Int,
    default_value_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_option_default", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    option_ := option_
    default_value_index_ := default_value_index_
    args := []__bindgen_gde.TypePtr {
        &option_,
        &default_value_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_set_option_count :: proc "contextless" (
    self: File_Dialog,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_option_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_get_option_count :: proc "contextless" (
    self: File_Dialog,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_option_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_add_option :: proc "contextless" (
    self: File_Dialog,
    name_: String,
    values_: Packed_String_Array,
    default_value_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_option", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 149592325)
    }
    self := self
    name_ := name_
    values_ := values_
    default_value_index_ := default_value_index_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &values_,
        &default_value_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_get_selected_options :: proc "contextless" (
    self: File_Dialog,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_selected_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_get_current_dir :: proc "contextless" (
    self: File_Dialog,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_dir", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_get_current_file :: proc "contextless" (
    self: File_Dialog,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_get_current_path :: proc "contextless" (
    self: File_Dialog,
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

file_dialog_set_current_dir :: proc "contextless" (
    self: File_Dialog,
    dir_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_current_dir", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    dir_ := dir_
    args := []__bindgen_gde.TypePtr {
        &dir_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_set_current_file :: proc "contextless" (
    self: File_Dialog,
    file_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_current_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    file_ := file_
    args := []__bindgen_gde.TypePtr {
        &file_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_set_current_path :: proc "contextless" (
    self: File_Dialog,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_current_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_set_mode_overrides_title :: proc "contextless" (
    self: File_Dialog,
    override_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mode_overrides_title", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    override_ := override_
    args := []__bindgen_gde.TypePtr {
        &override_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_is_mode_overriding_title :: proc "contextless" (
    self: File_Dialog,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_mode_overriding_title", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_set_file_mode :: proc "contextless" (
    self: File_Dialog,
    mode_: File_Dialog_File_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_file_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3654936397)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_get_file_mode :: proc "contextless" (
    self: File_Dialog,
) -> (ret: File_Dialog_File_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_file_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4074825319)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_set_display_mode :: proc "contextless" (
    self: File_Dialog,
    mode_: File_Dialog_Display_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_display_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2692197101)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_get_display_mode :: proc "contextless" (
    self: File_Dialog,
) -> (ret: File_Dialog_Display_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_display_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1092104624)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_get_vbox :: proc "contextless" (
    self: File_Dialog,
) -> (ret: V_Box_Container) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vbox", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 915758477)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_get_line_edit :: proc "contextless" (
    self: File_Dialog,
) -> (ret: Line_Edit) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_line_edit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4071694264)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_set_access :: proc "contextless" (
    self: File_Dialog,
    access_: File_Dialog_Access,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_access", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4104413466)
    }
    self := self
    access_ := access_
    args := []__bindgen_gde.TypePtr {
        &access_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_get_access :: proc "contextless" (
    self: File_Dialog,
) -> (ret: File_Dialog_Access) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_access", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3344081076)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_set_root_subfolder :: proc "contextless" (
    self: File_Dialog,
    dir_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_root_subfolder", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    dir_ := dir_
    args := []__bindgen_gde.TypePtr {
        &dir_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_get_root_subfolder :: proc "contextless" (
    self: File_Dialog,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_root_subfolder", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_set_show_hidden_files :: proc "contextless" (
    self: File_Dialog,
    show_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_show_hidden_files", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    show_ := show_
    args := []__bindgen_gde.TypePtr {
        &show_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_is_showing_hidden_files :: proc "contextless" (
    self: File_Dialog,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_showing_hidden_files", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_set_use_native_dialog :: proc "contextless" (
    self: File_Dialog,
    native_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_native_dialog", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    native_ := native_
    args := []__bindgen_gde.TypePtr {
        &native_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_get_use_native_dialog :: proc "contextless" (
    self: File_Dialog,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_use_native_dialog", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_set_customization_flag_enabled :: proc "contextless" (
    self: File_Dialog,
    flag_: File_Dialog_Customization,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_customization_flag_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3849177100)
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

file_dialog_is_customization_flag_enabled :: proc "contextless" (
    self: File_Dialog,
    flag_: File_Dialog_Customization,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_customization_flag_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3722277863)
    }
    self := self
    flag_ := flag_
    args := []__bindgen_gde.TypePtr {
        &flag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

file_dialog_deselect_all :: proc "contextless" (
    self: File_Dialog,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("deselect_all", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_popup_file_dialog :: proc "contextless" (
    self: File_Dialog,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("popup_file_dialog", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

file_dialog_invalidate :: proc "contextless" (
    self: File_Dialog,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("invalidate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
file_dialog_get_mode_overrides_title :: proc "contextless" (self: File_Dialog) -> Bool {
    return file_dialog_is_mode_overriding_title(self)
}
file_dialog_get_show_hidden_files :: proc "contextless" (self: File_Dialog) -> Bool {
    return file_dialog_is_showing_hidden_files(self)
}
file_dialog_get_hidden_files_toggle_enabled :: proc "contextless" (self: File_Dialog) -> Bool {
    return file_dialog_is_customization_flag_enabled(self, File_Dialog_Customization(0))
}
file_dialog_set_hidden_files_toggle_enabled :: proc "contextless" (self: File_Dialog, value: Bool) {
    file_dialog_set_customization_flag_enabled(self, File_Dialog_Customization(0), value)
}
file_dialog_get_file_filter_toggle_enabled :: proc "contextless" (self: File_Dialog) -> Bool {
    return file_dialog_is_customization_flag_enabled(self, File_Dialog_Customization(2))
}
file_dialog_set_file_filter_toggle_enabled :: proc "contextless" (self: File_Dialog, value: Bool) {
    file_dialog_set_customization_flag_enabled(self, File_Dialog_Customization(2), value)
}
file_dialog_get_file_sort_options_enabled :: proc "contextless" (self: File_Dialog) -> Bool {
    return file_dialog_is_customization_flag_enabled(self, File_Dialog_Customization(3))
}
file_dialog_set_file_sort_options_enabled :: proc "contextless" (self: File_Dialog, value: Bool) {
    file_dialog_set_customization_flag_enabled(self, File_Dialog_Customization(3), value)
}
file_dialog_get_folder_creation_enabled :: proc "contextless" (self: File_Dialog) -> Bool {
    return file_dialog_is_customization_flag_enabled(self, File_Dialog_Customization(1))
}
file_dialog_set_folder_creation_enabled :: proc "contextless" (self: File_Dialog, value: Bool) {
    file_dialog_set_customization_flag_enabled(self, File_Dialog_Customization(1), value)
}
file_dialog_get_favorites_enabled :: proc "contextless" (self: File_Dialog) -> Bool {
    return file_dialog_is_customization_flag_enabled(self, File_Dialog_Customization(4))
}
file_dialog_set_favorites_enabled :: proc "contextless" (self: File_Dialog, value: Bool) {
    file_dialog_set_customization_flag_enabled(self, File_Dialog_Customization(4), value)
}
file_dialog_get_recent_list_enabled :: proc "contextless" (self: File_Dialog) -> Bool {
    return file_dialog_is_customization_flag_enabled(self, File_Dialog_Customization(5))
}
file_dialog_set_recent_list_enabled :: proc "contextless" (self: File_Dialog, value: Bool) {
    file_dialog_set_customization_flag_enabled(self, File_Dialog_Customization(5), value)
}
file_dialog_get_layout_toggle_enabled :: proc "contextless" (self: File_Dialog) -> Bool {
    return file_dialog_is_customization_flag_enabled(self, File_Dialog_Customization(6))
}
file_dialog_set_layout_toggle_enabled :: proc "contextless" (self: File_Dialog, value: Bool) {
    file_dialog_set_customization_flag_enabled(self, File_Dialog_Customization(6), value)
}
file_dialog_get_overwrite_warning_enabled :: proc "contextless" (self: File_Dialog) -> Bool {
    return file_dialog_is_customization_flag_enabled(self, File_Dialog_Customization(7))
}
file_dialog_set_overwrite_warning_enabled :: proc "contextless" (self: File_Dialog, value: Bool) {
    file_dialog_set_customization_flag_enabled(self, File_Dialog_Customization(7), value)
}
file_dialog_get_deleting_enabled :: proc "contextless" (self: File_Dialog) -> Bool {
    return file_dialog_is_customization_flag_enabled(self, File_Dialog_Customization(8))
}
file_dialog_set_deleting_enabled :: proc "contextless" (self: File_Dialog, value: Bool) {
    file_dialog_set_customization_flag_enabled(self, File_Dialog_Customization(8), value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
file_dialog_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("FileDialog", true)
}

@(private = "file")
__class_name: String_Name