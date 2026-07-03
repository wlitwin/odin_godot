package godot

import __bindgen_gde "godot:gdext"

Editor_Scene_Post_Import_Plugin_Constants :: enum {
}
Editor_Scene_Post_Import_Plugin_Internal_Import_Category :: enum int {
    Internal_Import_Category_Node = 0,
    Internal_Import_Category_Mesh_3d_Node = 1,
    Internal_Import_Category_Mesh = 2,
    Internal_Import_Category_Material = 3,
    Internal_Import_Category_Animation = 4,
    Internal_Import_Category_Animation_Node = 5,
    Internal_Import_Category_Skeleton_3d_Node = 6,
    Internal_Import_Category_Max = 7,
}



editor_scene_post_import_plugin_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_scene_post_import_plugin_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_scene_post_import_plugin :: proc "contextless" () -> Editor_Scene_Post_Import_Plugin {
    return cast(Editor_Scene_Post_Import_Plugin)__bindgen_gde.classdb_construct_object(editor_scene_post_import_plugin_name_ref())
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

editor_scene_post_import_plugin__get_internal_import_options :: proc "contextless" (
    self: Editor_Scene_Post_Import_Plugin,
    category_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_internal_import_options", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    category_ := category_
    args := []__bindgen_gde.TypePtr {
        &category_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_scene_post_import_plugin__get_internal_option_visibility :: proc "contextless" (
    self: Editor_Scene_Post_Import_Plugin,
    category_: Int,
    for_animation_: Bool,
    option_: String,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_internal_option_visibility", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3811255416)
    }
    self := self
    category_ := category_
    for_animation_ := for_animation_
    option_ := option_
    args := []__bindgen_gde.TypePtr {
        &category_,
        &for_animation_,
        &option_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_scene_post_import_plugin__get_internal_option_update_view_required :: proc "contextless" (
    self: Editor_Scene_Post_Import_Plugin,
    category_: Int,
    option_: String,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_internal_option_update_view_required", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3957349696)
    }
    self := self
    category_ := category_
    option_ := option_
    args := []__bindgen_gde.TypePtr {
        &category_,
        &option_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_scene_post_import_plugin__internal_process :: proc "contextless" (
    self: Editor_Scene_Post_Import_Plugin,
    category_: Int,
    base_node_: Node,
    node_: Node,
    resource_: Resource,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_internal_process", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3641982463)
    }
    self := self
    category_ := category_
    base_node_ := base_node_
    node_ := node_
    resource_ := resource_
    args := []__bindgen_gde.TypePtr {
        &category_,
        &base_node_,
        &node_,
        &resource_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_scene_post_import_plugin__get_import_options :: proc "contextless" (
    self: Editor_Scene_Post_Import_Plugin,
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

editor_scene_post_import_plugin__get_option_visibility :: proc "contextless" (
    self: Editor_Scene_Post_Import_Plugin,
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

editor_scene_post_import_plugin__pre_process :: proc "contextless" (
    self: Editor_Scene_Post_Import_Plugin,
    scene_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_pre_process", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    scene_ := scene_
    args := []__bindgen_gde.TypePtr {
        &scene_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_scene_post_import_plugin__post_process :: proc "contextless" (
    self: Editor_Scene_Post_Import_Plugin,
    scene_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_post_process", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    scene_ := scene_
    args := []__bindgen_gde.TypePtr {
        &scene_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_scene_post_import_plugin_get_option_value :: proc "contextless" (
    self: Editor_Scene_Post_Import_Plugin,
    name_: String_Name,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_option_value", true)
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

editor_scene_post_import_plugin_add_import_option :: proc "contextless" (
    self: Editor_Scene_Post_Import_Plugin,
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

editor_scene_post_import_plugin_add_import_option_advanced :: proc "contextless" (
    self: Editor_Scene_Post_Import_Plugin,
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
editor_scene_post_import_plugin_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorScenePostImportPlugin", true)
}

@(private = "file")
__class_name: String_Name