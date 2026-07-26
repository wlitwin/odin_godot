package godot

import __bindgen_gde "godot:gdext"

Gltf_Document_Constants :: enum {
}
Gltf_Document_Root_Node_Mode :: enum int {
    Root_Node_Mode_Single_Root = 0,
    Root_Node_Mode_Keep_Root = 1,
    Root_Node_Mode_Multi_Root = 2,
}
Gltf_Document_Texture_Map_Mode :: enum int {
    Texture_Map_Mode_Do_Not_Remap = 0,
    Texture_Map_Mode_Remap_To_Standard_Material = 1,
}
Gltf_Document_Visibility_Mode :: enum int {
    Visibility_Mode_Include_Required = 0,
    Visibility_Mode_Include_Optional = 1,
    Visibility_Mode_Exclude = 2,
}

Gltf_Document_Import_Flags :: enum i64 {
    Import_Flag_Generate_Tangent_Arrays = 8,
    Import_Flag_Use_Named_Skin_Binds = 16,
    Import_Flag_Discard_Meshes_And_Materials = 32,
    Import_Flag_Force_Disable_Mesh_Compression = 64,
}


gltf_document_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

gltf_document_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_gltf_document :: proc "contextless" () -> Gltf_Document {
    return cast(Gltf_Document)__bindgen_gde.classdb_construct_object(gltf_document_name_ref())
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
gltf_document_import_object_model_property :: proc "contextless" (
    state_: Gltf_State,
    json_pointer_: String,
) -> (ret: Gltf_Object_Model_Property) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("import_object_model_property", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1206708632)
    }
    state_ := state_
    json_pointer_ := json_pointer_
    args := []__bindgen_gde.TypePtr {
        &state_,
        &json_pointer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}

gltf_document_export_object_model_property :: proc "contextless" (
    state_: Gltf_State,
    node_path_: Node_Path,
    godot_node_: Node,
    gltf_node_index_: Int,
) -> (ret: Gltf_Object_Model_Property) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("export_object_model_property", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 314209806)
    }
    state_ := state_
    node_path_ := node_path_
    godot_node_ := godot_node_
    gltf_node_index_ := gltf_node_index_
    args := []__bindgen_gde.TypePtr {
        &state_,
        &node_path_,
        &godot_node_,
        &gltf_node_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}

gltf_document_register_gltf_document_extension :: proc "contextless" (
    extension_: Gltf_Document_Extension,
    first_priority_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("register_gltf_document_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3752678331)
    }
    extension_ := extension_
    first_priority_ := first_priority_
    args := []__bindgen_gde.TypePtr {
        &extension_,
        &first_priority_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), nil)
}

gltf_document_unregister_gltf_document_extension :: proc "contextless" (
    extension_: Gltf_Document_Extension,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unregister_gltf_document_extension", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2684415758)
    }
    extension_ := extension_
    args := []__bindgen_gde.TypePtr {
        &extension_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), nil)
}

gltf_document_get_supported_gltf_extensions :: proc "contextless" (
) -> (ret: Packed_String_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_supported_gltf_extensions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2981934095)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}


