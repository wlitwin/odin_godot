package godot

import __bindgen_gde "godot:gdext"

Method_Tweener_Constants :: enum {
}



method_tweener_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

method_tweener_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_method_tweener :: proc "contextless" () -> Method_Tweener {
    return cast(Method_Tweener)__bindgen_gde.classdb_construct_object(method_tweener_name_ref())
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

method_tweener_set_delay :: proc "contextless" (
    self: Method_Tweener,
    delay_: f64,
) -> (ret: Method_Tweener) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_delay", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 266477812)
    }
    self := self
    delay_ := delay_
    args := []__bindgen_gde.TypePtr {
        &delay_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

method_tweener_set_trans :: proc "contextless" (
    self: Method_Tweener,
    trans_: Tween_Transition_Type,
) -> (ret: Method_Tweener) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_trans", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3740975367)
    }
    self := self
    trans_ := trans_
    args := []__bindgen_gde.TypePtr {
        &trans_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

method_tweener_set_ease :: proc "contextless" (
    self: Method_Tweener,
    ease_: Tween_Ease_Type,
) -> (ret: Method_Tweener) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_ease", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 315540545)
    }
    self := self
    ease_ := ease_
    args := []__bindgen_gde.TypePtr {
        &ease_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
method_tweener_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("MethodTweener", true)
}

@(private = "file")
__class_name: String_Name