package godot

import __bindgen_gde "godot:gdext"





// members

quaternion_from_euler :: proc "contextless" (
    euler_: Vector3,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("from_euler", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 4053467903)
    }
    euler_ := euler_
    args := []__bindgen_gde.TypePtr {
        &euler_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}

quaternion_length :: proc "contextless" (
    self: ^Quaternion,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
quaternion_length_squared :: proc "contextless" (
    self: ^Quaternion,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length_squared", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
quaternion_normalized :: proc "contextless" (
    self: ^Quaternion,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("normalized", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 4274879941)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
quaternion_is_normalized :: proc "contextless" (
    self: ^Quaternion,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_normalized", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
quaternion_is_equal_approx :: proc "contextless" (
    self: ^Quaternion,
    to_: Quaternion,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_equal_approx", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 1682156903)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
quaternion_is_finite :: proc "contextless" (
    self: ^Quaternion,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_finite", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
quaternion_inverse :: proc "contextless" (
    self: ^Quaternion,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("inverse", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 4274879941)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
quaternion_log :: proc "contextless" (
    self: ^Quaternion,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("log", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 4274879941)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
quaternion_exp :: proc "contextless" (
    self: ^Quaternion,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("exp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 4274879941)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
quaternion_angle_to :: proc "contextless" (
    self: ^Quaternion,
    to_: Quaternion,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("angle_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 3244682419)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
quaternion_dot :: proc "contextless" (
    self: ^Quaternion,
    with_: Quaternion,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("dot", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 3244682419)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
quaternion_slerp :: proc "contextless" (
    self: ^Quaternion,
    to_: Quaternion,
    weight_: f64,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("slerp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 1773590316)
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
quaternion_slerpni :: proc "contextless" (
    self: ^Quaternion,
    to_: Quaternion,
    weight_: f64,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("slerpni", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 1773590316)
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
quaternion_spherical_cubic_interpolate :: proc "contextless" (
    self: ^Quaternion,
    b_: Quaternion,
    pre_a_: Quaternion,
    post_b_: Quaternion,
    weight_: f64,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("spherical_cubic_interpolate", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 2150967576)
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
quaternion_spherical_cubic_interpolate_in_time :: proc "contextless" (
    self: ^Quaternion,
    b_: Quaternion,
    pre_a_: Quaternion,
    post_b_: Quaternion,
    weight_: f64,
    b_t_: f64,
    pre_a_t_: f64,
    post_b_t_: f64,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("spherical_cubic_interpolate_in_time", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 1436023539)
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
quaternion_get_euler :: proc "contextless" (
    self: ^Quaternion,
    order_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_euler", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 1394941017)
    }
    order_ := order_
    args := []__bindgen_gde.TypePtr {
        &order_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
quaternion_get_axis :: proc "contextless" (
    self: ^Quaternion,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_axis", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 1776574132)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
quaternion_get_angle :: proc "contextless" (
    self: ^Quaternion,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_angle", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Quaternion, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

quaternion_equal_variant :: proc "contextless" (self: Quaternion, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Quaternion, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
quaternion_equal_quaternion :: proc "contextless" (self: Quaternion, other: Quaternion) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Quaternion, .Quaternion)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

quaternion_equal :: proc {
    quaternion_equal_variant,
    quaternion_equal_quaternion,
}
quaternion_not_equal_variant :: proc "contextless" (self: Quaternion, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Quaternion, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
quaternion_not_equal_quaternion :: proc "contextless" (self: Quaternion, other: Quaternion) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Quaternion, .Quaternion)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

quaternion_not_equal :: proc {
    quaternion_not_equal_variant,
    quaternion_not_equal_quaternion,
}
quaternion_negate_default :: proc "contextless" (self: Quaternion) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Negate, .Quaternion, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

quaternion_negate :: proc {
    quaternion_negate_default,
}
quaternion_positive_default :: proc "contextless" (self: Quaternion) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Positive, .Quaternion, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

quaternion_positive :: proc {
    quaternion_positive_default,
}
quaternion_not_default :: proc "contextless" (self: Quaternion) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Quaternion, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

quaternion_not :: proc {
    quaternion_not_default,
}
quaternion_multiply_int :: proc "contextless" (self: Quaternion, other: Int) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Quaternion, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
quaternion_multiply_f64 :: proc "contextless" (self: Quaternion, other: f64) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Quaternion, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
quaternion_multiply_vector3 :: proc "contextless" (self: Quaternion, other: Vector3) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Quaternion, .Vector3)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
quaternion_multiply_quaternion :: proc "contextless" (self: Quaternion, other: Quaternion) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Quaternion, .Quaternion)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

quaternion_multiply :: proc {
    quaternion_multiply_int,
    quaternion_multiply_f64,
    quaternion_multiply_vector3,
    quaternion_multiply_quaternion,
}
quaternion_divide_int :: proc "contextless" (self: Quaternion, other: Int) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Quaternion, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
quaternion_divide_f64 :: proc "contextless" (self: Quaternion, other: f64) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Quaternion, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

quaternion_divide :: proc {
    quaternion_divide_int,
    quaternion_divide_f64,
}
quaternion_add_quaternion :: proc "contextless" (self: Quaternion, other: Quaternion) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .Quaternion, .Quaternion)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

quaternion_add :: proc {
    quaternion_add_quaternion,
}
quaternion_subtract_quaternion :: proc "contextless" (self: Quaternion, other: Quaternion) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Subtract, .Quaternion, .Quaternion)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

quaternion_subtract :: proc {
    quaternion_subtract_quaternion,
}
quaternion_in_dictionary :: proc "contextless" (self: Quaternion, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Quaternion, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
quaternion_in_array :: proc "contextless" (self: Quaternion, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Quaternion, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

quaternion_in :: proc {
    quaternion_in_dictionary,
    quaternion_in_array,
}

