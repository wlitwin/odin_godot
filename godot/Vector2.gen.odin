package godot

import __bindgen_gde "godot:gdext"
Vector2_Vector2_Axis :: enum int {
    Axis_X = 0,
    Axis_Y = 1,
}





// members

vector2_from_angle :: proc "contextless" (
    angle_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("from_angle", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 889263119)
    }
    angle_ := angle_
    args := []__bindgen_gde.TypePtr {
        &angle_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}

vector2_angle :: proc "contextless" (
    self: ^Vector2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("angle", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_angle_to :: proc "contextless" (
    self: ^Vector2,
    to_: Vector2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("angle_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 3819070308)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_angle_to_point :: proc "contextless" (
    self: ^Vector2,
    to_: Vector2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("angle_to_point", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 3819070308)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_direction_to :: proc "contextless" (
    self: ^Vector2,
    to_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("direction_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2026743667)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_distance_to :: proc "contextless" (
    self: ^Vector2,
    to_: Vector2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("distance_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 3819070308)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_distance_squared_to :: proc "contextless" (
    self: ^Vector2,
    to_: Vector2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("distance_squared_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 3819070308)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_length :: proc "contextless" (
    self: ^Vector2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_length_squared :: proc "contextless" (
    self: ^Vector2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length_squared", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_limit_length :: proc "contextless" (
    self: ^Vector2,
    length_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("limit_length", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2544004089)
    }
    length_ := length_
    args := []__bindgen_gde.TypePtr {
        &length_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_normalized :: proc "contextless" (
    self: ^Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("normalized", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2428350749)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_is_normalized :: proc "contextless" (
    self: ^Vector2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_normalized", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_is_equal_approx :: proc "contextless" (
    self: ^Vector2,
    to_: Vector2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_equal_approx", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 3190634762)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_is_zero_approx :: proc "contextless" (
    self: ^Vector2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_zero_approx", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_is_finite :: proc "contextless" (
    self: ^Vector2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_finite", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_posmod :: proc "contextless" (
    self: ^Vector2,
    mod_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("posmod", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2544004089)
    }
    mod_ := mod_
    args := []__bindgen_gde.TypePtr {
        &mod_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_posmodv :: proc "contextless" (
    self: ^Vector2,
    modv_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("posmodv", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2026743667)
    }
    modv_ := modv_
    args := []__bindgen_gde.TypePtr {
        &modv_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_project :: proc "contextless" (
    self: ^Vector2,
    b_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("project", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2026743667)
    }
    b_ := b_
    args := []__bindgen_gde.TypePtr {
        &b_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_lerp :: proc "contextless" (
    self: ^Vector2,
    to_: Vector2,
    weight_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("lerp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 4250033116)
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
vector2_slerp :: proc "contextless" (
    self: ^Vector2,
    to_: Vector2,
    weight_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("slerp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 4250033116)
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
vector2_cubic_interpolate :: proc "contextless" (
    self: ^Vector2,
    b_: Vector2,
    pre_a_: Vector2,
    post_b_: Vector2,
    weight_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cubic_interpolate", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 193522989)
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
vector2_cubic_interpolate_in_time :: proc "contextless" (
    self: ^Vector2,
    b_: Vector2,
    pre_a_: Vector2,
    post_b_: Vector2,
    weight_: f64,
    b_t_: f64,
    pre_a_t_: f64,
    post_b_t_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cubic_interpolate_in_time", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 1957055074)
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
vector2_bezier_interpolate :: proc "contextless" (
    self: ^Vector2,
    control_1_: Vector2,
    control_2_: Vector2,
    end_: Vector2,
    t_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bezier_interpolate", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 193522989)
    }
    control_1_ := control_1_
    control_2_ := control_2_
    end_ := end_
    t_ := t_
    args := []__bindgen_gde.TypePtr {
        &control_1_,
        &control_2_,
        &end_,
        &t_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_bezier_derivative :: proc "contextless" (
    self: ^Vector2,
    control_1_: Vector2,
    control_2_: Vector2,
    end_: Vector2,
    t_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bezier_derivative", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 193522989)
    }
    control_1_ := control_1_
    control_2_ := control_2_
    end_ := end_
    t_ := t_
    args := []__bindgen_gde.TypePtr {
        &control_1_,
        &control_2_,
        &end_,
        &t_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_max_axis_index :: proc "contextless" (
    self: ^Vector2,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("max_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_min_axis_index :: proc "contextless" (
    self: ^Vector2,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("min_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_move_toward :: proc "contextless" (
    self: ^Vector2,
    to_: Vector2,
    delta_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_toward", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 4250033116)
    }
    to_ := to_
    delta_ := delta_
    args := []__bindgen_gde.TypePtr {
        &to_,
        &delta_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_rotated :: proc "contextless" (
    self: ^Vector2,
    angle_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotated", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2544004089)
    }
    angle_ := angle_
    args := []__bindgen_gde.TypePtr {
        &angle_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_orthogonal :: proc "contextless" (
    self: ^Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("orthogonal", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2428350749)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_floor :: proc "contextless" (
    self: ^Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("floor", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2428350749)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_ceil :: proc "contextless" (
    self: ^Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ceil", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2428350749)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_round :: proc "contextless" (
    self: ^Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("round", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2428350749)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_aspect :: proc "contextless" (
    self: ^Vector2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("aspect", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_dot :: proc "contextless" (
    self: ^Vector2,
    with_: Vector2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("dot", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 3819070308)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_slide :: proc "contextless" (
    self: ^Vector2,
    n_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("slide", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2026743667)
    }
    n_ := n_
    args := []__bindgen_gde.TypePtr {
        &n_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_bounce :: proc "contextless" (
    self: ^Vector2,
    n_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bounce", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2026743667)
    }
    n_ := n_
    args := []__bindgen_gde.TypePtr {
        &n_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_reflect :: proc "contextless" (
    self: ^Vector2,
    line_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reflect", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2026743667)
    }
    line_ := line_
    args := []__bindgen_gde.TypePtr {
        &line_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_cross :: proc "contextless" (
    self: ^Vector2,
    with_: Vector2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cross", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 3819070308)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_abs :: proc "contextless" (
    self: ^Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("abs", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2428350749)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_sign :: proc "contextless" (
    self: ^Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sign", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2428350749)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_clamp :: proc "contextless" (
    self: ^Vector2,
    min_: Vector2,
    max_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clamp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 318031021)
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
vector2_clampf :: proc "contextless" (
    self: ^Vector2,
    min_: f64,
    max_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clampf", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 3464402636)
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
vector2_snapped :: proc "contextless" (
    self: ^Vector2,
    step_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("snapped", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2026743667)
    }
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &step_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_snappedf :: proc "contextless" (
    self: ^Vector2,
    step_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("snappedf", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2544004089)
    }
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &step_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_min :: proc "contextless" (
    self: ^Vector2,
    with_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("min", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2026743667)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_minf :: proc "contextless" (
    self: ^Vector2,
    with_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("minf", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2544004089)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_max :: proc "contextless" (
    self: ^Vector2,
    with_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("max", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2026743667)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector2_maxf :: proc "contextless" (
    self: ^Vector2,
    with_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("maxf", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector2, &_gde_name, 2544004089)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

vector2_equal_variant :: proc "contextless" (self: Vector2, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Vector2, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2_equal_vector2 :: proc "contextless" (self: Vector2, other: Vector2) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Vector2, .Vector2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2_equal :: proc {
    vector2_equal_variant,
    vector2_equal_vector2,
}
vector2_not_equal_variant :: proc "contextless" (self: Vector2, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Vector2, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2_not_equal_vector2 :: proc "contextless" (self: Vector2, other: Vector2) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Vector2, .Vector2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2_not_equal :: proc {
    vector2_not_equal_variant,
    vector2_not_equal_vector2,
}
vector2_negate_default :: proc "contextless" (self: Vector2) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Negate, .Vector2, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector2_negate :: proc {
    vector2_negate_default,
}
vector2_positive_default :: proc "contextless" (self: Vector2) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Positive, .Vector2, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector2_positive :: proc {
    vector2_positive_default,
}
vector2_not_default :: proc "contextless" (self: Vector2) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Vector2, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector2_not :: proc {
    vector2_not_default,
}
vector2_multiply_int :: proc "contextless" (self: Vector2, other: Int) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector2, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2_multiply_f64 :: proc "contextless" (self: Vector2, other: f64) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector2, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2_multiply_vector2 :: proc "contextless" (self: Vector2, other: Vector2) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector2, .Vector2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2_multiply_transform2d :: proc "contextless" (self: Vector2, other: Transform2d) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector2, .Transform2d)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2_multiply :: proc {
    vector2_multiply_int,
    vector2_multiply_f64,
    vector2_multiply_vector2,
    vector2_multiply_transform2d,
}
vector2_divide_int :: proc "contextless" (self: Vector2, other: Int) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector2, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2_divide_f64 :: proc "contextless" (self: Vector2, other: f64) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector2, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2_divide_vector2 :: proc "contextless" (self: Vector2, other: Vector2) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector2, .Vector2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2_divide :: proc {
    vector2_divide_int,
    vector2_divide_f64,
    vector2_divide_vector2,
}
vector2_less_vector2 :: proc "contextless" (self: Vector2, other: Vector2) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less, .Vector2, .Vector2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2_less :: proc {
    vector2_less_vector2,
}
vector2_less_equal_vector2 :: proc "contextless" (self: Vector2, other: Vector2) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less_Equal, .Vector2, .Vector2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2_less_equal :: proc {
    vector2_less_equal_vector2,
}
vector2_greater_vector2 :: proc "contextless" (self: Vector2, other: Vector2) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater, .Vector2, .Vector2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2_greater :: proc {
    vector2_greater_vector2,
}
vector2_greater_equal_vector2 :: proc "contextless" (self: Vector2, other: Vector2) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater_Equal, .Vector2, .Vector2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2_greater_equal :: proc {
    vector2_greater_equal_vector2,
}
vector2_add_vector2 :: proc "contextless" (self: Vector2, other: Vector2) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .Vector2, .Vector2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2_add :: proc {
    vector2_add_vector2,
}
vector2_subtract_vector2 :: proc "contextless" (self: Vector2, other: Vector2) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Subtract, .Vector2, .Vector2)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2_subtract :: proc {
    vector2_subtract_vector2,
}
vector2_in_dictionary :: proc "contextless" (self: Vector2, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector2, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2_in_array :: proc "contextless" (self: Vector2, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector2, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector2_in_packed_vector2_array :: proc "contextless" (self: Vector2, other: Packed_Vector2_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector2, .Packed_Vector2_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector2_in :: proc {
    vector2_in_dictionary,
    vector2_in_array,
    vector2_in_packed_vector2_array,
}

