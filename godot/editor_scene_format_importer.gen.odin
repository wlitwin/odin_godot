package godot

import __bindgen_gde "godot:gdext"

Editor_Scene_Format_Importer_Constants :: enum {
}

Editor_Scene_Format_Importer_Import_Flags :: enum i64 {
    Import_Scene = 1,
    Import_Animation = 2,
    Import_Fail_On_Missing_Dependencies = 4,
    Import_Generate_Tangent_Arrays = 8,
    Import_Use_Named_Skin_Binds = 16,
    Import_Discard_Meshes_And_Materials = 32,
    Import_Force_Disable_Mesh_Compression = 64,
}


editor_scene_format_importer_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_scene_format_importer_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_scene_format_importer :: proc "contextless" () -> Editor_Scene_Format_Importer {
    return cast(Editor_Scene_Format_Importer)__bindgen_gde.classdb_construct_object(editor_scene_format_importer_name_ref())
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

editor_scene_format_importer__get_extensions :: proc "contextless" (
    self: Editor_Scene_Format_Importer,
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_extensions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1139954409)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_scene_format_importer__import_scene :: proc "contextless" (
    self: Editor_Scene_Format_Importer,
    path_: String,
    flags_: Int,
    options_: Dictionary,
) -> (ret: Object) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_import_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3749238728)
    }
    self := self
    path_ := path_
    flags_ := flags_
    options_ := options_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &flags_,
        &options_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_scene_format_importer__get_import_options :: proc "contextless" (
    self: Editor_Scene_Format_Importer,
    path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_import_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_scene_format_importer__get_option_visibility :: proc "contextless" (
    self: Editor_Scene_Format_Importer,
    path_: String,
    for_animation_: Bool,
    option_: String,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_option_visibility", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 298836892)
    }
    self := self
    path_ := path_
    for_animation_ := for_animation_
    option_ := option_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &for_animation_,
        &option_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_scene_format_importer_add_import_option :: proc "contextless" (
    self: Editor_Scene_Format_Importer,
    name_: String,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_import_option", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 402577236)
    }
    self := self
    name_ := name_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_scene_format_importer_add_import_option_advanced :: proc "contextless" (
    self: Editor_Scene_Format_Importer,
    type_: __bindgen_gde.Variant_Type,
    name_: String,
    default_value_: Variant,
    hint_: Property_Hint,
    hint_string_: String,
    usage_flags_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_import_option_advanced", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3674075649)
    }
    self := self
    type_ := type_
    name_ := name_
    default_value_ := default_value_
    hint_ := hint_
    hint_string_ := hint_string_
    usage_flags_ := usage_flags_
    args := []__bindgen_gde.TypePtr {
        &type_,
        &name_,
        &default_value_,
        &hint_,
        &hint_string_,
        &usage_flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_scene_format_importer_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorSceneFormatImporter", true)
}

@(private = "file")
__class_name: String_Name