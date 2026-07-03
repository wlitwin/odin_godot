package godot

import __bindgen_gde "godot:gdext"

Animation_Node_Transition_Constants :: enum {
}



animation_node_transition_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

animation_node_transition_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_animation_node_transition :: proc "contextless" () -> Animation_Node_Transition {
    return cast(Animation_Node_Transition)__bindgen_gde.classdb_construct_object(animation_node_transition_name_ref())
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

animation_node_transition_set_input_count :: proc "contextless" (
    self: Animation_Node_Transition,
    input_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_input_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    input_count_ := input_count_
    args := []__bindgen_gde.TypePtr {
        &input_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_transition_set_input_as_auto_advance :: proc "contextless" (
    self: Animation_Node_Transition,
    input_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_input_as_auto_advance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    input_ := input_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &input_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_transition_is_input_set_as_auto_advance :: proc "contextless" (
    self: Animation_Node_Transition,
    input_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_input_set_as_auto_advance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    input_ := input_
    args := []__bindgen_gde.TypePtr {
        &input_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_transition_set_input_break_loop_at_end :: proc "contextless" (
    self: Animation_Node_Transition,
    input_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_input_break_loop_at_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    input_ := input_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &input_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_transition_is_input_loop_broken_at_end :: proc "contextless" (
    self: Animation_Node_Transition,
    input_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_input_loop_broken_at_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    input_ := input_
    args := []__bindgen_gde.TypePtr {
        &input_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_transition_set_input_reset :: proc "contextless" (
    self: Animation_Node_Transition,
    input_: Int,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_input_reset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    input_ := input_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &input_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_transition_is_input_reset :: proc "contextless" (
    self: Animation_Node_Transition,
    input_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_input_reset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    input_ := input_
    args := []__bindgen_gde.TypePtr {
        &input_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_transition_set_xfade_time :: proc "contextless" (
    self: Animation_Node_Transition,
    time_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_xfade_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    time_ := time_
    args := []__bindgen_gde.TypePtr {
        &time_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_transition_get_xfade_time :: proc "contextless" (
    self: Animation_Node_Transition,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_xfade_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_transition_set_xfade_curve :: proc "contextless" (
    self: Animation_Node_Transition,
    curve_: Curve,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_xfade_curve", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 270443179)
    }
    self := self
    curve_ := curve_
    args := []__bindgen_gde.TypePtr {
        &curve_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_transition_get_xfade_curve :: proc "contextless" (
    self: Animation_Node_Transition,
) -> (ret: Curve) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_xfade_curve", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2460114913)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

animation_node_transition_set_allow_transition_to_self :: proc "contextless" (
    self: Animation_Node_Transition,
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

animation_node_transition_is_allow_transition_to_self :: proc "contextless" (
    self: Animation_Node_Transition,
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


// properties
animation_node_transition_get_allow_transition_to_self :: proc "contextless" (self: Animation_Node_Transition) -> Bool {
    return animation_node_transition_is_allow_transition_to_self(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
animation_node_transition_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AnimationNodeTransition", true)
}

@(private = "file")
__class_name: String_Name