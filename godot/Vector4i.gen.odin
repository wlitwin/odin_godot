package godot

import __bindgen_gde "godot:gdext"
Vector4i_Vector4i_Axis :: enum int {
    Axis_X = 0,
    Axis_Y = 1,
    Axis_Z = 2,
    Axis_W = 3,
}





// members


vector4i_min_axis_index :: proc "contextless" (
    self: ^Vector4i,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("min_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_max_axis_index :: proc "contextless" (
    self: ^Vector4i,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("max_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_length :: proc "contextless" (
    self: ^Vector4i,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_length_squared :: proc "contextless" (
    self: ^Vector4i,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length_squared", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_sign :: proc "contextless" (
    self: ^Vector4i,
) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sign", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 4134919947)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_abs :: proc "contextless" (
    self: ^Vector4i,
) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("abs", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 4134919947)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_clamp :: proc "contextless" (
    self: ^Vector4i,
    min_: Vector4i,
    max_: Vector4i,
) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clamp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 3046490913)
    }
    min_ := min_
    max_ := max_
    args := []__bindgen_gde.TypePtr {
        &min_,
        &max_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_clampi :: proc "contextless" (
    self: ^Vector4i,
    min_: Int,
    max_: Int,
) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clampi", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 2994578256)
    }
    min_ := min_
    max_ := max_
    args := []__bindgen_gde.TypePtr {
        &min_,
        &max_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_snapped :: proc "contextless" (
    self: ^Vector4i,
    step_: Vector4i,
) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("snapped", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 1181693102)
    }
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &step_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_snappedi :: proc "contextless" (
    self: ^Vector4i,
    step_: Int,
) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("snappedi", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 1476494415)
    }
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &step_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_min :: proc "contextless" (
    self: ^Vector4i,
    with_: Vector4i,
) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("min", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 1181693102)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_mini :: proc "contextless" (
    self: ^Vector4i,
    with_: Int,
) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("mini", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 1476494415)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_max :: proc "contextless" (
    self: ^Vector4i,
    with_: Vector4i,
) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("max", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 1181693102)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_maxi :: proc "contextless" (
    self: ^Vector4i,
    with_: Int,
) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("maxi", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 1476494415)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_distance_to :: proc "contextless" (
    self: ^Vector4i,
    to_: Vector4i,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("distance_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 3446086573)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4i_distance_squared_to :: proc "contextless" (
    self: ^Vector4i,
    to_: Vector4i,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("distance_squared_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4i, &_gde_name, 346708794)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

vector4i_equal_variant :: proc "contextless" (self: Vector4i, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Vector4i, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4i_equal_vector4i :: proc "contextless" (self: Vector4i, other: Vector4i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Vector4i, .Vector4i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4i_equal :: proc {
    vector4i_equal_variant,
    vector4i_equal_vector4i,
}
vector4i_not_equal_variant :: proc "contextless" (self: Vector4i, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Vector4i, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4i_not_equal_vector4i :: proc "contextless" (self: Vector4i, other: Vector4i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Vector4i, .Vector4i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4i_not_equal :: proc {
    vector4i_not_equal_variant,
    vector4i_not_equal_vector4i,
}
vector4i_negate_default :: proc "contextless" (self: Vector4i) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Negate, .Vector4i, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector4i_negate :: proc {
    vector4i_negate_default,
}
vector4i_positive_default :: proc "contextless" (self: Vector4i) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Positive, .Vector4i, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector4i_positive :: proc {
    vector4i_positive_default,
}
vector4i_not_default :: proc "contextless" (self: Vector4i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Vector4i, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector4i_not :: proc {
    vector4i_not_default,
}
vector4i_multiply_int :: proc "contextless" (self: Vector4i, other: Int) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector4i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4i_multiply_f64 :: proc "contextless" (self: Vector4i, other: f64) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector4i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4i_multiply_vector4i :: proc "contextless" (self: Vector4i, other: Vector4i) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector4i, .Vector4i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4i_multiply :: proc {
    vector4i_multiply_int,
    vector4i_multiply_f64,
    vector4i_multiply_vector4i,
}
vector4i_divide_int :: proc "contextless" (self: Vector4i, other: Int) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector4i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4i_divide_f64 :: proc "contextless" (self: Vector4i, other: f64) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector4i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4i_divide_vector4i :: proc "contextless" (self: Vector4i, other: Vector4i) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector4i, .Vector4i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4i_divide :: proc {
    vector4i_divide_int,
    vector4i_divide_f64,
    vector4i_divide_vector4i,
}
vector4i_module_int :: proc "contextless" (self: Vector4i, other: Int) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .Vector4i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4i_module_vector4i :: proc "contextless" (self: Vector4i, other: Vector4i) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .Vector4i, .Vector4i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4i_module :: proc {
    vector4i_module_int,
    vector4i_module_vector4i,
}
vector4i_less_vector4i :: proc "contextless" (self: Vector4i, other: Vector4i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less, .Vector4i, .Vector4i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4i_less :: proc {
    vector4i_less_vector4i,
}
vector4i_less_equal_vector4i :: proc "contextless" (self: Vector4i, other: Vector4i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less_Equal, .Vector4i, .Vector4i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4i_less_equal :: proc {
    vector4i_less_equal_vector4i,
}
vector4i_greater_vector4i :: proc "contextless" (self: Vector4i, other: Vector4i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater, .Vector4i, .Vector4i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4i_greater :: proc {
    vector4i_greater_vector4i,
}
vector4i_greater_equal_vector4i :: proc "contextless" (self: Vector4i, other: Vector4i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater_Equal, .Vector4i, .Vector4i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4i_greater_equal :: proc {
    vector4i_greater_equal_vector4i,
}
vector4i_add_vector4i :: proc "contextless" (self: Vector4i, other: Vector4i) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .Vector4i, .Vector4i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4i_add :: proc {
    vector4i_add_vector4i,
}
vector4i_subtract_vector4i :: proc "contextless" (self: Vector4i, other: Vector4i) -> (ret: Vector4i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Subtract, .Vector4i, .Vector4i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4i_subtract :: proc {
    vector4i_subtract_vector4i,
}
vector4i_in_dictionary :: proc "contextless" (self: Vector4i, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector4i, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4i_in_array :: proc "contextless" (self: Vector4i, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector4i, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4i_in :: proc {
    vector4i_in_dictionary,
    vector4i_in_array,
}