gltf_document_set_image_format :: proc "contextless" (
    self: Gltf_Document,
    image_format_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_image_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    image_format_ := image_format_
    args := []__bindgen_gde.TypePtr {
        &image_format_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_document_get_image_format :: proc "contextless" (
    self: Gltf_Document,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_image_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_document_set_lossy_quality :: proc "contextless" (
    self: Gltf_Document,
    lossy_quality_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_lossy_quality", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    lossy_quality_ := lossy_quality_
    args := []__bindgen_gde.TypePtr {
        &lossy_quality_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_document_get_lossy_quality :: proc "contextless" (
    self: Gltf_Document,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_lossy_quality", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_document_set_fallback_image_format :: proc "contextless" (
    self: Gltf_Document,
    fallback_image_format_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fallback_image_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    fallback_image_format_ := fallback_image_format_
    args := []__bindgen_gde.TypePtr {
        &fallback_image_format_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_document_get_fallback_image_format :: proc "contextless" (
    self: Gltf_Document,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fallback_image_format", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_document_set_fallback_image_quality :: proc "contextless" (
    self: Gltf_Document,
    fallback_image_quality_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fallback_image_quality", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    fallback_image_quality_ := fallback_image_quality_
    args := []__bindgen_gde.TypePtr {
        &fallback_image_quality_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_document_get_fallback_image_quality :: proc "contextless" (
    self: Gltf_Document,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fallback_image_quality", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_document_set_root_node_mode :: proc "contextless" (
    self: Gltf_Document,
    root_node_mode_: Gltf_Document_Root_Node_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_root_node_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 463633402)
    }
    self := self
    root_node_mode_ := root_node_mode_
    args := []__bindgen_gde.TypePtr {
        &root_node_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_document_get_root_node_mode :: proc "contextless" (
    self: Gltf_Document,
) -> (ret: Gltf_Document_Root_Node_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_root_node_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 948057992)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_document_set_texture_map_mode :: proc "contextless" (
    self: Gltf_Document,
    texture_map_mode_: Gltf_Document_Texture_Map_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_map_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3144426102)
    }
    self := self
    texture_map_mode_ := texture_map_mode_
    args := []__bindgen_gde.TypePtr {
        &texture_map_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_document_get_texture_map_mode :: proc "contextless" (
    self: Gltf_Document,
) -> (ret: Gltf_Document_Texture_Map_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_map_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2113256994)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_document_set_visibility_mode :: proc "contextless" (
    self: Gltf_Document,
    visibility_mode_: Gltf_Document_Visibility_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2803579218)
    }
    self := self
    visibility_mode_ := visibility_mode_
    args := []__bindgen_gde.TypePtr {
        &visibility_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gltf_document_get_visibility_mode :: proc "contextless" (
    self: Gltf_Document,
) -> (ret: Gltf_Document_Visibility_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3885445962)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_document_append_from_file :: proc "contextless" (
    self: Gltf_Document,
    path_: String,
    state_: Gltf_State,
    flags_: Int,
    base_path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_from_file", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866380864)
    }
    self := self
    path_ := path_
    state_ := state_
    flags_ := flags_
    base_path_ := base_path_
    args := []__bindgen_gde.TypePtr {
        &path_,
        &state_,
        &flags_,
        &base_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_document_append_from_buffer :: proc "contextless" (
    self: Gltf_Document,
    bytes_: Packed_Byte_Array,
    base_path_: String,
    state_: Gltf_State,
    flags_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_from_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1616081266)
    }
    self := self
    bytes_ := bytes_
    base_path_ := base_path_
    state_ := state_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &bytes_,
        &base_path_,
        &state_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_document_append_from_scene :: proc "contextless" (
    self: Gltf_Document,
    node_: Node,
    state_: Gltf_State,
    flags_: Int,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("append_from_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1622574258)
    }
    self := self
    node_ := node_
    state_ := state_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &node_,
        &state_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_document_generate_scene :: proc "contextless" (
    self: Gltf_Document,
    state_: Gltf_State,
    bake_fps_: f64,
    trimming_: Bool,
    remove_immutable_tracks_: Bool,
) -> (ret: Node) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generate_scene", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 596118388)
    }
    self := self
    state_ := state_
    bake_fps_ := bake_fps_
    trimming_ := trimming_
    remove_immutable_tracks_ := remove_immutable_tracks_
    args := []__bindgen_gde.TypePtr {
        &state_,
        &bake_fps_,
        &trimming_,
        &remove_immutable_tracks_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_document_generate_buffer :: proc "contextless" (
    self: Gltf_Document,
    state_: Gltf_State,
) -> (ret: Packed_Byte_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generate_buffer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 741783455)
    }
    self := self
    state_ := state_
    args := []__bindgen_gde.TypePtr {
        &state_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gltf_document_write_to_filesystem :: proc "contextless" (
    self: Gltf_Document,
    state_: Gltf_State,
    path_: String,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("write_to_filesystem", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1784551478)
    }
    self := self
    state_ := state_
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &state_,
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
gltf_document_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GLTFDocument", true)
}

@(private = "file")
__class_name: String_Name