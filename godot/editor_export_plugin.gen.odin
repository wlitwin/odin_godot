package godot

import __bindgen_gde "godot:gdext"

Editor_Export_Plugin_Constants :: enum {
}



editor_export_plugin_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_export_plugin_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_export_plugin :: proc "contextless" () -> Editor_Export_Plugin {
    return cast(Editor_Export_Plugin)__bindgen_gde.classdb_construct_object(editor_export_plugin_name_ref())
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

editor_export_plugin__export_file :: proc "contextless" (
    self: Editor_Export_Plugin,
    path_: String,
    type_: String,
    features_: Packed_String_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_export_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3533781844)
    }
    self := self
    path_ := path_
    type_ := type_
    features_ := features_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &type_,
        &features_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin__export_begin :: proc "contextless" (
    self: Editor_Export_Plugin,
    features_: Packed_String_Array,
    is_debug_: Bool,
    path_: String,
    flags_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_export_begin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2765511433)
    }
    self := self
    features_ := features_
    is_debug_ := is_debug_
    path_ := path_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &features_,
        &is_debug_,
        &path_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin__export_end :: proc "contextless" (
    self: Editor_Export_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_export_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin__begin_customize_resources :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
    features_: Packed_String_Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_begin_customize_resources", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1312023292)
    }
    self := self
    platform_ := platform_
    features_ := features_
    args := []__bindgen_gde.TypePtr {
        &platform_,
        &features_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__customize_resource :: proc "contextless" (
    self: Editor_Export_Plugin,
    resource_: Resource,
    path_: String,
) -> (ret: Resource) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_customize_resource", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 307917495)
    }
    self := self
    resource_ := resource_
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &resource_,
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__begin_customize_scenes :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
    features_: Packed_String_Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_begin_customize_scenes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1312023292)
    }
    self := self
    platform_ := platform_
    features_ := features_
    args := []__bindgen_gde.TypePtr {
        &platform_,
        &features_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__customize_scene :: proc "contextless" (
    self: Editor_Export_Plugin,
    scene_: Node,
    path_: String,
) -> (ret: Node) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_customize_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 498701822)
    }
    self := self
    scene_ := scene_
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &scene_,
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__get_customization_configuration_hash :: proc "contextless" (
    self: Editor_Export_Plugin,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_customization_configuration_hash", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__end_customize_scenes :: proc "contextless" (
    self: Editor_Export_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_end_customize_scenes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin__end_customize_resources :: proc "contextless" (
    self: Editor_Export_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_end_customize_resources", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin__get_export_options :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_export_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 488349689)
    }
    self := self
    platform_ := platform_
    args := []__bindgen_gde.TypePtr {
        &platform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__get_export_options_overrides :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_export_options_overrides", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2837326714)
    }
    self := self
    platform_ := platform_
    args := []__bindgen_gde.TypePtr {
        &platform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__should_update_export_options :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_should_update_export_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1866233299)
    }
    self := self
    platform_ := platform_
    args := []__bindgen_gde.TypePtr {
        &platform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__get_export_option_visibility :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
    option_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_export_option_visibility", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3537301980)
    }
    self := self
    platform_ := platform_
    option_ := option_
    args := []__bindgen_gde.TypePtr {
        &platform_,
        &option_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__get_export_option_warning :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
    option_: String,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_export_option_warning", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3340251247)
    }
    self := self
    platform_ := platform_
    option_ := option_
    args := []__bindgen_gde.TypePtr {
        &platform_,
        &option_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__get_export_features :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
    debug_: Bool,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_export_features", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1057664154)
    }
    self := self
    platform_ := platform_
    debug_ := debug_
    args := []__bindgen_gde.TypePtr {
        &platform_,
        &debug_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__get_name :: proc "contextless" (
    self: Editor_Export_Plugin,
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

editor_export_plugin__supports_platform :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_supports_platform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1866233299)
    }
    self := self
    platform_ := platform_
    args := []__bindgen_gde.TypePtr {
        &platform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__get_android_dependencies :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
    debug_: Bool,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_android_dependencies", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1057664154)
    }
    self := self
    platform_ := platform_
    debug_ := debug_
    args := []__bindgen_gde.TypePtr {
        &platform_,
        &debug_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__get_android_dependencies_maven_repos :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
    debug_: Bool,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_android_dependencies_maven_repos", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1057664154)
    }
    self := self
    platform_ := platform_
    debug_ := debug_
    args := []__bindgen_gde.TypePtr {
        &platform_,
        &debug_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__get_android_libraries :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
    debug_: Bool,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_android_libraries", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1057664154)
    }
    self := self
    platform_ := platform_
    debug_ := debug_
    args := []__bindgen_gde.TypePtr {
        &platform_,
        &debug_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__get_android_manifest_activity_element_contents :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
    debug_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_android_manifest_activity_element_contents", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4013372917)
    }
    self := self
    platform_ := platform_
    debug_ := debug_
    args := []__bindgen_gde.TypePtr {
        &platform_,
        &debug_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__get_android_manifest_application_element_contents :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
    debug_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_android_manifest_application_element_contents", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4013372917)
    }
    self := self
    platform_ := platform_
    debug_ := debug_
    args := []__bindgen_gde.TypePtr {
        &platform_,
        &debug_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__get_android_manifest_element_contents :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
    debug_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_android_manifest_element_contents", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4013372917)
    }
    self := self
    platform_ := platform_
    debug_ := debug_
    args := []__bindgen_gde.TypePtr {
        &platform_,
        &debug_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin__update_android_prebuilt_manifest :: proc "contextless" (
    self: Editor_Export_Plugin,
    platform_: Editor_Export_Platform,
    manifest_data_: Packed_Byte_Array,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_update_android_prebuilt_manifest", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304965187)
    }
    self := self
    platform_ := platform_
    manifest_data_ := manifest_data_
    args := []__bindgen_gde.TypePtr {
        &platform_,
        &manifest_data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin_add_shared_object :: proc "contextless" (
    self: Editor_Export_Plugin,
    path_: String,
    tags_: Packed_String_Array,
    target_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_shared_object", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3098291045)
    }
    self := self
    path_ := path_
    tags_ := tags_
    target_ := target_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &tags_,
        &target_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_file :: proc "contextless" (
    self: Editor_Export_Plugin,
    path_: String,
    file_: Packed_Byte_Array,
    remap_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 527928637)
    }
    self := self
    path_ := path_
    file_ := file_
    remap_ := remap_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &file_,
        &remap_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_apple_embedded_platform_project_static_lib :: proc "contextless" (
    self: Editor_Export_Plugin,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_apple_embedded_platform_project_static_lib", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_apple_embedded_platform_framework :: proc "contextless" (
    self: Editor_Export_Plugin,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_apple_embedded_platform_framework", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_apple_embedded_platform_embedded_framework :: proc "contextless" (
    self: Editor_Export_Plugin,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_apple_embedded_platform_embedded_framework", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_apple_embedded_platform_plist_content :: proc "contextless" (
    self: Editor_Export_Plugin,
    plist_content_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_apple_embedded_platform_plist_content", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    plist_content_ := plist_content_
    args := []__bindgen_gde.TypePtr {
        &plist_content_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_apple_embedded_platform_linker_flags :: proc "contextless" (
    self: Editor_Export_Plugin,
    flags_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_apple_embedded_platform_linker_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_apple_embedded_platform_bundle_file :: proc "contextless" (
    self: Editor_Export_Plugin,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_apple_embedded_platform_bundle_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_apple_embedded_platform_cpp_code :: proc "contextless" (
    self: Editor_Export_Plugin,
    code_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_apple_embedded_platform_cpp_code", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    code_ := code_
    args := []__bindgen_gde.TypePtr {
        &code_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_ios_project_static_lib :: proc "contextless" (
    self: Editor_Export_Plugin,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_ios_project_static_lib", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_ios_framework :: proc "contextless" (
    self: Editor_Export_Plugin,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_ios_framework", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_ios_embedded_framework :: proc "contextless" (
    self: Editor_Export_Plugin,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_ios_embedded_framework", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_ios_plist_content :: proc "contextless" (
    self: Editor_Export_Plugin,
    plist_content_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_ios_plist_content", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    plist_content_ := plist_content_
    args := []__bindgen_gde.TypePtr {
        &plist_content_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_ios_linker_flags :: proc "contextless" (
    self: Editor_Export_Plugin,
    flags_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_ios_linker_flags", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_ios_bundle_file :: proc "contextless" (
    self: Editor_Export_Plugin,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_ios_bundle_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_ios_cpp_code :: proc "contextless" (
    self: Editor_Export_Plugin,
    code_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_ios_cpp_code", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    code_ := code_
    args := []__bindgen_gde.TypePtr {
        &code_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_add_macos_plugin_file :: proc "contextless" (
    self: Editor_Export_Plugin,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_macos_plugin_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_skip :: proc "contextless" (
    self: Editor_Export_Plugin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("skip", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_export_plugin_get_option :: proc "contextless" (
    self: Editor_Export_Plugin,
    name_: String_Name,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_option", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2760726917)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin_get_export_preset :: proc "contextless" (
    self: Editor_Export_Plugin,
) -> (ret: Editor_Export_Preset) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_export_preset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1610607222)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_export_plugin_get_export_platform :: proc "contextless" (
    self: Editor_Export_Plugin,
) -> (ret: Editor_Export_Platform) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_export_platform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 282254641)
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
editor_export_plugin_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorExportPlugin", true)
}

@(private = "file")
__class_name: String_Name