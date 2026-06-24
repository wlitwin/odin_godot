package godot

import __bindgen_gde "godot:gdext"
Vector4_Vector4_Axis :: enum int {
    Axis_X = 0,
    Axis_Y = 1,
    Axis_Z = 2,
    Axis_W = 3,
}





// members


vector4_min_axis_index :: proc "contextless" (
    self: ^Vector4,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("min_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_max_axis_index :: proc "contextless" (
    self: ^Vector4,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("max_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_length :: proc "contextless" (
    self: ^Vector4,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_length_squared :: proc "contextless" (
    self: ^Vector4,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length_squared", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_abs :: proc "contextless" (
    self: ^Vector4,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("abs", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 80860099)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_sign :: proc "contextless" (
    self: ^Vector4,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sign", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 80860099)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_floor :: proc "contextless" (
    self: ^Vector4,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("floor", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 80860099)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_ceil :: proc "contextless" (
    self: ^Vector4,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ceil", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 80860099)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_round :: proc "contextless" (
    self: ^Vector4,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("round", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 80860099)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_lerp :: proc "contextless" (
    self: ^Vector4,
    to_: Vector4,
    weight_: f64,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("lerp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 2329757942)
    }
    to_ := to_
    weight_ := weight_
    args := []__bindgen_gde.TypePtr {
        &to_,
        &weight_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_cubic_interpolate :: proc "contextless" (
    self: ^Vector4,
    b_: Vector4,
    pre_a_: Vector4,
    post_b_: Vector4,
    weight_: f64,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cubic_interpolate", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 726768410)
    }
    b_ := b_
    pre_a_ := pre_a_
    post_b_ := post_b_
    weight_ := weight_
    args := []__bindgen_gde.TypePtr {
        &b_,
        &pre_a_,
        &post_b_,
        &weight_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_cubic_interpolate_in_time :: proc "contextless" (
    self: ^Vector4,
    b_: Vector4,
    pre_a_: Vector4,
    post_b_: Vector4,
    weight_: f64,
    b_t_: f64,
    pre_a_t_: f64,
    post_b_t_: f64,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cubic_interpolate_in_time", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 681631873)
    }
    b_ := b_
    pre_a_ := pre_a_
    post_b_ := post_b_
    weight_ := weight_
    b_t_ := b_t_
    pre_a_t_ := pre_a_t_
    post_b_t_ := post_b_t_
    args := []__bindgen_gde.TypePtr {
        &b_,
        &pre_a_,
        &post_b_,
        &weight_,
        &b_t_,
        &pre_a_t_,
        &post_b_t_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_posmod :: proc "contextless" (
    self: ^Vector4,
    mod_: f64,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("posmod", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 3129671720)
    }
    mod_ := mod_
    args := []__bindgen_gde.TypePtr {
        &mod_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_posmodv :: proc "contextless" (
    self: ^Vector4,
    modv_: Vector4,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("posmodv", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 2031281584)
    }
    modv_ := modv_
    args := []__bindgen_gde.TypePtr {
        &modv_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_snapped :: proc "contextless" (
    self: ^Vector4,
    step_: Vector4,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("snapped", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 2031281584)
    }
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &step_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_snappedf :: proc "contextless" (
    self: ^Vector4,
    step_: f64,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("snappedf", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 3129671720)
    }
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &step_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_clamp :: proc "contextless" (
    self: ^Vector4,
    min_: Vector4,
    max_: Vector4,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clamp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 823915692)
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
vector4_clampf :: proc "contextless" (
    self: ^Vector4,
    min_: f64,
    max_: f64,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clampf", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 4072091586)
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
vector4_normalized :: proc "contextless" (
    self: ^Vector4,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("normalized", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 80860099)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_is_normalized :: proc "contextless" (
    self: ^Vector4,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_normalized", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_direction_to :: proc "contextless" (
    self: ^Vector4,
    to_: Vector4,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("direction_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 2031281584)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_distance_to :: proc "contextless" (
    self: ^Vector4,
    to_: Vector4,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("distance_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 3770801042)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_distance_squared_to :: proc "contextless" (
    self: ^Vector4,
    to_: Vector4,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("distance_squared_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 3770801042)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_dot :: proc "contextless" (
    self: ^Vector4,
    with_: Vector4,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("dot", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 3770801042)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_inverse :: proc "contextless" (
    self: ^Vector4,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("inverse", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 80860099)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_is_equal_approx :: proc "contextless" (
    self: ^Vector4,
    to_: Vector4,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_equal_approx", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 88913544)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_is_zero_approx :: proc "contextless" (
    self: ^Vector4,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_zero_approx", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_is_finite :: proc "contextless" (
    self: ^Vector4,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_finite", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_min :: proc "contextless" (
    self: ^Vector4,
    with_: Vector4,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("min", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 2031281584)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_minf :: proc "contextless" (
    self: ^Vector4,
    with_: f64,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("minf", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 3129671720)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_max :: proc "contextless" (
    self: ^Vector4,
    with_: Vector4,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("max", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 2031281584)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector4_maxf :: proc "contextless" (
    self: ^Vector4,
    with_: f64,
) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("maxf", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector4, &_gde_name, 3129671720)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

vector4_equal_variant :: proc "contextless" (self: Vector4, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Vector4, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4_equal_vector4 :: proc "contextless" (self: Vector4, other: Vector4) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Vector4, .Vector4)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4_equal :: proc {
    vector4_equal_variant,
    vector4_equal_vector4,
}
vector4_not_equal_variant :: proc "contextless" (self: Vector4, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Vector4, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4_not_equal_vector4 :: proc "contextless" (self: Vector4, other: Vector4) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Vector4, .Vector4)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4_not_equal :: proc {
    vector4_not_equal_variant,
    vector4_not_equal_vector4,
}
vector4_negate_default :: proc "contextless" (self: Vector4) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Negate, .Vector4, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector4_negate :: proc {
    vector4_negate_default,
}
vector4_positive_default :: proc "contextless" (self: Vector4) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Positive, .Vector4, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector4_positive :: proc {
    vector4_positive_default,
}
vector4_not_default :: proc "contextless" (self: Vector4) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Vector4, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector4_not :: proc {
    vector4_not_default,
}
vector4_multiply_int :: proc "contextless" (self: Vector4, other: Int) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector4, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4_multiply_f64 :: proc "contextless" (self: Vector4, other: f64) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector4, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4_multiply_vector4 :: proc "contextless" (self: Vector4, other: Vector4) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector4, .Vector4)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4_multiply_projection :: proc "contextless" (self: Vector4, other: Projection) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector4, .Projection)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4_multiply :: proc {
    vector4_multiply_int,
    vector4_multiply_f64,
    vector4_multiply_vector4,
    vector4_multiply_projection,
}
vector4_divide_int :: proc "contextless" (self: Vector4, other: Int) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector4, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4_divide_f64 :: proc "contextless" (self: Vector4, other: f64) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector4, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4_divide_vector4 :: proc "contextless" (self: Vector4, other: Vector4) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector4, .Vector4)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4_divide :: proc {
    vector4_divide_int,
    vector4_divide_f64,
    vector4_divide_vector4,
}
vector4_less_vector4 :: proc "contextless" (self: Vector4, other: Vector4) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less, .Vector4, .Vector4)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4_less :: proc {
    vector4_less_vector4,
}
vector4_less_equal_vector4 :: proc "contextless" (self: Vector4, other: Vector4) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less_Equal, .Vector4, .Vector4)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4_less_equal :: proc {
    vector4_less_equal_vector4,
}
vector4_greater_vector4 :: proc "contextless" (self: Vector4, other: Vector4) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater, .Vector4, .Vector4)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4_greater :: proc {
    vector4_greater_vector4,
}
vector4_greater_equal_vector4 :: proc "contextless" (self: Vector4, other: Vector4) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater_Equal, .Vector4, .Vector4)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4_greater_equal :: proc {
    vector4_greater_equal_vector4,
}
vector4_add_vector4 :: proc "contextless" (self: Vector4, other: Vector4) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .Vector4, .Vector4)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4_add :: proc {
    vector4_add_vector4,
}
vector4_subtract_vector4 :: proc "contextless" (self: Vector4, other: Vector4) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Subtract, .Vector4, .Vector4)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4_subtract :: proc {
    vector4_subtract_vector4,
}
vector4_in_dictionary :: proc "contextless" (self: Vector4, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector4, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4_in_array :: proc "contextless" (self: Vector4, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector4, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector4_in_packed_vector4_array :: proc "contextless" (self: Vector4, other: Packed_Vector4_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector4, .Packed_Vector4_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector4_in :: proc {
    vector4_in_dictionary,
    vector4_in_array,
    vector4_in_packed_vector4_array,
}

