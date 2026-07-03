package godot

import __bindgen_gde "godot:gdext"

Editor_Export_Platform_Extension_Constants :: enum {
}



editor_export_platform_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_export_platform_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_export_platform_extension :: proc "contextless" () -> Editor_Export_Platform_Extension {
    return cast(Editor_Export_Platform_Extension)__bindgen_gde.classdb_construct_object(editor_export_platform_extension_name_ref())
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

editor_export_platform_extension__get_preset_features :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    preset_: Editor_Export_Preset,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_preset_features", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1387456631)
    }
    self := self
    preset_ := preset_
    args := []__bindgen_gde.TypePtr {
        &preset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__is_executable :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    path_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_executable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_export_options :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_export_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__should_update_export_options :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_should_update_export_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_export_option_visibility :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    preset_: Editor_Export_Preset,
    option_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_export_option_visibility", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 969350244)
    }
    self := self
    preset_ := preset_
    option_ := option_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &option_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_export_option_warning :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    preset_: Editor_Export_Preset,
    option_: String_Name,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_export_option_warning", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 805886795)
    }
    self := self
    preset_ := preset_
    option_ := option_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &option_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_os_name :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_os_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_name :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_logo :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_logo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__poll_export :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_poll_export", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_options_count :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_options_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_options_tooltip :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_options_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_option_icon :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    device_: Int,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_option_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3536238170)
    }
    self := self
    device_ := device_
    args := []__bindgen_gde.TypePtr {
        &device_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_option_label :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    device_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_option_label", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    device_ := device_
    args := []__bindgen_gde.TypePtr {
        &device_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_option_tooltip :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    device_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_option_tooltip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    device_ := device_
    args := []__bindgen_gde.TypePtr {
        &device_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_device_architecture :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    device_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_device_architecture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    device_ := device_
    args := []__bindgen_gde.TypePtr {
        &device_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__cleanup :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_cleanup", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_platform_extension__run :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    preset_: Editor_Export_Preset,
    device_: Int,
    debug_flags_: Editor_Export_Platform_Debug_Flags,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_run", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1726914928)
    }
    self := self
    preset_ := preset_
    device_ := device_
    debug_flags_ := debug_flags_
    args := []__bindgen_gde.TypePtr {
        &preset_,
        &device_,
        &debug_flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_run_icon :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_run_icon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__can_export :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    preset_: Editor_Export_Preset,
    debug_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_can_export", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 493961987)
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

editor_export_platform_extension__has_valid_export_configuration :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    preset_: Editor_Export_Preset,
    debug_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_has_valid_export_configuration", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 493961987)
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

editor_export_platform_extension__has_valid_project_configuration :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    preset_: Editor_Export_Preset,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_has_valid_project_configuration", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3117166915)
    }
    self := self
    preset_ := preset_
    args := []__bindgen_gde.TypePtr {
        &preset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_binary_extensions :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    preset_: Editor_Export_Preset,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_binary_extensions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1387456631)
    }
    self := self
    preset_ := preset_
    args := []__bindgen_gde.TypePtr {
        &preset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__export_project :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
    flags_: Editor_Export_Platform_Debug_Flags,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_export_project", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1328957260)
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

editor_export_platform_extension__export_pack :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
    flags_: Editor_Export_Platform_Debug_Flags,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_export_pack", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1328957260)
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

editor_export_platform_extension__export_zip :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
    flags_: Editor_Export_Platform_Debug_Flags,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_export_zip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1328957260)
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

editor_export_platform_extension__export_pack_patch :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
    patches_: Packed_String_Array,
    flags_: Editor_Export_Platform_Debug_Flags,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_export_pack_patch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 454765315)
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

editor_export_platform_extension__export_zip_patch :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    preset_: Editor_Export_Preset,
    debug_: Bool,
    path_: String,
    patches_: Packed_String_Array,
    flags_: Editor_Export_Platform_Debug_Flags,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_export_zip_patch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 454765315)
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

editor_export_platform_extension__get_platform_features :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_platform_features", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__get_debug_protocol :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_debug_protocol", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension__initialize :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_initialize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_platform_extension_set_config_error :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    error_text_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_config_error", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3089850668)
    }
    self := self
    error_text_ := error_text_
    args := []__bindgen_gde.TypePtr {
        &error_text_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_platform_extension_get_config_error :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_config_error", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_platform_extension_set_config_missing_templates :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
    missing_templates_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_config_missing_templates", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1695273946)
    }
    self := self
    missing_templates_ := missing_templates_
    args := []__bindgen_gde.TypePtr {
        &missing_templates_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_platform_extension_get_config_missing_templates :: proc "contextless" (
    self: Editor_Export_Platform_Extension,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_config_missing_templates", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
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
editor_export_platform_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorExportPlatformExtension", true)
}

@(private = "file")
__class_name: String_Name