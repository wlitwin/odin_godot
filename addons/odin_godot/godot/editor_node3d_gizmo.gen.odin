package godot

import __bindgen_gde "godot:gdext"

Editor_Node3d_Gizmo_Constants :: enum {
}



editor_node3d_gizmo_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

editor_node3d_gizmo_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_editor_node3d_gizmo :: proc "contextless" () -> Editor_Node3d_Gizmo {
    return cast(Editor_Node3d_Gizmo)__bindgen_gde.classdb_construct_object(editor_node3d_gizmo_name_ref())
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

editor_node3d_gizmo__redraw :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_redraw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo__get_handle_name :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    id_: Int,
    secondary_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_handle_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1868713439)
    }
    self := self
    id_ := id_
    secondary_ := secondary_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &secondary_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo__is_handle_highlighted :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    id_: Int,
    secondary_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_handle_highlighted", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 361316320)
    }
    self := self
    id_ := id_
    secondary_ := secondary_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &secondary_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo__get_handle_value :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    id_: Int,
    secondary_: Bool,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_handle_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2144196525)
    }
    self := self
    id_ := id_
    secondary_ := secondary_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &secondary_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo__begin_handle_action :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    id_: Int,
    secondary_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_begin_handle_action", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    id_ := id_
    secondary_ := secondary_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &secondary_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo__set_handle :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    id_: Int,
    secondary_: Bool,
    camera_: Camera3d,
    point_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2210262157)
    }
    self := self
    id_ := id_
    secondary_ := secondary_
    camera_ := camera_
    point_ := point_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &secondary_,
        &camera_,
        &point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo__commit_handle :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    id_: Int,
    secondary_: Bool,
    restore_: Variant,
    cancel_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_commit_handle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3655739840)
    }
    self := self
    id_ := id_
    secondary_ := secondary_
    restore_ := restore_
    cancel_ := cancel_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &secondary_,
        &restore_,
        &cancel_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo__subgizmos_intersect_ray :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    camera_: Camera3d,
    point_: Vector2,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_subgizmos_intersect_ray", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2055005479)
    }
    self := self
    camera_ := camera_
    point_ := point_
    args := []__bindgen_gde.TypePtr {
        &camera_,
        &point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo__subgizmos_intersect_frustum :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    camera_: Camera3d,
    frustum_: Typed_Array(Plane),
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_subgizmos_intersect_frustum", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1653813165)
    }
    self := self
    camera_ := camera_
    frustum_ := frustum_
    args := []__bindgen_gde.TypePtr {
        &camera_,
        &frustum_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo__set_subgizmo_transform :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    id_: Int,
    transform_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_set_subgizmo_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3616898986)
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

editor_node3d_gizmo__get_subgizmo_transform :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    id_: Int,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_subgizmo_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1965739696)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo__commit_subgizmos :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    ids_: Packed_Int32_Array,
    restores_: Typed_Array(Transform3d),
    cancel_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_commit_subgizmos", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411059856)
    }
    self := self
    ids_ := ids_
    restores_ := restores_
    cancel_ := cancel_
    args := []__bindgen_gde.TypePtr {
        &ids_,
        &restores_,
        &cancel_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_add_lines :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    lines_: Packed_Vector3_Array,
    material_: Material,
    billboard_: Bool,
    modulate_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_lines", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2910971437)
    }
    self := self
    lines_ := lines_
    material_ := material_
    billboard_ := billboard_
    modulate_ := modulate_
    args := []__bindgen_gde.TypePtr {
        &lines_,
        &material_,
        &billboard_,
        &modulate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_add_mesh :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    mesh_: Mesh,
    material_: Material,
    transform_: Transform3d,
    skeleton_: Skin_Reference,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1579955111)
    }
    self := self
    mesh_ := mesh_
    material_ := material_
    transform_ := transform_
    skeleton_ := skeleton_
    args := []__bindgen_gde.TypePtr {
        &mesh_,
        &material_,
        &transform_,
        &skeleton_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_add_collision_segments :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    segments_: Packed_Vector3_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_collision_segments", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 334873810)
    }
    self := self
    segments_ := segments_
    args := []__bindgen_gde.TypePtr {
        &segments_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_add_collision_triangles :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    triangles_: Triangle_Mesh,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_collision_triangles", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 54901064)
    }
    self := self
    triangles_ := triangles_
    args := []__bindgen_gde.TypePtr {
        &triangles_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_add_unscaled_billboard :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    material_: Material,
    default_scale_: f64,
    modulate_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_unscaled_billboard", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 520007164)
    }
    self := self
    material_ := material_
    default_scale_ := default_scale_
    modulate_ := modulate_
    args := []__bindgen_gde.TypePtr {
        &material_,
        &default_scale_,
        &modulate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_add_handles :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    handles_: Packed_Vector3_Array,
    material_: Material,
    ids_: Packed_Int32_Array,
    billboard_: Bool,
    secondary_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_handles", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2254560097)
    }
    self := self
    handles_ := handles_
    material_ := material_
    ids_ := ids_
    billboard_ := billboard_
    secondary_ := secondary_
    args := []__bindgen_gde.TypePtr {
        &handles_,
        &material_,
        &ids_,
        &billboard_,
        &secondary_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_set_node_3d :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    node_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_node_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    node_ := node_
    args := []__bindgen_gde.TypePtr {
        &node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_get_node_3d :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
) -> (ret: Node3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 151077316)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_get_plugin :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
) -> (ret: Editor_Node3d_Gizmo_Plugin) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_plugin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4250544552)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_clear :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_set_hidden :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    hidden_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hidden", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    hidden_ := hidden_
    args := []__bindgen_gde.TypePtr {
        &hidden_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

editor_node3d_gizmo_is_subgizmo_selected :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
    id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_subgizmo_selected", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

editor_node3d_gizmo_get_subgizmo_selection :: proc "contextless" (
    self: Editor_Node3d_Gizmo,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_subgizmo_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1930428628)
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
editor_node3d_gizmo_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("EditorNode3DGizmo", true)
}

@(private = "file")
__class_name: String_Name