package godot

import __bindgen_gde "godot:gdext"





// members


rect2i_get_center :: proc "contextless" (
    self: ^Rect2i,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2i, &_gde_name, 3444277866)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2i_get_area :: proc "contextless" (
    self: ^Rect2i,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_area", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2i, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2i_has_area :: proc "contextless" (
    self: ^Rect2i,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_area", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2i, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2i_has_point :: proc "contextless" (
    self: ^Rect2i,
    point_: Vector2i,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_point", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2i, &_gde_name, 328189994)
    }
    point_ := point_
    args := []__bindgen_gde.TypePtr {
        &point_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2i_intersects :: proc "contextless" (
    self: ^Rect2i,
    b_: Rect2i,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersects", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2i, &_gde_name, 3434691493)
    }
    b_ := b_
    args := []__bindgen_gde.TypePtr {
        &b_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2i_encloses :: proc "contextless" (
    self: ^Rect2i,
    b_: Rect2i,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encloses", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2i, &_gde_name, 3434691493)
    }
    b_ := b_
    args := []__bindgen_gde.TypePtr {
        &b_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2i_intersection :: proc "contextless" (
    self: ^Rect2i,
    b_: Rect2i,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersection", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2i, &_gde_name, 717431873)
    }
    b_ := b_
    args := []__bindgen_gde.TypePtr {
        &b_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2i_merge :: proc "contextless" (
    self: ^Rect2i,
    b_: Rect2i,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("merge", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2i, &_gde_name, 717431873)
    }
    b_ := b_
    args := []__bindgen_gde.TypePtr {
        &b_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2i_expand :: proc "contextless" (
    self: ^Rect2i,
    to_: Vector2i,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("expand", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2i, &_gde_name, 1355196872)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2i_grow :: proc "contextless" (
    self: ^Rect2i,
    amount_: Int,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("grow", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2i, &_gde_name, 1578070074)
    }
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
rect2i_grow_side :: proc "contextless" (
    self: ^Rect2i,
    side_: Int,
    amount_: Int,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("grow_side", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2i, &_gde_name, 3191154199)
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
rect2i_grow_individual :: proc "contextless" (
    self: ^Rect2i,
    left_: Int,
    top_: Int,
    right_: Int,
    bottom_: Int,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("grow_individual", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2i, &_gde_name, 1893743416)
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
rect2i_abs :: proc "contextless" (
    self: ^Rect2i,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("abs", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Rect2i, &_gde_name, 1469025700)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

rect2i_equal_variant :: proc "contextless" (self: Rect2i, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Rect2i, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
rect2i_equal_rect2i :: proc "contextless" (self: Rect2i, other: Rect2i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Rect2i, .Rect2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rect2i_equal :: proc {
    rect2i_equal_variant,
    rect2i_equal_rect2i,
}
rect2i_not_equal_variant :: proc "contextless" (self: Rect2i, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Rect2i, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
rect2i_not_equal_rect2i :: proc "contextless" (self: Rect2i, other: Rect2i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Rect2i, .Rect2i)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rect2i_not_equal :: proc {
    rect2i_not_equal_variant,
    rect2i_not_equal_rect2i,
}
rect2i_not_default :: proc "contextless" (self: Rect2i) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Rect2i, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

rect2i_not :: proc {
    rect2i_not_default,
}
rect2i_in_dictionary :: proc "contextless" (self: Rect2i, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Rect2i, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
rect2i_in_array :: proc "contextless" (self: Rect2i, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Rect2i, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

rect2i_in :: proc {
    rect2i_in_dictionary,
    rect2i_in_array,
}

