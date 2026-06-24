package godot

import __bindgen_gde "godot:gdext"

Expression_Constants :: enum {
}



expression_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

expression_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_expression :: proc "contextless" () -> Expression {
    return cast(Expression)__bindgen_gde.classdb_construct_object(expression_name_ref())
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

expression_parse :: proc "contextless" (
    self: Expression,
    expression_: String,
    input_names_: Packed_String_Array,
) -> (ret: Error) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("parse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3069722906)
    }
    self := self
    expression_ := expression_
    input_names_ := input_names_
    args := []__bindgen_gde.TypePtr {
        &expression_,
        &input_names_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

expression_execute :: proc "contextless" (
    self: Expression,
    inputs_: Array,
    base_instance_: Object,
    show_error_: Bool,
    const_calls_only_: Bool,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("execute", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3712471238)
    }
    self := self
    inputs_ := inputs_
    base_instance_ := base_instance_
    show_error_ := show_error_
    const_calls_only_ := const_calls_only_
    args := []__bindgen_gde.TypePtr {
        &inputs_,
        &base_instance_,
        &show_error_,
        &const_calls_only_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

expression_has_execute_failed :: proc "contextless" (
    self: Expression,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_execute_failed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

expression_get_error_text :: proc "contextless" (
    self: Expression,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_error_text", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
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
expression_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Expression", true)
}

@(private = "file")
__class_name: String_Name