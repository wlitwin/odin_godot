package godot

import __bindgen_gde "godot:gdext"


new_signal :: proc {
    new_signal_default,
    new_signal_signal,
    new_signal_object_string_name,
}

new_signal_default :: proc "contextless" (
) -> (ret: Signal) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Signal, 0)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(&ret, raw_data(args))
    return
}
new_signal_signal :: proc "contextless" (
    from_: Signal,
) -> (ret: Signal) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Signal, 1)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_signal_object_string_name :: proc "contextless" (
    object_: Object,
    signal_: String_Name,
) -> (ret: Signal) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Signal, 2)
    }
    object_ := object_
    signal_ := signal_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &signal_,
    }
    __ptr(&ret, raw_data(args))
    return
}

free_signal :: proc "contextless" (self: Signal) {
    @(static) __ptr: __bindgen_gde.PtrDestructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_destructor(.Signal)
    }

    self := self
    __ptr(&self)
}

// members


signal_is_null :: proc "contextless" (
    self: ^Signal,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_null", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Signal, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
signal_get_object :: proc "contextless" (
    self: ^Signal,
) -> (ret: Object) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_object", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Signal, &_gde_name, 4008621732)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
signal_get_object_id :: proc "contextless" (
    self: ^Signal,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_object_id", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Signal, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
signal_get_name :: proc "contextless" (
    self: ^Signal,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_name", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Signal, &_gde_name, 1825232092)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
signal_connect :: proc "contextless" (
    self: ^Signal,
    callable_: Callable,
    flags_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("connect", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Signal, &_gde_name, 979702392)
    }
    callable_ := callable_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &callable_,
        &flags_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
signal_disconnect :: proc "contextless" (
    self: ^Signal,
    callable_: Callable,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("disconnect", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Signal, &_gde_name, 3470848906)
    }
    callable_ := callable_
    args := []__bindgen_gde.TypePtr {
        &callable_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
signal_is_connected :: proc "contextless" (
    self: ^Signal,
    callable_: Callable,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_connected", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Signal, &_gde_name, 4129521963)
    }
    callable_ := callable_
    args := []__bindgen_gde.TypePtr {
        &callable_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
signal_get_connections :: proc "contextless" (
    self: ^Signal,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_connections", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Signal, &_gde_name, 4144163970)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
signal_has_connections :: proc "contextless" (
    self: ^Signal,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_connections", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Signal, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
signal_emit :: proc "contextless" (
    self: ^Signal,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("emit", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Signal, &_gde_name, 3286317445)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}

signal_equal_variant :: proc "contextless" (self: Signal, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Signal, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
signal_equal_signal :: proc "contextless" (self: Signal, other: Signal) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Signal, .Signal)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

signal_equal :: proc {
    signal_equal_variant,
    signal_equal_signal,
}
signal_not_equal_variant :: proc "contextless" (self: Signal, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Signal, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
signal_not_equal_signal :: proc "contextless" (self: Signal, other: Signal) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Signal, .Signal)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

signal_not_equal :: proc {
    signal_not_equal_variant,
    signal_not_equal_signal,
}
signal_not_default :: proc "contextless" (self: Signal) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Signal, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

signal_not :: proc {
    signal_not_default,
}
signal_in_dictionary :: proc "contextless" (self: Signal, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Signal, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
signal_in_array :: proc "contextless" (self: Signal, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Signal, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

signal_in :: proc {
    signal_in_dictionary,
    signal_in_array,
}

