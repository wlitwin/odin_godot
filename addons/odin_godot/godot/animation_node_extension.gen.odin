package godot

import __bindgen_gde "godot:gdext"

Animation_Node_Extension_Constants :: enum {
}



animation_node_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

animation_node_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_animation_node_extension :: proc "contextless" () -> Animation_Node_Extension {
    return cast(Animation_Node_Extension)__bindgen_gde.classdb_construct_object(animation_node_extension_name_ref())
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
animation_node_extension_is_looping :: proc "contextless" (
    node_info_: Packed_Float32_Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_looping", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2035584311)
    }
    node_info_ := node_info_
    args := []__bindgen_gde.TypePtr {
        &node_info_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}

animation_node_extension_get_remaining_time :: proc "contextless" (
    node_info_: Packed_Float32_Array,
    break_loop_: Bool,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_remaining_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2851904656)
    }
    node_info_ := node_info_
    break_loop_ := break_loop_
    args := []__bindgen_gde.TypePtr {
        &node_info_,
        &break_loop_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, nil, raw_data(args), &ret)
    return
}


animation_node_extension__process_animation_node :: proc "contextless" (
    self: Animation_Node_Extension,
    playback_info_: Packed_Float64_Array,
    test_only_: Bool,
) -> (ret: Packed_Float32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_process_animation_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 912931771)
    }
    self := self
    playback_info_ := playback_info_
    test_only_ := test_only_
    args := []__bindgen_gde.TypePtr {
        &playback_info_,
        &test_only_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
animation_node_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AnimationNodeExtension", true)
}

@(private = "file")
__class_name: String_Name