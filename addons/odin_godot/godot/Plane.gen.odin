package godot

import __bindgen_gde "godot:gdext"





// members


plane_normalized :: proc "contextless" (
    self: ^Plane,
) -> (ret: Plane) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("normalized", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Plane, &_gde_name, 1051796340)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
plane_get_center :: proc "contextless" (
    self: ^Plane,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Plane, &_gde_name, 1776574132)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
plane_is_equal_approx :: proc "contextless" (
    self: ^Plane,
    to_plane_: Plane,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_equal_approx", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Plane, &_gde_name, 1150170233)
    }
    to_plane_ := to_plane_
    args := []__bindgen_gde.TypePtr {
        &to_plane_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
plane_is_finite :: proc "contextless" (
    self: ^Plane,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_finite", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Plane, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
plane_is_point_over :: proc "contextless" (
    self: ^Plane,
    point_: Vector3,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_point_over", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Plane, &_gde_name, 1749054343)
    }
    point_ := point_
    args := []__bindgen_gde.TypePtr {
        &point_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
plane_distance_to :: proc "contextless" (
    self: ^Plane,
    point_: Vector3,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("distance_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Plane, &_gde_name, 1047977935)
    }
    point_ := point_
    args := []__bindgen_gde.TypePtr {
        &point_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
plane_has_point :: proc "contextless" (
    self: ^Plane,
    point_: Vector3,
    tolerance_: f64,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_point", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Plane, &_gde_name, 1258189072)
    }
    point_ := point_
    tolerance_ := tolerance_
    args := []__bindgen_gde.TypePtr {
        &point_,
        &tolerance_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
plane_project :: proc "contextless" (
    self: ^Plane,
    point_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("project", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Plane, &_gde_name, 2923479887)
    }
    point_ := point_
    args := []__bindgen_gde.TypePtr {
        &point_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
plane_intersect_3 :: proc "contextless" (
    self: ^Plane,
    b_: Plane,
    c_: Plane,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersect_3", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Plane, &_gde_name, 2012052692)
    }
    b_ := b_
    c_ := c_
    args := []__bindgen_gde.TypePtr {
        &b_,
        &c_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
plane_intersects_ray :: proc "contextless" (
    self: ^Plane,
    from_: Vector3,
    dir_: Vector3,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersects_ray", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Plane, &_gde_name, 2048133369)
    }
    from_ := from_
    dir_ := dir_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &dir_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
plane_intersects_segment :: proc "contextless" (
    self: ^Plane,
    from_: Vector3,
    to_: Vector3,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersects_segment", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Plane, &_gde_name, 2048133369)
    }
    from_ := from_
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

plane_equal_variant :: proc "contextless" (self: Plane, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Plane, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
plane_equal_plane :: proc "contextless" (self: Plane, other: Plane) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Plane, .Plane)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

plane_equal :: proc {
    plane_equal_variant,
    plane_equal_plane,
}
plane_not_equal_variant :: proc "contextless" (self: Plane, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Plane, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
plane_not_equal_plane :: proc "contextless" (self: Plane, other: Plane) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Plane, .Plane)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

plane_not_equal :: proc {
    plane_not_equal_variant,
    plane_not_equal_plane,
}
plane_negate_default :: proc "contextless" (self: Plane) -> (ret: Plane) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Negate, .Plane, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

plane_negate :: proc {
    plane_negate_default,
}
plane_positive_default :: proc "contextless" (self: Plane) -> (ret: Plane) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Positive, .Plane, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

plane_positive :: proc {
    plane_positive_default,
}
plane_not_default :: proc "contextless" (self: Plane) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Plane, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

plane_not :: proc {
    plane_not_default,
}
plane_multiply_transform3d :: proc "contextless" (self: Plane, other: Transform3d) -> (ret: Plane) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Plane, .Transform3d)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

plane_multiply :: proc {
    plane_multiply_transform3d,
}
plane_in_dictionary :: proc "contextless" (self: Plane, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Plane, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
plane_in_array :: proc "contextless" (self: Plane, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Plane, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

plane_in :: proc {
    plane_in_dictionary,
    plane_in_array,
}

