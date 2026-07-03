package godot

import __bindgen_gde "godot:gdext"

Animation_Node_Blend_Tree_Constants :: enum {
    CONNECTION_OK = 0,
    CONNECTION_ERROR_NO_INPUT = 1,
    CONNECTION_ERROR_NO_INPUT_INDEX = 2,
    CONNECTION_ERROR_NO_OUTPUT = 3,
    CONNECTION_ERROR_SAME_NODE = 4,
    CONNECTION_ERROR_CONNECTION_EXISTS = 5,
}



animation_node_blend_tree_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

animation_node_blend_tree_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_animation_node_blend_tree :: proc "contextless" () -> Animation_Node_Blend_Tree {
    return cast(Animation_Node_Blend_Tree)__bindgen_gde.classdb_construct_object(animation_node_blend_tree_name_ref())
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

animation_node_blend_tree_add_node :: proc "contextless" (
    self: Animation_Node_Blend_Tree,
    name_: String_Name,
    node_: Animation_Node,
    position_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1980270704)
    }
    self := self
    name_ := name_
    node_ := node_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &node_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_blend_tree_get_node :: proc "contextless" (
    self: Animation_Node_Blend_Tree,
    name_: String_Name,
) -> (ret: Animation_Node) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 625644256)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_blend_tree_remove_node :: proc "contextless" (
    self: Animation_Node_Blend_Tree,
    name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3304788590)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_blend_tree_rename_node :: proc "contextless" (
    self: Animation_Node_Blend_Tree,
    name_: String_Name,
    new_name_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rename_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    name_ := name_
    new_name_ := new_name_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &new_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_blend_tree_has_node :: proc "contextless" (
    self: Animation_Node_Blend_Tree,
    name_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2619796661)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_blend_tree_connect_node :: proc "contextless" (
    self: Animation_Node_Blend_Tree,
    input_node_: String_Name,
    input_index_: Int,
    output_node_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("connect_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2168001410)
    }
    self := self
    input_node_ := input_node_
    input_index_ := input_index_
    output_node_ := output_node_
    args := []__bindgen_gde.TypePtr {
        &input_node_,
        &input_index_,
        &output_node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_blend_tree_disconnect_node :: proc "contextless" (
    self: Animation_Node_Blend_Tree,
    input_node_: String_Name,
    input_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("disconnect_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2415702435)
    }
    self := self
    input_node_ := input_node_
    input_index_ := input_index_
    args := []__bindgen_gde.TypePtr {
        &input_node_,
        &input_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_blend_tree_get_node_list :: proc "contextless" (
    self: Animation_Node_Blend_Tree,
) -> (ret: Typed_Array(String_Name)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_blend_tree_set_node_position :: proc "contextless" (
    self: Animation_Node_Blend_Tree,
    name_: String_Name,
    position_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_node_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1999414630)
    }
    self := self
    name_ := name_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_blend_tree_get_node_position :: proc "contextless" (
    self: Animation_Node_Blend_Tree,
    name_: String_Name,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3100822709)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_blend_tree_set_graph_offset :: proc "contextless" (
    self: Animation_Node_Blend_Tree,
    offset_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_graph_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_blend_tree_get_graph_offset :: proc "contextless" (
    self: Animation_Node_Blend_Tree,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_graph_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
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
animation_node_blend_tree_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AnimationNodeBlendTree", true)
}

@(private = "file")
__class_name: String_Name