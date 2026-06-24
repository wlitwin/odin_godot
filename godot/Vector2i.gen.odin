package godot

import __bindgen_gde "godot:gdext"
Vector2i_Vector2i_Axis :: enum int {
    Axis_X = 0,
    Axis_Y = 1,
}





// members


vector2i_aspect :: proc "contextless" (
    self: ^Vector2i,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("aspect", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_max_axis_index :: proc "contextless" (
    self: ^Vector2i,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("max_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_min_axis_index :: proc "contextless" (
    self: ^Vector2i,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("min_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_distance_to :: proc "contextless" (
    self: ^Vector2i,
    to_: Vector2i,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("distance_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 707501214)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_distance_squared_to :: proc "contextless" (
    self: ^Vector2i,
    to_: Vector2i,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("distance_squared_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 1130029528)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_length :: proc "contextless" (
    self: ^Vector2i,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_length_squared :: proc "contextless" (
    self: ^Vector2i,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length_squared", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_sign :: proc "contextless" (
    self: ^Vector2i,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sign", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 3444277866)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_abs :: proc "contextless" (
    self: ^Vector2i,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("abs", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 3444277866)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_clamp :: proc "contextless" (
    self: ^Vector2i,
    min_: Vector2i,
    max_: Vector2i,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clamp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 186568249)
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
vector2i_clampi :: proc "contextless" (
    self: ^Vector2i,
    min_: Int,
    max_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clampi", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 3686769569)
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
vector2i_snapped :: proc "contextless" (
    self: ^Vector2i,
    step_: Vector2i,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("snapped", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 1735278196)
    }
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &step_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_snappedi :: proc "contextless" (
    self: ^Vector2i,
    step_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("snappedi", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 2161988953)
    }
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &step_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_min :: proc "contextless" (
    self: ^Vector2i,
    with_: Vector2i,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("min", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 1735278196)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_mini :: proc "contextless" (
    self: ^Vector2i,
    with_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("mini", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 2161988953)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_max :: proc "contextless" (
    self: ^Vector2i,
    with_: Vector2i,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("max", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 1735278196)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2i_maxi :: proc "contextless" (
    self: ^Vector2i,
    with_: Int,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("maxi", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2i, &_gde_name, 2161988953)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

vector2i_equal_variant :: proc "contextless" (self: Vector2i, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Vector2i, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2i_equal_vector2i :: proc "contextless" (self: Vector2i, other: Vector2i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Vector2i, .Vector2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2i_equal :: proc {
    vector2i_equal_variant,
    vector2i_equal_vector2i,
}
vector2i_not_equal_variant :: proc "contextless" (self: Vector2i, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Vector2i, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2i_not_equal_vector2i :: proc "contextless" (self: Vector2i, other: Vector2i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Vector2i, .Vector2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2i_not_equal :: proc {
    vector2i_not_equal_variant,
    vector2i_not_equal_vector2i,
}
vector2i_negate_default :: proc "contextless" (self: Vector2i) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Negate, .Vector2i, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector2i_negate :: proc {
    vector2i_negate_default,
}
vector2i_positive_default :: proc "contextless" (self: Vector2i) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Positive, .Vector2i, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector2i_positive :: proc {
    vector2i_positive_default,
}
vector2i_not_default :: proc "contextless" (self: Vector2i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Vector2i, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector2i_not :: proc {
    vector2i_not_default,
}
vector2i_multiply_int :: proc "contextless" (self: Vector2i, other: Int) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector2i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2i_multiply_f64 :: proc "contextless" (self: Vector2i, other: f64) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector2i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2i_multiply_vector2i :: proc "contextless" (self: Vector2i, other: Vector2i) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector2i, .Vector2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2i_multiply :: proc {
    vector2i_multiply_int,
    vector2i_multiply_f64,
    vector2i_multiply_vector2i,
}
vector2i_divide_int :: proc "contextless" (self: Vector2i, other: Int) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector2i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2i_divide_f64 :: proc "contextless" (self: Vector2i, other: f64) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector2i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2i_divide_vector2i :: proc "contextless" (self: Vector2i, other: Vector2i) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector2i, .Vector2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2i_divide :: proc {
    vector2i_divide_int,
    vector2i_divide_f64,
    vector2i_divide_vector2i,
}
vector2i_module_int :: proc "contextless" (self: Vector2i, other: Int) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .Vector2i, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2i_module_vector2i :: proc "contextless" (self: Vector2i, other: Vector2i) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Module, .Vector2i, .Vector2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2i_module :: proc {
    vector2i_module_int,
    vector2i_module_vector2i,
}
vector2i_less_vector2i :: proc "contextless" (self: Vector2i, other: Vector2i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less, .Vector2i, .Vector2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2i_less :: proc {
    vector2i_less_vector2i,
}
vector2i_less_equal_vector2i :: proc "contextless" (self: Vector2i, other: Vector2i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less_Equal, .Vector2i, .Vector2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2i_less_equal :: proc {
    vector2i_less_equal_vector2i,
}
vector2i_greater_vector2i :: proc "contextless" (self: Vector2i, other: Vector2i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater, .Vector2i, .Vector2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2i_greater :: proc {
    vector2i_greater_vector2i,
}
vector2i_greater_equal_vector2i :: proc "contextless" (self: Vector2i, other: Vector2i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater_Equal, .Vector2i, .Vector2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2i_greater_equal :: proc {
    vector2i_greater_equal_vector2i,
}
vector2i_add_vector2i :: proc "contextless" (self: Vector2i, other: Vector2i) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .Vector2i, .Vector2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2i_add :: proc {
    vector2i_add_vector2i,
}
vector2i_subtract_vector2i :: proc "contextless" (self: Vector2i, other: Vector2i) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Subtract, .Vector2i, .Vector2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2i_subtract :: proc {
    vector2i_subtract_vector2i,
}
vector2i_in_dictionary :: proc "contextless" (self: Vector2i, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector2i, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2i_in_array :: proc "contextless" (self: Vector2i, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector2i, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2i_in :: proc {
    vector2i_in_dictionary,
    vector2i_in_array,
}

