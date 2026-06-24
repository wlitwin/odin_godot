package godot

import __bindgen_gde "godot:gdext"





// members


transform3d_inverse :: proc "contextless" (
    self: ^Transform3d,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("inverse", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform3d, &_gde_name, 3816817146)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform3d_affine_inverse :: proc "contextless" (
    self: ^Transform3d,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("affine_inverse", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform3d, &_gde_name, 3816817146)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform3d_orthonormalized :: proc "contextless" (
    self: ^Transform3d,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("orthonormalized", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform3d, &_gde_name, 3816817146)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform3d_rotated :: proc "contextless" (
    self: ^Transform3d,
    axis_: Vector3,
    angle_: f64,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotated", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform3d, &_gde_name, 1563203923)
    }
    axis_ := axis_
    angle_ := angle_
    args := []__bindgen_gde.TypePtr {
        &axis_,
        &angle_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform3d_rotated_local :: proc "contextless" (
    self: ^Transform3d,
    axis_: Vector3,
    angle_: f64,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotated_local", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform3d, &_gde_name, 1563203923)
    }
    axis_ := axis_
    angle_ := angle_
    args := []__bindgen_gde.TypePtr {
        &axis_,
        &angle_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform3d_scaled :: proc "contextless" (
    self: ^Transform3d,
    scale_: Vector3,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("scaled", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform3d, &_gde_name, 1405596198)
    }
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform3d_scaled_local :: proc "contextless" (
    self: ^Transform3d,
    scale_: Vector3,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("scaled_local", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform3d, &_gde_name, 1405596198)
    }
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform3d_translated :: proc "contextless" (
    self: ^Transform3d,
    offset_: Vector3,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("translated", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform3d, &_gde_name, 1405596198)
    }
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform3d_translated_local :: proc "contextless" (
    self: ^Transform3d,
    offset_: Vector3,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("translated_local", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform3d, &_gde_name, 1405596198)
    }
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform3d_looking_at :: proc "contextless" (
    self: ^Transform3d,
    target_: Vector3,
    up_: Vector3,
    use_model_front_: Bool,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("looking_at", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform3d, &_gde_name, 90889270)
    }
    target_ := target_
    up_ := up_
    use_model_front_ := use_model_front_
    args := []__bindgen_gde.TypePtr {
        &target_,
        &up_,
        &use_model_front_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform3d_interpolate_with :: proc "contextless" (
    self: ^Transform3d,
    xform_: Transform3d,
    weight_: f64,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("interpolate_with", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform3d, &_gde_name, 1786453358)
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
transform3d_is_equal_approx :: proc "contextless" (
    self: ^Transform3d,
    xform_: Transform3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_equal_approx", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform3d, &_gde_name, 696001652)
    }
    xform_ := xform_
    args := []__bindgen_gde.TypePtr {
        &xform_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
transform3d_is_finite :: proc "contextless" (
    self: ^Transform3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_finite", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Transform3d, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

transform3d_equal_variant :: proc "contextless" (self: Transform3d, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Transform3d, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform3d_equal_transform3d :: proc "contextless" (self: Transform3d, other: Transform3d) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Transform3d, .Transform3d)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

transform3d_equal :: proc {
    transform3d_equal_variant,
    transform3d_equal_transform3d,
}
transform3d_not_equal_variant :: proc "contextless" (self: Transform3d, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Transform3d, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform3d_not_equal_transform3d :: proc "contextless" (self: Transform3d, other: Transform3d) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Transform3d, .Transform3d)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

transform3d_not_equal :: proc {
    transform3d_not_equal_variant,
    transform3d_not_equal_transform3d,
}
transform3d_not_default :: proc "contextless" (self: Transform3d) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Transform3d, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

transform3d_not :: proc {
    transform3d_not_default,
}
transform3d_multiply_int :: proc "contextless" (self: Transform3d, other: Int) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Transform3d, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform3d_multiply_f64 :: proc "contextless" (self: Transform3d, other: f64) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Transform3d, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform3d_multiply_vector3 :: proc "contextless" (self: Transform3d, other: Vector3) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Transform3d, .Vector3)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform3d_multiply_plane :: proc "contextless" (self: Transform3d, other: Plane) -> (ret: Plane) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Transform3d, .Plane)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform3d_multiply_aabb :: proc "contextless" (self: Transform3d, other: Aabb) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Transform3d, .Aabb)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform3d_multiply_transform3d :: proc "contextless" (self: Transform3d, other: Transform3d) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Transform3d, .Transform3d)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform3d_multiply_packed_vector3_array :: proc "contextless" (self: Transform3d, other: Packed_Vector3_Array) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Transform3d, .Packed_Vector3_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

transform3d_multiply :: proc {
    transform3d_multiply_int,
    transform3d_multiply_f64,
    transform3d_multiply_vector3,
    transform3d_multiply_plane,
    transform3d_multiply_aabb,
    transform3d_multiply_transform3d,
    transform3d_multiply_packed_vector3_array,
}
transform3d_divide_int :: proc "contextless" (self: Transform3d, other: Int) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Transform3d, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform3d_divide_f64 :: proc "contextless" (self: Transform3d, other: f64) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Transform3d, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

transform3d_divide :: proc {
    transform3d_divide_int,
    transform3d_divide_f64,
}
transform3d_in_dictionary :: proc "contextless" (self: Transform3d, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Transform3d, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
transform3d_in_array :: proc "contextless" (self: Transform3d, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Transform3d, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

transform3d_in :: proc {
    transform3d_in_dictionary,
    transform3d_in_array,
}

