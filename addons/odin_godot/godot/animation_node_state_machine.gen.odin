package godot

import __bindgen_gde "godot:gdext"

Animation_Node_State_Machine_Constants :: enum {
}
Animation_Node_State_Machine_State_Machine_Type :: enum int {
    State_Machine_Type_Root = 0,
    State_Machine_Type_Nested = 1,
    State_Machine_Type_Grouped = 2,
}



animation_node_state_machine_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

animation_node_state_machine_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_animation_node_state_machine :: proc "contextless" () -> Animation_Node_State_Machine {
    return cast(Animation_Node_State_Machine)__bindgen_gde.classdb_construct_object(animation_node_state_machine_name_ref())
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

animation_node_state_machine_add_node :: proc "contextless" (
    self: Animation_Node_State_Machine,
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

animation_node_state_machine_replace_node :: proc "contextless" (
    self: Animation_Node_State_Machine,
    name_: String_Name,
    node_: Animation_Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("replace_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2559412862)
    }
    self := self
    name_ := name_
    node_ := node_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_state_machine_get_node :: proc "contextless" (
    self: Animation_Node_State_Machine,
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

animation_node_state_machine_remove_node :: proc "contextless" (
    self: Animation_Node_State_Machine,
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

animation_node_state_machine_rename_node :: proc "contextless" (
    self: Animation_Node_State_Machine,
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

animation_node_state_machine_has_node :: proc "contextless" (
    self: Animation_Node_State_Machine,
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

animation_node_state_machine_get_node_name :: proc "contextless" (
    self: Animation_Node_State_Machine,
    node_: Animation_Node,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_node_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 739213945)
    }
    self := self
    node_ := node_
    args := []__bindgen_gde.TypePtr {
        &node_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_state_machine_get_node_list :: proc "contextless" (
    self: Animation_Node_State_Machine,
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

animation_node_state_machine_set_node_position :: proc "contextless" (
    self: Animation_Node_State_Machine,
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

animation_node_state_machine_get_node_position :: proc "contextless" (
    self: Animation_Node_State_Machine,
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

animation_node_state_machine_has_transition :: proc "contextless" (
    self: Animation_Node_State_Machine,
    from_: String_Name,
    to_: String_Name,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_transition", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 471820014)
    }
    self := self
    from_ := from_
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &to_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_state_machine_add_transition :: proc "contextless" (
    self: Animation_Node_State_Machine,
    from_: String_Name,
    to_: String_Name,
    transition_: Animation_Node_State_Machine_Transition,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_transition", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 795486887)
    }
    self := self
    from_ := from_
    to_ := to_
    transition_ := transition_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &to_,
        &transition_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_state_machine_get_transition :: proc "contextless" (
    self: Animation_Node_State_Machine,
    idx_: Int,
) -> (ret: Animation_Node_State_Machine_Transition) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transition", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4192381260)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_state_machine_get_transition_from :: proc "contextless" (
    self: Animation_Node_State_Machine,
    idx_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transition_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 659327637)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_state_machine_get_transition_to :: proc "contextless" (
    self: Animation_Node_State_Machine,
    idx_: Int,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transition_to", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 659327637)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_state_machine_get_transition_count :: proc "contextless" (
    self: Animation_Node_State_Machine,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transition_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_state_machine_remove_transition_by_index :: proc "contextless" (
    self: Animation_Node_State_Machine,
    idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_transition_by_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_state_machine_remove_transition :: proc "contextless" (
    self: Animation_Node_State_Machine,
    from_: String_Name,
    to_: String_Name,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_transition", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740211285)
    }
    self := self
    from_ := from_
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &to_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_state_machine_set_graph_offset :: proc "contextless" (
    self: Animation_Node_State_Machine,
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

animation_node_state_machine_get_graph_offset :: proc "contextless" (
    self: Animation_Node_State_Machine,
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

animation_node_state_machine_set_state_machine_type :: proc "contextless" (
    self: Animation_Node_State_Machine,
    state_machine_type_: Animation_Node_State_Machine_State_Machine_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_state_machine_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2584759088)
    }
    self := self
    state_machine_type_ := state_machine_type_
    args := []__bindgen_gde.TypePtr {
        &state_machine_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_state_machine_get_state_machine_type :: proc "contextless" (
    self: Animation_Node_State_Machine,
) -> (ret: Animation_Node_State_Machine_State_Machine_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_state_machine_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1140726469)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_state_machine_set_allow_transition_to_self :: proc "contextless" (
    self: Animation_Node_State_Machine,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_allow_transition_to_self", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_state_machine_is_allow_transition_to_self :: proc "contextless" (
    self: Animation_Node_State_Machine,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_allow_transition_to_self", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_state_machine_set_reset_ends :: proc "contextless" (
    self: Animation_Node_State_Machine,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_reset_ends", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_state_machine_are_ends_reset :: proc "contextless" (
    self: Animation_Node_State_Machine,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("are_ends_reset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
animation_node_state_machine_get_allow_transition_to_self :: proc "contextless" (self: Animation_Node_State_Machine) -> Bool {
    return animation_node_state_machine_is_allow_transition_to_self(self)
}
animation_node_state_machine_get_reset_ends :: proc "contextless" (self: Animation_Node_State_Machine) -> Bool {
    return animation_node_state_machine_are_ends_reset(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
animation_node_state_machine_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AnimationNodeStateMachine", true)
}

@(private = "file")
__class_name: String_Name