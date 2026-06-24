package godot

import __bindgen_gde "godot:gdext"





// members

color_hex :: proc "contextless" (
    hex_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hex", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 351421375)
    }
    hex_ := hex_
    args := []__bindgen_gde.TypePtr {
        &hex_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
color_hex64 :: proc "contextless" (
    hex_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hex64", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 351421375)
    }
    hex_ := hex_
    args := []__bindgen_gde.TypePtr {
        &hex_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
color_html :: proc "contextless" (
    rgba_: String,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("html", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 2500054655)
    }
    rgba_ := rgba_
    args := []__bindgen_gde.TypePtr {
        &rgba_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
color_html_is_valid :: proc "contextless" (
    color_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("html_is_valid", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 2942997125)
    }
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
color_from_string :: proc "contextless" (
    str_: String,
    default_: Color,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("from_string", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3755044230)
    }
    str_ := str_
    default_ := default_
    args := []__bindgen_gde.TypePtr {
        &str_,
        &default_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
color_from_hsv :: proc "contextless" (
    h_: f64,
    s_: f64,
    v_: f64,
    alpha_: f64,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("from_hsv", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 1573799446)
    }
    h_ := h_
    s_ := s_
    v_ := v_
    alpha_ := alpha_
    args := []__bindgen_gde.TypePtr {
        &h_,
        &s_,
        &v_,
        &alpha_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
color_from_ok_hsl :: proc "contextless" (
    h_: f64,
    s_: f64,
    l_: f64,
    alpha_: f64,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("from_ok_hsl", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 1573799446)
    }
    h_ := h_
    s_ := s_
    l_ := l_
    alpha_ := alpha_
    args := []__bindgen_gde.TypePtr {
        &h_,
        &s_,
        &l_,
        &alpha_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
color_from_rgbe9995 :: proc "contextless" (
    rgbe_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("from_rgbe9995", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 351421375)
    }
    rgbe_ := rgbe_
    args := []__bindgen_gde.TypePtr {
        &rgbe_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
color_from_rgba8 :: proc "contextless" (
    r8_: Int,
    g8_: Int,
    b8_: Int,
    a8_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("from_rgba8", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3072934735)
    }
    r8_ := r8_
    g8_ := g8_
    b8_ := b8_
    a8_ := a8_
    args := []__bindgen_gde.TypePtr {
        &r8_,
        &g8_,
        &b8_,
        &a8_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}

color_to_argb32 :: proc "contextless" (
    self: ^Color,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_argb32", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_to_abgr32 :: proc "contextless" (
    self: ^Color,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_abgr32", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_to_rgba32 :: proc "contextless" (
    self: ^Color,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_rgba32", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_to_argb64 :: proc "contextless" (
    self: ^Color,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_argb64", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_to_abgr64 :: proc "contextless" (
    self: ^Color,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_abgr64", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_to_rgba64 :: proc "contextless" (
    self: ^Color,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_rgba64", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_to_html :: proc "contextless" (
    self: ^Color,
    with_alpha_: Bool,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_html", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3429816538)
    }
    with_alpha_ := with_alpha_
    args := []__bindgen_gde.TypePtr {
        &with_alpha_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_clamp :: proc "contextless" (
    self: ^Color,
    min_: Color,
    max_: Color,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clamp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 105651410)
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
color_inverted :: proc "contextless" (
    self: ^Color,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("inverted", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3334027602)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_lerp :: proc "contextless" (
    self: ^Color,
    to_: Color,
    weight_: f64,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("lerp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 402949615)
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
color_lightened :: proc "contextless" (
    self: ^Color,
    amount_: f64,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("lightened", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 1466039168)
    }
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_darkened :: proc "contextless" (
    self: ^Color,
    amount_: f64,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("darkened", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 1466039168)
    }
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_blend :: proc "contextless" (
    self: ^Color,
    over_: Color,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("blend", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3803690977)
    }
    over_ := over_
    args := []__bindgen_gde.TypePtr {
        &over_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_get_luminance :: proc "contextless" (
    self: ^Color,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_luminance", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_srgb_to_linear :: proc "contextless" (
    self: ^Color,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("srgb_to_linear", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3334027602)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_linear_to_srgb :: proc "contextless" (
    self: ^Color,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("linear_to_srgb", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3334027602)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
color_is_equal_approx :: proc "contextless" (
    self: ^Color,
    to_: Color,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_equal_approx", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Color, &_gde_name, 3167426256)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

color_equal_variant :: proc "contextless" (self: Color, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Color, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
color_equal_color :: proc "contextless" (self: Color, other: Color) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Color, .Color)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

color_equal :: proc {
    color_equal_variant,
    color_equal_color,
}
color_not_equal_variant :: proc "contextless" (self: Color, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Color, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
color_not_equal_color :: proc "contextless" (self: Color, other: Color) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Color, .Color)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

color_not_equal :: proc {
    color_not_equal_variant,
    color_not_equal_color,
}
color_negate_default :: proc "contextless" (self: Color) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Negate, .Color, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

color_negate :: proc {
    color_negate_default,
}
color_positive_default :: proc "contextless" (self: Color) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Positive, .Color, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

color_positive :: proc {
    color_positive_default,
}
color_not_default :: proc "contextless" (self: Color) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Color, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

color_not :: proc {
    color_not_default,
}
color_multiply_int :: proc "contextless" (self: Color, other: Int) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Color, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
color_multiply_f64 :: proc "contextless" (self: Color, other: f64) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Color, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
color_multiply_color :: proc "contextless" (self: Color, other: Color) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Color, .Color)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

color_multiply :: proc {
    color_multiply_int,
    color_multiply_f64,
    color_multiply_color,
}
color_divide_int :: proc "contextless" (self: Color, other: Int) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Color, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
color_divide_f64 :: proc "contextless" (self: Color, other: f64) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Color, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
color_divide_color :: proc "contextless" (self: Color, other: Color) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Color, .Color)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

color_divide :: proc {
    color_divide_int,
    color_divide_f64,
    color_divide_color,
}
color_add_color :: proc "contextless" (self: Color, other: Color) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .Color, .Color)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

color_add :: proc {
    color_add_color,
}
color_subtract_color :: proc "contextless" (self: Color, other: Color) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Subtract, .Color, .Color)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

color_subtract :: proc {
    color_subtract_color,
}
color_in_dictionary :: proc "contextless" (self: Color, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Color, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
color_in_array :: proc "contextless" (self: Color, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Color, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
color_in_packed_color_array :: proc "contextless" (self: Color, other: Packed_Color_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Color, .Packed_Color_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

color_in :: proc {
    color_in_dictionary,
    color_in_array,
    color_in_packed_color_array,
}

