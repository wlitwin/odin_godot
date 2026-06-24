package godot

import __bindgen_gde "godot:gdext"


new_rid :: proc {
    new_rid_default,
    new_rid_rid,
}

new_rid_default :: proc "contextless" (
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Rid, 0)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(&ret, raw_data(args))
    return
}
new_rid_rid :: proc "contextless" (
    from_: Rid,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.PtrConstructor
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_constructor(.Rid, 1)
    }
    from_ := from_
    args := []__bindgen_gde.TypePtr {
        &from_,
    }
    __ptr(&ret, raw_data(args))
    return
}


// members


rid_is_valid :: proc "contextless" (
    self: ^Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rid, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rid_get_id :: proc "contextless" (
    self: ^Rid,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_id", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rid, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

rid_equal_variant :: proc "contextless" (self: Rid, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Rid, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
rid_equal_rid :: proc "contextless" (self: Rid, other: Rid) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Rid, .Rid)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rid_equal :: proc {
    rid_equal_variant,
    rid_equal_rid,
}
rid_not_equal_variant :: proc "contextless" (self: Rid, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Rid, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
rid_not_equal_rid :: proc "contextless" (self: Rid, other: Rid) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Rid, .Rid)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rid_not_equal :: proc {
    rid_not_equal_variant,
    rid_not_equal_rid,
}
rid_not_default :: proc "contextless" (self: Rid) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Rid, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

rid_not :: proc {
    rid_not_default,
}
rid_less_rid :: proc "contextless" (self: Rid, other: Rid) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less, .Rid, .Rid)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rid_less :: proc {
    rid_less_rid,
}
rid_less_equal_rid :: proc "contextless" (self: Rid, other: Rid) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less_Equal, .Rid, .Rid)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rid_less_equal :: proc {
    rid_less_equal_rid,
}
rid_greater_rid :: proc "contextless" (self: Rid, other: Rid) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater, .Rid, .Rid)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rid_greater :: proc {
    rid_greater_rid,
}
rid_greater_equal_rid :: proc "contextless" (self: Rid, other: Rid) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater_Equal, .Rid, .Rid)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rid_greater_equal :: proc {
    rid_greater_equal_rid,
}
rid_in_dictionary :: proc "contextless" (self: Rid, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Rid, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
rid_in_array :: proc "contextless" (self: Rid, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Rid, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rid_in :: proc {
    rid_in_dictionary,
    rid_in_array,
}

