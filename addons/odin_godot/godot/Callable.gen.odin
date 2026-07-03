package godot

import __bindgen_gde "godot:gdext"


new_callable :: proc {
    new_callable_default,
    new_callable_callable,
    new_callable_object_string_name,
}

new_callable_default :: proc "contextless" (
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Callable, 0)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(&ret, raw_data(args))
    return
}
new_callable_callable :: proc "contextless" (
    from_: Callable,
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Callable, 1)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}
new_callable_object_string_name :: proc "contextless" (
    object_: Object,
    method_: String_Name,
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Callable, 2)
    }
    object_ := object_
    method_ := method_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &method_,
    }
    __ptr(&ret, raw_data(args))
    return
}

free_callable :: proc "contextless" (self: Callable) {
    @(static) __ptr: __bindgen_gde.PtrDestructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_destructor(.Callable)
    }

    self := self
    __ptr(&self)
}

// members

callable_create :: proc "contextless" (
    variant_: Variant,
    method_: String_Name,
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 1709381114)
    }
    variant_ := variant_
    method_ := method_
    args := []__bindgen_gde.TypePtr {
        &variant_,
        &method_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}

callable_callv :: proc "contextless" (
    self: ^Callable,
    arguments_: Array,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("callv", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 413578926)
    }
    arguments_ := arguments_
    args := []__bindgen_gde.TypePtr {
        &arguments_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_is_null :: proc "contextless" (
    self: ^Callable,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_null", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_is_custom :: proc "contextless" (
    self: ^Callable,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_custom", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_is_standard :: proc "contextless" (
    self: ^Callable,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_standard", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_is_valid :: proc "contextless" (
    self: ^Callable,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_get_object :: proc "contextless" (
    self: ^Callable,
) -> (ret: Object) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_object", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 4008621732)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_get_object_id :: proc "contextless" (
    self: ^Callable,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_object_id", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_get_method :: proc "contextless" (
    self: ^Callable,
) -> (ret: String_Name) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_method", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 1825232092)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_get_argument_count :: proc "contextless" (
    self: ^Callable,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_argument_count", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_get_bound_arguments_count :: proc "contextless" (
    self: ^Callable,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bound_arguments_count", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_get_bound_arguments :: proc "contextless" (
    self: ^Callable,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bound_arguments", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 4144163970)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_get_unbound_arguments_count :: proc "contextless" (
    self: ^Callable,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_unbound_arguments_count", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_hash :: proc "contextless" (
    self: ^Callable,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hash", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_bindv :: proc "contextless" (
    self: ^Callable,
    arguments_: Array,
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bindv", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3564560322)
    }
    arguments_ := arguments_
    args := []__bindgen_gde.TypePtr {
        &arguments_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_unbind :: proc "contextless" (
    self: ^Callable,
    argcount_: Int,
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unbind", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 755001590)
    }
    argcount_ := argcount_
    args := []__bindgen_gde.TypePtr {
        &argcount_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_call :: proc "contextless" (
    self: ^Callable,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("call", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3643564216)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
callable_call_deferred :: proc "contextless" (
    self: ^Callable,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("call_deferred", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3286317445)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
callable_rpc :: proc "contextless" (
    self: ^Callable,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rpc", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3286317445)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
callable_rpc_id :: proc "contextless" (
    self: ^Callable,
    peer_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rpc_id", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 2270047679)
    }
    peer_id_ := peer_id_
    args := []__bindgen_gde.TypePtr {
        &peer_id_,
    }
    __ptr(self, raw_data(args), nil, len(args))
    return
}
callable_bind :: proc "contextless" (
    self: ^Callable,
) -> (ret: Callable) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bind", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Callable, &_gde_name, 3224143119)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

callable_equal_variant :: proc "contextless" (self: Callable, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Callable, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
callable_equal_callable :: proc "contextless" (self: Callable, other: Callable) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Callable, .Callable)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

callable_equal :: proc {
    callable_equal_variant,
    callable_equal_callable,
}
callable_not_equal_variant :: proc "contextless" (self: Callable, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Callable, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
callable_not_equal_callable :: proc "contextless" (self: Callable, other: Callable) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Callable, .Callable)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

callable_not_equal :: proc {
    callable_not_equal_variant,
    callable_not_equal_callable,
}
callable_not_default :: proc "contextless" (self: Callable) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Callable, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

callable_not :: proc {
    callable_not_default,
}
callable_in_dictionary :: proc "contextless" (self: Callable, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Callable, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
callable_in_array :: proc "contextless" (self: Callable, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Callable, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

callable_in :: proc {
    callable_in_dictionary,
    callable_in_array,
}

