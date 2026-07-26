package godot

import __bindgen_gde "godot:gdext"

Editor_Node3d_Gizmo_Plugin_Constants :: enum {
}



editor_node3d_gizmo_plugin_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_node3d_gizmo_plugin_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_node3d_gizmo_plugin :: proc "contextless" () -> Editor_Node3d_Gizmo_Plugin {
    return cast(Editor_Node3d_Gizmo_Plugin)__bindgen_gde.classdb_construct_object(editor_node3d_gizmo_plugin_name_ref())
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

editor_node3d_gizmo_plugin__has_gizmo :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    for_node_3d_: Node3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_has_gizmo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1905827158)
    }
    self := self
    for_node_3d_ := for_node_3d_
    args := []__bindgen_gde.TypePtr {
        &for_node_3d_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_plugin__create_gizmo :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    for_node_3d_: Node3d,
) -> (ret: Editor_Node3d_Gizmo) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_create_gizmo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1418965287)
    }
    self := self
    for_node_3d_ := for_node_3d_
    args := []__bindgen_gde.TypePtr {
        &for_node_3d_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_plugin__get_gizmo_name :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_gizmo_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_plugin__get_priority :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_priority", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_plugin__can_be_hidden :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_can_be_hidden", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_plugin__is_selectable_when_hidden :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_selectable_when_hidden", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_plugin__can_commit_handle_on_click :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_can_commit_handle_on_click", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_plugin__redraw :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    gizmo_: Editor_Node3d_Gizmo,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_redraw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 173330131)
    }
    self := self
    gizmo_ := gizmo_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_plugin__get_handle_name :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    gizmo_: Editor_Node3d_Gizmo,
    handle_id_: Int,
    secondary_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_handle_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3888674840)
    }
    self := self
    gizmo_ := gizmo_
    handle_id_ := handle_id_
    secondary_ := secondary_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
        &handle_id_,
        &secondary_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_plugin__is_handle_highlighted :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    gizmo_: Editor_Node3d_Gizmo,
    handle_id_: Int,
    secondary_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_handle_highlighted", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2665780718)
    }
    self := self
    gizmo_ := gizmo_
    handle_id_ := handle_id_
    secondary_ := secondary_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
        &handle_id_,
        &secondary_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_plugin__get_handle_value :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    gizmo_: Editor_Node3d_Gizmo,
    handle_id_: Int,
    secondary_: Bool,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_handle_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2887724832)
    }
    self := self
    gizmo_ := gizmo_
    handle_id_ := handle_id_
    secondary_ := secondary_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
        &handle_id_,
        &secondary_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_plugin__begin_handle_action :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    gizmo_: Editor_Node3d_Gizmo,
    handle_id_: Int,
    secondary_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_begin_handle_action", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3363704593)
    }
    self := self
    gizmo_ := gizmo_
    handle_id_ := handle_id_
    secondary_ := secondary_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
        &handle_id_,
        &secondary_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_plugin__set_handle :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    gizmo_: Editor_Node3d_Gizmo,
    handle_id_: Int,
    secondary_: Bool,
    camera_: Camera3d,
    screen_pos_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1249646868)
    }
    self := self
    gizmo_ := gizmo_
    handle_id_ := handle_id_
    secondary_ := secondary_
    camera_ := camera_
    screen_pos_ := screen_pos_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
        &handle_id_,
        &secondary_,
        &camera_,
        &screen_pos_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_plugin__commit_handle :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    gizmo_: Editor_Node3d_Gizmo,
    handle_id_: Int,
    secondary_: Bool,
    restore_: Variant,
    cancel_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_commit_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1939863962)
    }
    self := self
    gizmo_ := gizmo_
    handle_id_ := handle_id_
    secondary_ := secondary_
    restore_ := restore_
    cancel_ := cancel_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
        &handle_id_,
        &secondary_,
        &restore_,
        &cancel_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_plugin__subgizmos_intersect_ray :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    gizmo_: Editor_Node3d_Gizmo,
    camera_: Camera3d,
    screen_pos_: Vector2,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_subgizmos_intersect_ray", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1781916302)
    }
    self := self
    gizmo_ := gizmo_
    camera_ := camera_
    screen_pos_ := screen_pos_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
        &camera_,
        &screen_pos_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_plugin__subgizmos_intersect_frustum :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    gizmo_: Editor_Node3d_Gizmo,
    camera_: Camera3d,
    frustum_planes_: Typed_Array(Plane),
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_subgizmos_intersect_frustum", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3514748524)
    }
    self := self
    gizmo_ := gizmo_
    camera_ := camera_
    frustum_planes_ := frustum_planes_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
        &camera_,
        &frustum_planes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_plugin__get_subgizmo_transform :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    gizmo_: Editor_Node3d_Gizmo,
    subgizmo_id_: Int,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_subgizmo_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3700343508)
    }
    self := self
    gizmo_ := gizmo_
    subgizmo_id_ := subgizmo_id_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
        &subgizmo_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_plugin__set_subgizmo_transform :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    gizmo_: Editor_Node3d_Gizmo,
    subgizmo_id_: Int,
    transform_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_subgizmo_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2435388792)
    }
    self := self
    gizmo_ := gizmo_
    subgizmo_id_ := subgizmo_id_
    transform_ := transform_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
        &subgizmo_id_,
        &transform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_plugin__commit_subgizmos :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    gizmo_: Editor_Node3d_Gizmo,
    ids_: Packed_Int32_Array,
    restores_: Typed_Array(Transform3d),
    cancel_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_commit_subgizmos", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2282018236)
    }
    self := self
    gizmo_ := gizmo_
    ids_ := ids_
    restores_ := restores_
    cancel_ := cancel_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
        &ids_,
        &restores_,
        &cancel_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_plugin_create_material :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    name_: String,
    color_: Color,
    billboard_: Bool,
    on_top_: Bool,
    use_vertex_color_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3486012546)
    }
    self := self
    name_ := name_
    color_ := color_
    billboard_ := billboard_
    on_top_ := on_top_
    use_vertex_color_ := use_vertex_color_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &color_,
        &billboard_,
        &on_top_,
        &use_vertex_color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_plugin_create_icon_material :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    name_: String,
    texture_: Texture2d,
    on_top_: Bool,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_icon_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3804976916)
    }
    self := self
    name_ := name_
    texture_ := texture_
    on_top_ := on_top_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &texture_,
        &on_top_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_plugin_create_handle_material :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    name_: String,
    billboard_: Bool,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_handle_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2486475223)
    }
    self := self
    name_ := name_
    billboard_ := billboard_
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &billboard_,
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_plugin_add_material :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    name_: String,
    material_: Standard_Material3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1374068695)
    }
    self := self
    name_ := name_
    material_ := material_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_plugin_get_material :: proc "contextless" (
    self: Editor_Node3d_Gizmo_Plugin,
    name_: String,
    gizmo_: Editor_Node3d_Gizmo,
) -> (ret: Standard_Material3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 974464017)
    }
    self := self
    name_ := name_
    gizmo_ := gizmo_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &gizmo_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
editor_node3d_gizmo_plugin_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorNode3DGizmoPlugin", true)
}

@(private = "file")
__class_name: String_Name