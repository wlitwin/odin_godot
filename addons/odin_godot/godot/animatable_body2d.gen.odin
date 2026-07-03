package godot

import __bindgen_gde "godot:gdext"

Animatable_Body2d_Constants :: enum {
}



animatable_body2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

animatable_body2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_animatable_body2d :: proc "contextless" () -> Animatable_Body2d {
    return __bindgen_gde.classdb_construct_object(animatable_body2d_name_ref())
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

animatable_body2d_set_sync_to_physics :: proc "contextless" (
    self: Animatable_Body2d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sync_to_physics", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

animatable_body2d_is_sync_to_physics_enabled :: proc "contextless" (
    self: Animatable_Body2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_sync_to_physics_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
animatable_body2d_get_sync_to_physics :: proc "contextless" (self: Animatable_Body2d) -> Bool {
    return animatable_body2d_is_sync_to_physics_enabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
animatable_body2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AnimatableBody2D", true)
}

@(private = "file")
__class_name: String_Name