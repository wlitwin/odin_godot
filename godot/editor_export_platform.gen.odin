package godot

import __bindgen_gde "godot:gdext"

Editor_Export_Platform_Constants :: enum {
}
Editor_Export_Platform_Export_Message_Type :: enum int {
    Export_Message_None = 0,
    Export_Message_Info = 1,
    Export_Message_Warning = 2,
    Export_Message_Error = 3,
}

Editor_Export_Platform_Debug_Flags :: enum i64 {
    Debug_Flag_Dumb_Client = 1,
    Debug_Flag_Remote_Debug = 2,
    Debug_Flag_Remote_Debug_Localhost = 4,
    Debug_Flag_View_Collisions = 8,
    Debug_Flag_View_Navigation = 16,
}


editor_export_platform_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_export_platform_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_export_platform :: proc "contextless" () -> Editor_Export_Platform {
    return cast(Editor_Export_Platform)__bindgen_gde.classdb_construct_object(editor_export_platform_name_ref())
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
editor_export_platform_get_forced_export_files :: proc "contextless" (
    preset_: Editor_Export_Preset,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_forced_export_files", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1939331020)
    }
    preset_ := preset_
    args := []__bindgen_gde.TypePtr {
        &preset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}


editor_export_platform_get_os_name :: proc "contextless" (
    self: Editor_Export_Platform,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_os_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_create_preset :: proc "contextless" (
    self: Editor_Export_Platform,
) -> (ret: Editor_Export_Preset) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_preset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2572397818)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_find_export_template :: proc "contextless" (
    self: Editor_Export_Platform,
    template_file_name_: String,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_export_template", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2248993622)
    }
    self := self
    template_file_name_ := template_file_name_
    args := []__bindgen_gde.TypePtr {
        &template_file_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_get_current_presets :: proc "contextless" (
    self: Editor_Export_Platform,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_presets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_save_pack :: proc "contextless" (
    self: Editor_Export_Platform,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
    embed_: Bool,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_pack", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3420080977)
    }
    self := self
    preset_ := preset_
    debug_ := debug_
    path_ := path_
    embed_ := embed_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &debug_,
        &path_,
        &embed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_save_zip :: proc "contextless" (
    self: Editor_Export_Platform,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_zip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1485052307)
    }
    self := self
    preset_ := preset_
    debug_ := debug_
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &debug_,
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_save_pack_patch :: proc "contextless" (
    self: Editor_Export_Platform,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_pack_patch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1485052307)
    }
    self := self
    preset_ := preset_
    debug_ := debug_
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &debug_,
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_save_zip_patch :: proc "contextless" (
    self: Editor_Export_Platform,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("save_zip_patch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1485052307)
    }
    self := self
    preset_ := preset_
    debug_ := debug_
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &debug_,
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_gen_export_flags :: proc "contextless" (
    self: Editor_Export_Platform,
    flags_: Editor_Export_Platform_Debug_Flags,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("gen_export_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2976483270)
    }
    self := self
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_export_project_files :: proc "contextless" (
    self: Editor_Export_Platform,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    save_cb_: Callable,
    shared_cb_: Callable,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("export_project_files", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1063735070)
    }
    self := self
    preset_ := preset_
    debug_ := debug_
    save_cb_ := save_cb_
    shared_cb_ := shared_cb_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &debug_,
        &save_cb_,
        &shared_cb_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_export_project :: proc "contextless" (
    self: Editor_Export_Platform,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
    flags_: Editor_Export_Platform_Debug_Flags,
    notify_: Bool,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("export_project", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1201906210)
    }
    self := self
    preset_ := preset_
    debug_ := debug_
    path_ := path_
    flags_ := flags_
    notify_ := notify_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &debug_,
        &path_,
        &flags_,
        &notify_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_export_pack :: proc "contextless" (
    self: Editor_Export_Platform,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
    flags_: Editor_Export_Platform_Debug_Flags,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("export_pack", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3879521245)
    }
    self := self
    preset_ := preset_
    debug_ := debug_
    path_ := path_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &debug_,
        &path_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_export_zip :: proc "contextless" (
    self: Editor_Export_Platform,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
    flags_: Editor_Export_Platform_Debug_Flags,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("export_zip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3879521245)
    }
    self := self
    preset_ := preset_
    debug_ := debug_
    path_ := path_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &debug_,
        &path_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_export_pack_patch :: proc "contextless" (
    self: Editor_Export_Platform,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
    patches_: Packed_String_Array,
    flags_: Editor_Export_Platform_Debug_Flags,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("export_pack_patch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 608021658)
    }
    self := self
    preset_ := preset_
    debug_ := debug_
    path_ := path_
    patches_ := patches_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &debug_,
        &path_,
        &patches_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_export_zip_patch :: proc "contextless" (
    self: Editor_Export_Platform,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
    patches_: Packed_String_Array,
    flags_: Editor_Export_Platform_Debug_Flags,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("export_zip_patch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 608021658)
    }
    self := self
    preset_ := preset_
    debug_ := debug_
    path_ := path_
    patches_ := patches_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &debug_,
        &path_,
        &patches_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_clear_messages :: proc "contextless" (
    self: Editor_Export_Platform,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_messages", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_platform_add_message :: proc "contextless" (
    self: Editor_Export_Platform,
    type_: Editor_Export_Platform_Export_Message_Type,
    category_: String,
    message_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_message", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 782767225)
    }
    self := self
    type_ := type_
    category_ := category_
    message_ := message_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &category_,
        &message_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_platform_get_message_count :: proc "contextless" (
    self: Editor_Export_Platform,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_message_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_get_message_type :: proc "contextless" (
    self: Editor_Export_Platform,
    index_: Int,
) -> (ret: Editor_Export_Platform_Export_Message_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_message_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2667287293)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_get_message_category :: proc "contextless" (
    self: Editor_Export_Platform,
    index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_message_category", true)
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

editor_export_platform_get_message_text :: proc "contextless" (
    self: Editor_Export_Platform,
    index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_message_text", true)
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

editor_export_platform_get_worst_message_type :: proc "contextless" (
    self: Editor_Export_Platform,
) -> (ret: Editor_Export_Platform_Export_Message_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_worst_message_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2580557466)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_ssh_run_on_remote :: proc "contextless" (
    self: Editor_Export_Platform,
    host_: String,
    port_: String,
    ssh_arg_: Packed_String_Array,
    cmd_args_: String,
    output_: Array,
    port_fwd_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ssh_run_on_remote", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3163734797)
    }
    self := self
    host_ := host_
    port_ := port_
    ssh_arg_ := ssh_arg_
    cmd_args_ := cmd_args_
    output_ := output_
    port_fwd_ := port_fwd_
    args := []__bindgen_gde.TypePtr {
        &host_,
        &port_,
        &ssh_arg_,
        &cmd_args_,
        &output_,
        &port_fwd_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_ssh_run_on_remote_no_wait :: proc "contextless" (
    self: Editor_Export_Platform,
    host_: String,
    port_: String,
    ssh_args_: Packed_String_Array,
    cmd_args_: String,
    port_fwd_: Int,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ssh_run_on_remote_no_wait", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3606362233)
    }
    self := self
    host_ := host_
    port_ := port_
    ssh_args_ := ssh_args_
    cmd_args_ := cmd_args_
    port_fwd_ := port_fwd_
    args := []__bindgen_gde.TypePtr {
        &host_,
        &port_,
        &ssh_args_,
        &cmd_args_,
        &port_fwd_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_ssh_push_to_remote :: proc "contextless" (
    self: Editor_Export_Platform,
    host_: String,
    port_: String,
    scp_args_: Packed_String_Array,
    src_file_: String,
    dst_file_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ssh_push_to_remote", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 218756989)
    }
    self := self
    host_ := host_
    port_ := port_
    scp_args_ := scp_args_
    src_file_ := src_file_
    dst_file_ := dst_file_
    args := []__bindgen_gde.TypePtr {
        &host_,
        &port_,
        &scp_args_,
        &src_file_,
        &dst_file_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_get_internal_export_files :: proc "contextless" (
    self: Editor_Export_Platform,
    preset_: Editor_Export_Preset,
    debug_: Bool,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_internal_export_files", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 89550086)
    }
    self := self
    preset_ := preset_
    debug_ := debug_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &debug_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_export_platform_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorExportPlatform", true)
}

@(private = "file")
__class_name: String_Name