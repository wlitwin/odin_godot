package godot

import __bindgen_gde "godot:gdext"

Os_Constants :: enum {
}
Os_Rendering_Driver :: enum int {
    Rendering_Driver_Vulkan = 0,
    Rendering_Driver_Opengl3 = 1,
    Rendering_Driver_D3d12 = 2,
    Rendering_Driver_Metal = 3,
}
Os_System_Dir :: enum int {
    System_Dir_Desktop = 0,
    System_Dir_Dcim = 1,
    System_Dir_Documents = 2,
    System_Dir_Downloads = 3,
    System_Dir_Movies = 4,
    System_Dir_Music = 5,
    System_Dir_Pictures = 6,
    System_Dir_Ringtones = 7,
}
Os_Std_Handle_Type :: enum int {
    Std_Handle_Invalid = 0,
    Std_Handle_Console = 1,
    Std_Handle_File = 2,
    Std_Handle_Pipe = 3,
    Std_Handle_Unknown = 4,
}



os_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

os_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_os :: proc "contextless" () -> Os {
    return cast(Os)__bindgen_gde.classdb_construct_object(os_name_ref())
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

os_get_entropy :: proc "contextless" (
    self: Os,
    size_: Int,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_entropy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 47165747)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_system_ca_certificates :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_system_ca_certificates", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2841200299)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_connected_midi_inputs :: proc "contextless" (
    self: Os,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_connected_midi_inputs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2981934095)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_open_midi_inputs :: proc "contextless" (
    self: Os,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("open_midi_inputs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_close_midi_inputs :: proc "contextless" (
    self: Os,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("close_midi_inputs", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_alert :: proc "contextless" (
    self: Os,
    text_: String,
    title_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("alert", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1783970740)
    }
    self := self
    text_ := text_
    title_ := title_
    args := []__bindgen_gde.TypePtr {
        &text_,
        &title_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_crash :: proc "contextless" (
    self: Os,
    message_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("crash", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    message_ := message_
    args := []__bindgen_gde.TypePtr {
        &message_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_set_low_processor_usage_mode :: proc "contextless" (
    self: Os,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_low_processor_usage_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_is_in_low_processor_usage_mode :: proc "contextless" (
    self: Os,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_in_low_processor_usage_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_set_low_processor_usage_mode_sleep_usec :: proc "contextless" (
    self: Os,
    usec_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_low_processor_usage_mode_sleep_usec", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    usec_ := usec_
    args := []__bindgen_gde.TypePtr {
        &usec_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_get_low_processor_usage_mode_sleep_usec :: proc "contextless" (
    self: Os,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_low_processor_usage_mode_sleep_usec", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_set_delta_smoothing :: proc "contextless" (
    self: Os,
    delta_smoothing_enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_delta_smoothing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    delta_smoothing_enabled_ := delta_smoothing_enabled_
    args := []__bindgen_gde.TypePtr {
        &delta_smoothing_enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_is_delta_smoothing_enabled :: proc "contextless" (
    self: Os,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_delta_smoothing_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_processor_count :: proc "contextless" (
    self: Os,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_processor_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_processor_name :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_processor_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_system_fonts :: proc "contextless" (
    self: Os,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_system_fonts", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_system_font_path :: proc "contextless" (
    self: Os,
    font_name_: String,
    weight_: Int,
    stretch_: Int,
    italic_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_system_font_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 626580860)
    }
    self := self
    font_name_ := font_name_
    weight_ := weight_
    stretch_ := stretch_
    italic_ := italic_
    args := []__bindgen_gde.TypePtr {
        &font_name_,
        &weight_,
        &stretch_,
        &italic_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_system_font_path_for_text :: proc "contextless" (
    self: Os,
    font_name_: String,
    text_: String,
    locale_: String,
    script_: String,
    weight_: Int,
    stretch_: Int,
    italic_: Bool,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_system_font_path_for_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 197317981)
    }
    self := self
    font_name_ := font_name_
    text_ := text_
    locale_ := locale_
    script_ := script_
    weight_ := weight_
    stretch_ := stretch_
    italic_ := italic_
    args := []__bindgen_gde.TypePtr {
        &font_name_,
        &text_,
        &locale_,
        &script_,
        &weight_,
        &stretch_,
        &italic_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_executable_path :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_executable_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_read_string_from_stdin :: proc "contextless" (
    self: Os,
    buffer_size_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("read_string_from_stdin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 723587915)
    }
    self := self
    buffer_size_ := buffer_size_
    args := []__bindgen_gde.TypePtr {
        &buffer_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_read_buffer_from_stdin :: proc "contextless" (
    self: Os,
    buffer_size_: Int,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("read_buffer_from_stdin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3249455752)
    }
    self := self
    buffer_size_ := buffer_size_
    args := []__bindgen_gde.TypePtr {
        &buffer_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_stdin_type :: proc "contextless" (
    self: Os,
) -> (ret: Os_Std_Handle_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stdin_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1704816237)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_stdout_type :: proc "contextless" (
    self: Os,
) -> (ret: Os_Std_Handle_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stdout_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1704816237)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_stderr_type :: proc "contextless" (
    self: Os,
) -> (ret: Os_Std_Handle_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stderr_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1704816237)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_execute :: proc "contextless" (
    self: Os,
    path_: String,
    arguments_: Packed_String_Array,
    output_: Array,
    read_stderr_: Bool,
    open_console_: Bool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("execute", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1488299882)
    }
    self := self
    path_ := path_
    arguments_ := arguments_
    output_ := output_
    read_stderr_ := read_stderr_
    open_console_ := open_console_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &arguments_,
        &output_,
        &read_stderr_,
        &open_console_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_execute_with_pipe :: proc "contextless" (
    self: Os,
    path_: String,
    arguments_: Packed_String_Array,
    blocking_: Bool,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("execute_with_pipe", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2851312030)
    }
    self := self
    path_ := path_
    arguments_ := arguments_
    blocking_ := blocking_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &arguments_,
        &blocking_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_create_process :: proc "contextless" (
    self: Os,
    path_: String,
    arguments_: Packed_String_Array,
    open_console_: Bool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_process", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2903767230)
    }
    self := self
    path_ := path_
    arguments_ := arguments_
    open_console_ := open_console_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &arguments_,
        &open_console_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_create_instance :: proc "contextless" (
    self: Os,
    arguments_: Packed_String_Array,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_instance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1080601263)
    }
    self := self
    arguments_ := arguments_
    args := []__bindgen_gde.TypePtr {
        &arguments_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_open_with_program :: proc "contextless" (
    self: Os,
    program_path_: String,
    paths_: Packed_String_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("open_with_program", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2848259907)
    }
    self := self
    program_path_ := program_path_
    paths_ := paths_
    args := []__bindgen_gde.TypePtr {
        &program_path_,
        &paths_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_kill :: proc "contextless" (
    self: Os,
    pid_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("kill", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844576869)
    }
    self := self
    pid_ := pid_
    args := []__bindgen_gde.TypePtr {
        &pid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_shell_open :: proc "contextless" (
    self: Os,
    uri_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shell_open", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166001499)
    }
    self := self
    uri_ := uri_
    args := []__bindgen_gde.TypePtr {
        &uri_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_shell_show_in_file_manager :: proc "contextless" (
    self: Os,
    file_or_dir_path_: String,
    open_folder_: Bool,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shell_show_in_file_manager", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3565188097)
    }
    self := self
    file_or_dir_path_ := file_or_dir_path_
    open_folder_ := open_folder_
    args := []__bindgen_gde.TypePtr {
        &file_or_dir_path_,
        &open_folder_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_is_process_running :: proc "contextless" (
    self: Os,
    pid_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_process_running", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    pid_ := pid_
    args := []__bindgen_gde.TypePtr {
        &pid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_process_exit_code :: proc "contextless" (
    self: Os,
    pid_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_process_exit_code", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    pid_ := pid_
    args := []__bindgen_gde.TypePtr {
        &pid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_process_id :: proc "contextless" (
    self: Os,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_process_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_has_environment :: proc "contextless" (
    self: Os,
    variable_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_environment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    variable_ := variable_
    args := []__bindgen_gde.TypePtr {
        &variable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_environment :: proc "contextless" (
    self: Os,
    variable_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_environment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3135753539)
    }
    self := self
    variable_ := variable_
    args := []__bindgen_gde.TypePtr {
        &variable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_set_environment :: proc "contextless" (
    self: Os,
    variable_: String,
    value_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_environment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3605043004)
    }
    self := self
    variable_ := variable_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &variable_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_unset_environment :: proc "contextless" (
    self: Os,
    variable_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unset_environment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3089850668)
    }
    self := self
    variable_ := variable_
    args := []__bindgen_gde.TypePtr {
        &variable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_get_name :: proc "contextless" (
    self: Os,
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

os_get_distribution_name :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_distribution_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_version :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_version", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_version_alias :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_version_alias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_cmdline_args :: proc "contextless" (
    self: Os,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cmdline_args", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2981934095)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_cmdline_user_args :: proc "contextless" (
    self: Os,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cmdline_user_args", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2981934095)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_video_adapter_driver_info :: proc "contextless" (
    self: Os,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_video_adapter_driver_info", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_set_restart_on_exit :: proc "contextless" (
    self: Os,
    restart_: Bool,
    arguments_: Packed_String_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_restart_on_exit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3331453935)
    }
    self := self
    restart_ := restart_
    arguments_ := arguments_
    args := []__bindgen_gde.TypePtr {
        &restart_,
        &arguments_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_is_restart_on_exit_set :: proc "contextless" (
    self: Os,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_restart_on_exit_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_restart_on_exit_arguments :: proc "contextless" (
    self: Os,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_restart_on_exit_arguments", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_delay_usec :: proc "contextless" (
    self: Os,
    usec_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("delay_usec", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 998575451)
    }
    self := self
    usec_ := usec_
    args := []__bindgen_gde.TypePtr {
        &usec_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_delay_msec :: proc "contextless" (
    self: Os,
    msec_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("delay_msec", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 998575451)
    }
    self := self
    msec_ := msec_
    args := []__bindgen_gde.TypePtr {
        &msec_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_get_locale :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_locale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_locale_language :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_locale_language", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_model_name :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_model_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_is_userfs_persistent :: proc "contextless" (
    self: Os,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_userfs_persistent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_is_stdout_verbose :: proc "contextless" (
    self: Os,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_stdout_verbose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_is_debug_build :: proc "contextless" (
    self: Os,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_debug_build", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_static_memory_usage :: proc "contextless" (
    self: Os,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_static_memory_usage", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_static_memory_peak_usage :: proc "contextless" (
    self: Os,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_static_memory_peak_usage", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_memory_info :: proc "contextless" (
    self: Os,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_memory_info", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_move_to_trash :: proc "contextless" (
    self: Os,
    path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_to_trash", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2113323047)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_user_data_dir :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_user_data_dir", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_system_dir :: proc "contextless" (
    self: Os,
    dir_: Os_System_Dir,
    shared_storage_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_system_dir", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3073895123)
    }
    self := self
    dir_ := dir_
    shared_storage_ := shared_storage_
    args := []__bindgen_gde.TypePtr {
        &dir_,
        &shared_storage_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_config_dir :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_config_dir", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_data_dir :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_data_dir", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_cache_dir :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cache_dir", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_temp_dir :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_temp_dir", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_unique_id :: proc "contextless" (
    self: Os,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_unique_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_keycode_string :: proc "contextless" (
    self: Os,
    code_: Key,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_keycode_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2261993717)
    }
    self := self
    code_ := code_
    args := []__bindgen_gde.TypePtr {
        &code_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_is_keycode_unicode :: proc "contextless" (
    self: Os,
    code_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_keycode_unicode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    code_ := code_
    args := []__bindgen_gde.TypePtr {
        &code_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_find_keycode_from_string :: proc "contextless" (
    self: Os,
    string_: String,
) -> (ret: Key) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_keycode_from_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1084858572)
    }
    self := self
    string_ := string_
    args := []__bindgen_gde.TypePtr {
        &string_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_set_use_file_access_save_and_swap :: proc "contextless" (
    self: Os,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_file_access_save_and_swap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_set_thread_name :: proc "contextless" (
    self: Os,
    name_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_thread_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 166001499)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_thread_caller_id :: proc "contextless" (
    self: Os,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_thread_caller_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_main_thread_id :: proc "contextless" (
    self: Os,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_main_thread_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_has_feature :: proc "contextless" (
    self: Os,
    tag_name_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_feature", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    tag_name_ := tag_name_
    args := []__bindgen_gde.TypePtr {
        &tag_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_is_sandboxed :: proc "contextless" (
    self: Os,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_sandboxed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_request_permission :: proc "contextless" (
    self: Os,
    name_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("request_permission", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2323990056)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_request_permissions :: proc "contextless" (
    self: Os,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("request_permissions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_get_granted_permissions :: proc "contextless" (
    self: Os,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_granted_permissions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

os_revoke_granted_permissions :: proc "contextless" (
    self: Os,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("revoke_granted_permissions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_add_logger :: proc "contextless" (
    self: Os,
    logger_: Logger,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_logger", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4261188958)
    }
    self := self
    logger_ := logger_
    args := []__bindgen_gde.TypePtr {
        &logger_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

os_remove_logger :: proc "contextless" (
    self: Os,
    logger_: Logger,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_logger", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4261188958)
    }
    self := self
    logger_ := logger_
    args := []__bindgen_gde.TypePtr {
        &logger_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
os_get_low_processor_usage_mode :: proc "contextless" (self: Os) -> Bool {
    return os_is_in_low_processor_usage_mode(self)
}
os_get_delta_smoothing :: proc "contextless" (self: Os) -> Bool {
    return os_is_delta_smoothing_enabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
os_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OS", true)
}

@(private = "file")
__class_name: String_Name