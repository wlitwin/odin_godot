package godot

import __bindgen_gde "godot:gdext"





// members


rect2_get_center :: proc "contextless" (
    self: ^Rect2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 2428350749)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_get_area :: proc "contextless" (
    self: ^Rect2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_area", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_has_area :: proc "contextless" (
    self: ^Rect2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_area", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_has_point :: proc "contextless" (
    self: ^Rect2,
    point_: Vector2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_point", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 3190634762)
    }
    point_ := point_
    args := []__bindgen_gde.TypePtr {
        &point_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_is_equal_approx :: proc "contextless" (
    self: ^Rect2,
    rect_: Rect2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_equal_approx", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 1908192260)
    }
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &rect_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_is_finite :: proc "contextless" (
    self: ^Rect2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_finite", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_intersects :: proc "contextless" (
    self: ^Rect2,
    b_: Rect2,
    include_borders_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersects", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 819294880)
    }
    b_ := b_
    include_borders_ := include_borders_
    args := []__bindgen_gde.TypePtr {
        &b_,
        &include_borders_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_encloses :: proc "contextless" (
    self: ^Rect2,
    b_: Rect2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encloses", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 1908192260)
    }
    b_ := b_
    args := []__bindgen_gde.TypePtr {
        &b_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_intersection :: proc "contextless" (
    self: ^Rect2,
    b_: Rect2,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersection", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 2282977743)
    }
    b_ := b_
    args := []__bindgen_gde.TypePtr {
        &b_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_merge :: proc "contextless" (
    self: ^Rect2,
    b_: Rect2,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("merge", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 2282977743)
    }
    b_ := b_
    args := []__bindgen_gde.TypePtr {
        &b_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_expand :: proc "contextless" (
    self: ^Rect2,
    to_: Vector2,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("expand", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 293272265)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_get_support :: proc "contextless" (
    self: ^Rect2,
    direction_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_support", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 2026743667)
    }
    direction_ := direction_
    args := []__bindgen_gde.TypePtr {
        &direction_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_grow :: proc "contextless" (
    self: ^Rect2,
    amount_: f64,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("grow", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 39664498)
    }
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_grow_side :: proc "contextless" (
    self: ^Rect2,
    side_: Int,
    amount_: f64,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("grow_side", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 4177736158)
    }
    side_ := side_
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &side_,
        &amount_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_grow_individual :: proc "contextless" (
    self: ^Rect2,
    left_: f64,
    top_: f64,
    right_: f64,
    bottom_: f64,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("grow_individual", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 3203390369)
    }
    left_ := left_
    top_ := top_
    right_ := right_
    bottom_ := bottom_
    args := []__bindgen_gde.TypePtr {
        &left_,
        &top_,
        &right_,
        &bottom_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2_abs :: proc "contextless" (
    self: ^Rect2,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("abs", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2, &_gde_name, 3107653634)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

rect2_equal_variant :: proc "contextless" (self: Rect2, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Rect2, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
rect2_equal_rect2 :: proc "contextless" (self: Rect2, other: Rect2) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Rect2, .Rect2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rect2_equal :: proc {
    rect2_equal_variant,
    rect2_equal_rect2,
}
rect2_not_equal_variant :: proc "contextless" (self: Rect2, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Rect2, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
rect2_not_equal_rect2 :: proc "contextless" (self: Rect2, other: Rect2) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Rect2, .Rect2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rect2_not_equal :: proc {
    rect2_not_equal_variant,
    rect2_not_equal_rect2,
}
rect2_not_default :: proc "contextless" (self: Rect2) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Rect2, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

rect2_not :: proc {
    rect2_not_default,
}
rect2_multiply_transform2d :: proc "contextless" (self: Rect2, other: Transform2d) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Rect2, .Transform2d)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rect2_multiply :: proc {
    rect2_multiply_transform2d,
}
rect2_in_dictionary :: proc "contextless" (self: Rect2, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Rect2, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
rect2_in_array :: proc "contextless" (self: Rect2, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Rect2, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rect2_in :: proc {
    rect2_in_dictionary,
    rect2_in_array,
}

