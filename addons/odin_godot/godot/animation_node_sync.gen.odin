package godot

import __bindgen_gde "godot:gdext"

Animation_Node_Sync_Constants :: enum {
}



animation_node_sync_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

animation_node_sync_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_animation_node_sync :: proc "contextless" () -> Animation_Node_Sync {
    return cast(Animation_Node_Sync)__bindgen_gde.classdb_construct_object(animation_node_sync_name_ref())
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

animation_node_sync_set_use_sync :: proc "contextless" (
    self: Animation_Node_Sync,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_sync", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animation_node_sync_is_using_sync :: proc "contextless" (
    self: Animation_Node_Sync,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_sync", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
animation_node_sync_get_sync :: proc "contextless" (self: Animation_Node_Sync) -> Bool {
    return animation_node_sync_is_using_sync(self)
}
animation_node_sync_set_sync :: proc "contextless" (self: Animation_Node_Sync, value: Bool) {
    animation_node_sync_set_use_sync(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
animation_node_sync_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AnimationNodeSync", true)
}

@(private = "file")
__class_name: String_Name