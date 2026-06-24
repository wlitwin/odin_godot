package godot

import __bindgen_gde "godot:gdext"

Property_Tweener_Constants :: enum {
}



property_tweener_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

property_tweener_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_property_tweener :: proc "contextless" () -> Property_Tweener {
    return cast(Property_Tweener)__bindgen_gde.classdb_construct_object(property_tweener_name_ref())
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

property_tweener_from :: proc "contextless" (
    self: Property_Tweener,
    value_: Variant,
) -> (ret: Property_Tweener) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4190193059)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

property_tweener_from_current :: proc "contextless" (
    self: Property_Tweener,
) -> (ret: Property_Tweener) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("from_current", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4279177709)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

property_tweener_as_relative :: proc "contextless" (
    self: Property_Tweener,
) -> (ret: Property_Tweener) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("as_relative", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4279177709)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

property_tweener_set_trans :: proc "contextless" (
    self: Property_Tweener,
    trans_: Tween_Transition_Type,
) -> (ret: Property_Tweener) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_trans", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1899107404)
    }
    self := self
    trans_ := trans_
    args := []__bindgen_gde.TypePtr {
        &trans_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

property_tweener_set_ease :: proc "contextless" (
    self: Property_Tweener,
    ease_: Tween_Ease_Type,
) -> (ret: Property_Tweener) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_ease", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1080455622)
    }
    self := self
    ease_ := ease_
    args := []__bindgen_gde.TypePtr {
        &ease_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

property_tweener_set_custom_interpolator :: proc "contextless" (
    self: Property_Tweener,
    interpolator_method_: Callable,
) -> (ret: Property_Tweener) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_interpolator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3174170268)
    }
    self := self
    interpolator_method_ := interpolator_method_
    args := []__bindgen_gde.TypePtr {
        &interpolator_method_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

property_tweener_set_delay :: proc "contextless" (
    self: Property_Tweener,
    delay_: f64,
) -> (ret: Property_Tweener) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_delay", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2171559331)
    }
    self := self
    delay_ := delay_
    args := []__bindgen_gde.TypePtr {
        &delay_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
property_tweener_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PropertyTweener", true)
}

@(private = "file")
__class_name: String_Name