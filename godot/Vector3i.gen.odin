package godot

import __bindgen_gde "godot:gdext"
Vector3i_Vector3i_Axis :: enum int {
    Axis_X = 0,
    Axis_Y = 1,
    Axis_Z = 2,
}





// members


vector3i_min_axis_index :: proc "contextless" (
    self: ^Vector3i,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("min_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3i_max_axis_index :: proc "contextless" (
    self: ^Vector3i,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("max_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3i_distance_to :: proc "contextless" (
    self: ^Vector3i,
    to_: Vector3i,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("distance_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 1975170430)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3i_distance_squared_to :: proc "contextless" (
    self: ^Vector3i,
    to_: Vector3i,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("distance_squared_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 2947717320)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3i_length :: proc "contextless" (
    self: ^Vector3i,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3i_length_squared :: proc "contextless" (
    self: ^Vector3i,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length_squared", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3i_sign :: proc "contextless" (
    self: ^Vector3i,
) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sign", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 3729604559)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3i_abs :: proc "contextless" (
    self: ^Vector3i,
) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("abs", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 3729604559)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3i_clamp :: proc "contextless" (
    self: ^Vector3i,
    min_: Vector3i,
    max_: Vector3i,
) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clamp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 1086892323)
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
vector3i_clampi :: proc "contextless" (
    self: ^Vector3i,
    min_: Int,
    max_: Int,
) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clampi", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 1077216921)
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
vector3i_snapped :: proc "contextless" (
    self: ^Vector3i,
    step_: Vector3i,
) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("snapped", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 1989319750)
    }
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &step_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3i_snappedi :: proc "contextless" (
    self: ^Vector3i,
    step_: Int,
) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("snappedi", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 2377625641)
    }
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &step_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3i_min :: proc "contextless" (
    self: ^Vector3i,
    with_: Vector3i,
) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("min", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 1989319750)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3i_mini :: proc "contextless" (
    self: ^Vector3i,
    with_: Int,
) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("mini", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 2377625641)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3i_max :: proc "contextless" (
    self: ^Vector3i,
    with_: Vector3i,
) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("max", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 1989319750)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3i_maxi :: proc "contextless" (
    self: ^Vector3i,
    with_: Int,
) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("maxi", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3i, &_gde_name, 2377625641)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

vector3i_equal_variant :: proc "contextless" (self: Vector3i, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Vector3i, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3i_equal_vector3i :: proc "contextless" (self: Vector3i, other: Vector3i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Vector3i, .Vector3i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3i_equal :: proc {
    vector3i_equal_variant,
    vector3i_equal_vector3i,
}
vector3i_not_equal_variant :: proc "contextless" (self: Vector3i, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Vector3i, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3i_not_equal_vector3i :: proc "contextless" (self: Vector3i, other: Vector3i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Vector3i, .Vector3i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3i_not_equal :: proc {
    vector3i_not_equal_variant,
    vector3i_not_equal_vector3i,
}
vector3i_negate_default :: proc "contextless" (self: Vector3i) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Negate, .Vector3i, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector3i_negate :: proc {
    vector3i_negate_default,
}
vector3i_positive_default :: proc "contextless" (self: Vector3i) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Positive, .Vector3i, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector3i_positive :: proc {
    vector3i_positive_default,
}
vector3i_not_default :: proc "contextless" (self: Vector3i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Vector3i, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector3i_not :: proc {
    vector3i_not_default,
}
vector3i_multiply_int :: proc "contextless" (self: Vector3i, other: Int) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector3i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3i_multiply_f64 :: proc "contextless" (self: Vector3i, other: f64) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector3i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3i_multiply_vector3i :: proc "contextless" (self: Vector3i, other: Vector3i) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector3i, .Vector3i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3i_multiply :: proc {
    vector3i_multiply_int,
    vector3i_multiply_f64,
    vector3i_multiply_vector3i,
}
vector3i_divide_int :: proc "contextless" (self: Vector3i, other: Int) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector3i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3i_divide_f64 :: proc "contextless" (self: Vector3i, other: f64) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector3i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3i_divide_vector3i :: proc "contextless" (self: Vector3i, other: Vector3i) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector3i, .Vector3i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3i_divide :: proc {
    vector3i_divide_int,
    vector3i_divide_f64,
    vector3i_divide_vector3i,
}
vector3i_module_int :: proc "contextless" (self: Vector3i, other: Int) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .Vector3i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3i_module_vector3i :: proc "contextless" (self: Vector3i, other: Vector3i) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .Vector3i, .Vector3i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3i_module :: proc {
    vector3i_module_int,
    vector3i_module_vector3i,
}
vector3i_less_vector3i :: proc "contextless" (self: Vector3i, other: Vector3i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less, .Vector3i, .Vector3i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3i_less :: proc {
    vector3i_less_vector3i,
}
vector3i_less_equal_vector3i :: proc "contextless" (self: Vector3i, other: Vector3i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less_Equal, .Vector3i, .Vector3i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3i_less_equal :: proc {
    vector3i_less_equal_vector3i,
}
vector3i_greater_vector3i :: proc "contextless" (self: Vector3i, other: Vector3i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater, .Vector3i, .Vector3i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3i_greater :: proc {
    vector3i_greater_vector3i,
}
vector3i_greater_equal_vector3i :: proc "contextless" (self: Vector3i, other: Vector3i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater_Equal, .Vector3i, .Vector3i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3i_greater_equal :: proc {
    vector3i_greater_equal_vector3i,
}
vector3i_add_vector3i :: proc "contextless" (self: Vector3i, other: Vector3i) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .Vector3i, .Vector3i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3i_add :: proc {
    vector3i_add_vector3i,
}
vector3i_subtract_vector3i :: proc "contextless" (self: Vector3i, other: Vector3i) -> (ret: Vector3i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Subtract, .Vector3i, .Vector3i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3i_subtract :: proc {
    vector3i_subtract_vector3i,
}
vector3i_in_dictionary :: proc "contextless" (self: Vector3i, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector3i, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3i_in_array :: proc "contextless" (self: Vector3i, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector3i, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3i_in :: proc {
    vector3i_in_dictionary,
    vector3i_in_array,
}

