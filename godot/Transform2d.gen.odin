package godot

import __bindgen_gde "godot:gdext"





// members


transform2d_inverse :: proc "contextless" (
    self: ^Transform2d,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("inverse", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 1420440541)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_affine_inverse :: proc "contextless" (
    self: ^Transform2d,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("affine_inverse", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 1420440541)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_get_rotation :: proc "contextless" (
    self: ^Transform2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rotation", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_get_origin :: proc "contextless" (
    self: ^Transform2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_origin", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 2428350749)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_get_scale :: proc "contextless" (
    self: ^Transform2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scale", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 2428350749)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_get_skew :: proc "contextless" (
    self: ^Transform2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skew", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_orthonormalized :: proc "contextless" (
    self: ^Transform2d,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("orthonormalized", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 1420440541)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_rotated :: proc "contextless" (
    self: ^Transform2d,
    angle_: f64,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotated", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 729597514)
    }
    angle_ := angle_
    args := []__bindgen_gde.TypePtr {
        &angle_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_rotated_local :: proc "contextless" (
    self: ^Transform2d,
    angle_: f64,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotated_local", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 729597514)
    }
    angle_ := angle_
    args := []__bindgen_gde.TypePtr {
        &angle_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_scaled :: proc "contextless" (
    self: ^Transform2d,
    scale_: Vector2,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("scaled", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 1446323263)
    }
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_scaled_local :: proc "contextless" (
    self: ^Transform2d,
    scale_: Vector2,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("scaled_local", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 1446323263)
    }
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_translated :: proc "contextless" (
    self: ^Transform2d,
    offset_: Vector2,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("translated", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 1446323263)
    }
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_translated_local :: proc "contextless" (
    self: ^Transform2d,
    offset_: Vector2,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("translated_local", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 1446323263)
    }
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_determinant :: proc "contextless" (
    self: ^Transform2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("determinant", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_basis_xform :: proc "contextless" (
    self: ^Transform2d,
    v_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("basis_xform", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 2026743667)
    }
    v_ := v_
    args := []__bindgen_gde.TypePtr {
        &v_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_basis_xform_inv :: proc "contextless" (
    self: ^Transform2d,
    v_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("basis_xform_inv", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 2026743667)
    }
    v_ := v_
    args := []__bindgen_gde.TypePtr {
        &v_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_interpolate_with :: proc "contextless" (
    self: ^Transform2d,
    xform_: Transform2d,
    weight_: f64,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("interpolate_with", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 359399686)
    }
    xform_ := xform_
    weight_ := weight_
    args := []__bindgen_gde.TypePtr {
        &xform_,
        &weight_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_is_conformal :: proc "contextless" (
    self: ^Transform2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_conformal", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_is_equal_approx :: proc "contextless" (
    self: ^Transform2d,
    xform_: Transform2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_equal_approx", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 3837431929)
    }
    xform_ := xform_
    args := []__bindgen_gde.TypePtr {
        &xform_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_is_finite :: proc "contextless" (
    self: ^Transform2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_finite", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform2d_looking_at :: proc "contextless" (
    self: ^Transform2d,
    target_: Vector2,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("looking_at", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform2d, &_gde_name, 1446323263)
    }
    target_ := target_
    args := []__bindgen_gde.TypePtr {
        &target_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

transform2d_equal_variant :: proc "contextless" (self: Transform2d, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Transform2d, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform2d_equal_transform2d :: proc "contextless" (self: Transform2d, other: Transform2d) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Transform2d, .Transform2d)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

transform2d_equal :: proc {
    transform2d_equal_variant,
    transform2d_equal_transform2d,
}
transform2d_not_equal_variant :: proc "contextless" (self: Transform2d, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Transform2d, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform2d_not_equal_transform2d :: proc "contextless" (self: Transform2d, other: Transform2d) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Transform2d, .Transform2d)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

transform2d_not_equal :: proc {
    transform2d_not_equal_variant,
    transform2d_not_equal_transform2d,
}
transform2d_not_default :: proc "contextless" (self: Transform2d) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Transform2d, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

transform2d_not :: proc {
    transform2d_not_default,
}
transform2d_multiply_int :: proc "contextless" (self: Transform2d, other: Int) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Transform2d, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform2d_multiply_f64 :: proc "contextless" (self: Transform2d, other: f64) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Transform2d, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform2d_multiply_vector2 :: proc "contextless" (self: Transform2d, other: Vector2) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Transform2d, .Vector2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform2d_multiply_rect2 :: proc "contextless" (self: Transform2d, other: Rect2) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Transform2d, .Rect2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform2d_multiply_transform2d :: proc "contextless" (self: Transform2d, other: Transform2d) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Transform2d, .Transform2d)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform2d_multiply_packed_vector2_array :: proc "contextless" (self: Transform2d, other: Packed_Vector2_Array) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Transform2d, .Packed_Vector2_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

transform2d_multiply :: proc {
    transform2d_multiply_int,
    transform2d_multiply_f64,
    transform2d_multiply_vector2,
    transform2d_multiply_rect2,
    transform2d_multiply_transform2d,
    transform2d_multiply_packed_vector2_array,
}
transform2d_divide_int :: proc "contextless" (self: Transform2d, other: Int) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Transform2d, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform2d_divide_f64 :: proc "contextless" (self: Transform2d, other: f64) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Transform2d, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

transform2d_divide :: proc {
    transform2d_divide_int,
    transform2d_divide_f64,
}
transform2d_in_dictionary :: proc "contextless" (self: Transform2d, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Transform2d, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform2d_in_array :: proc "contextless" (self: Transform2d, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Transform2d, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

transform2d_in :: proc {
    transform2d_in_dictionary,
    transform2d_in_array,
}

