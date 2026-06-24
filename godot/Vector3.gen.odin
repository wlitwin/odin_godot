package godot

import __bindgen_gde "godot:gdext"
Vector3_Vector3_Axis :: enum int {
    Axis_X = 0,
    Axis_Y = 1,
    Axis_Z = 2,
}





// members

vector3_octahedron_decode :: proc "contextless" (
    uv_: Vector2,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("octahedron_decode", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 3991820552)
    }
    uv_ := uv_
    args := []__bindgen_gde.TypePtr {
        &uv_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}

vector3_min_axis_index :: proc "contextless" (
    self: ^Vector3,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("min_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_max_axis_index :: proc "contextless" (
    self: ^Vector3,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("max_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_angle_to :: proc "contextless" (
    self: ^Vector3,
    to_: Vector3,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("angle_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1047977935)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_signed_angle_to :: proc "contextless" (
    self: ^Vector3,
    to_: Vector3,
    axis_: Vector3,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("signed_angle_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2781412522)
    }
    to_ := to_
    axis_ := axis_
    args := []__bindgen_gde.TypePtr {
        &to_,
        &axis_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_direction_to :: proc "contextless" (
    self: ^Vector3,
    to_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("direction_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2923479887)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_distance_to :: proc "contextless" (
    self: ^Vector3,
    to_: Vector3,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("distance_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1047977935)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_distance_squared_to :: proc "contextless" (
    self: ^Vector3,
    to_: Vector3,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("distance_squared_to", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1047977935)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_length :: proc "contextless" (
    self: ^Vector3,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_length_squared :: proc "contextless" (
    self: ^Vector3,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("length_squared", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_limit_length :: proc "contextless" (
    self: ^Vector3,
    length_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("limit_length", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 514930144)
    }
    length_ := length_
    args := []__bindgen_gde.TypePtr {
        &length_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_normalized :: proc "contextless" (
    self: ^Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("normalized", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1776574132)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_is_normalized :: proc "contextless" (
    self: ^Vector3,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_normalized", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_is_equal_approx :: proc "contextless" (
    self: ^Vector3,
    to_: Vector3,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_equal_approx", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1749054343)
    }
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &to_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_is_zero_approx :: proc "contextless" (
    self: ^Vector3,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_zero_approx", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_is_finite :: proc "contextless" (
    self: ^Vector3,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_finite", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_inverse :: proc "contextless" (
    self: ^Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("inverse", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1776574132)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_clamp :: proc "contextless" (
    self: ^Vector3,
    min_: Vector3,
    max_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clamp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 4145107892)
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
vector3_clampf :: proc "contextless" (
    self: ^Vector3,
    min_: f64,
    max_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clampf", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2329594628)
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
vector3_snapped :: proc "contextless" (
    self: ^Vector3,
    step_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("snapped", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2923479887)
    }
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &step_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_snappedf :: proc "contextless" (
    self: ^Vector3,
    step_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("snappedf", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 514930144)
    }
    step_ := step_
    args := []__bindgen_gde.TypePtr {
        &step_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_rotated :: proc "contextless" (
    self: ^Vector3,
    axis_: Vector3,
    angle_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotated", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1682608829)
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
vector3_lerp :: proc "contextless" (
    self: ^Vector3,
    to_: Vector3,
    weight_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("lerp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1682608829)
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
vector3_slerp :: proc "contextless" (
    self: ^Vector3,
    to_: Vector3,
    weight_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("slerp", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1682608829)
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
vector3_cubic_interpolate :: proc "contextless" (
    self: ^Vector3,
    b_: Vector3,
    pre_a_: Vector3,
    post_b_: Vector3,
    weight_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cubic_interpolate", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2597922253)
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
vector3_cubic_interpolate_in_time :: proc "contextless" (
    self: ^Vector3,
    b_: Vector3,
    pre_a_: Vector3,
    post_b_: Vector3,
    weight_: f64,
    b_t_: f64,
    pre_a_t_: f64,
    post_b_t_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cubic_interpolate_in_time", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 3256682901)
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
vector3_bezier_interpolate :: proc "contextless" (
    self: ^Vector3,
    control_1_: Vector3,
    control_2_: Vector3,
    end_: Vector3,
    t_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bezier_interpolate", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2597922253)
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
vector3_bezier_derivative :: proc "contextless" (
    self: ^Vector3,
    control_1_: Vector3,
    control_2_: Vector3,
    end_: Vector3,
    t_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bezier_derivative", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2597922253)
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
vector3_move_toward :: proc "contextless" (
    self: ^Vector3,
    to_: Vector3,
    delta_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_toward", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1682608829)
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
vector3_dot :: proc "contextless" (
    self: ^Vector3,
    with_: Vector3,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("dot", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1047977935)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_cross :: proc "contextless" (
    self: ^Vector3,
    with_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cross", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2923479887)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_outer :: proc "contextless" (
    self: ^Vector3,
    with_: Vector3,
) -> (ret: Basis) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("outer", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 3934786792)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_abs :: proc "contextless" (
    self: ^Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("abs", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1776574132)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_floor :: proc "contextless" (
    self: ^Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("floor", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1776574132)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_ceil :: proc "contextless" (
    self: ^Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ceil", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1776574132)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_round :: proc "contextless" (
    self: ^Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("round", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1776574132)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_posmod :: proc "contextless" (
    self: ^Vector3,
    mod_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("posmod", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 514930144)
    }
    mod_ := mod_
    args := []__bindgen_gde.TypePtr {
        &mod_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_posmodv :: proc "contextless" (
    self: ^Vector3,
    modv_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("posmodv", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2923479887)
    }
    modv_ := modv_
    args := []__bindgen_gde.TypePtr {
        &modv_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_project :: proc "contextless" (
    self: ^Vector3,
    b_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("project", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2923479887)
    }
    b_ := b_
    args := []__bindgen_gde.TypePtr {
        &b_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_slide :: proc "contextless" (
    self: ^Vector3,
    n_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("slide", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2923479887)
    }
    n_ := n_
    args := []__bindgen_gde.TypePtr {
        &n_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_bounce :: proc "contextless" (
    self: ^Vector3,
    n_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bounce", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2923479887)
    }
    n_ := n_
    args := []__bindgen_gde.TypePtr {
        &n_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_reflect :: proc "contextless" (
    self: ^Vector3,
    n_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reflect", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2923479887)
    }
    n_ := n_
    args := []__bindgen_gde.TypePtr {
        &n_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_sign :: proc "contextless" (
    self: ^Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sign", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 1776574132)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_octahedron_encode :: proc "contextless" (
    self: ^Vector3,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("octahedron_encode", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2428350749)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_min :: proc "contextless" (
    self: ^Vector3,
    with_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("min", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2923479887)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_minf :: proc "contextless" (
    self: ^Vector3,
    with_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("minf", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 514930144)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_max :: proc "contextless" (
    self: ^Vector3,
    with_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("max", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 2923479887)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
vector3_maxf :: proc "contextless" (
    self: ^Vector3,
    with_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("maxf", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Vector3, &_gde_name, 514930144)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

vector3_equal_variant :: proc "contextless" (self: Vector3, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Vector3, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3_equal_vector3 :: proc "contextless" (self: Vector3, other: Vector3) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Vector3, .Vector3)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3_equal :: proc {
    vector3_equal_variant,
    vector3_equal_vector3,
}
vector3_not_equal_variant :: proc "contextless" (self: Vector3, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Vector3, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3_not_equal_vector3 :: proc "contextless" (self: Vector3, other: Vector3) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Vector3, .Vector3)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3_not_equal :: proc {
    vector3_not_equal_variant,
    vector3_not_equal_vector3,
}
vector3_negate_default :: proc "contextless" (self: Vector3) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Negate, .Vector3, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector3_negate :: proc {
    vector3_negate_default,
}
vector3_positive_default :: proc "contextless" (self: Vector3) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Positive, .Vector3, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector3_positive :: proc {
    vector3_positive_default,
}
vector3_not_default :: proc "contextless" (self: Vector3) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Vector3, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

vector3_not :: proc {
    vector3_not_default,
}
vector3_multiply_int :: proc "contextless" (self: Vector3, other: Int) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector3, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3_multiply_f64 :: proc "contextless" (self: Vector3, other: f64) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector3, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3_multiply_vector3 :: proc "contextless" (self: Vector3, other: Vector3) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector3, .Vector3)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3_multiply_quaternion :: proc "contextless" (self: Vector3, other: Quaternion) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector3, .Quaternion)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3_multiply_basis :: proc "contextless" (self: Vector3, other: Basis) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector3, .Basis)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3_multiply_transform3d :: proc "contextless" (self: Vector3, other: Transform3d) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Vector3, .Transform3d)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3_multiply :: proc {
    vector3_multiply_int,
    vector3_multiply_f64,
    vector3_multiply_vector3,
    vector3_multiply_quaternion,
    vector3_multiply_basis,
    vector3_multiply_transform3d,
}
vector3_divide_int :: proc "contextless" (self: Vector3, other: Int) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector3, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3_divide_f64 :: proc "contextless" (self: Vector3, other: f64) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector3, .Int)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3_divide_vector3 :: proc "contextless" (self: Vector3, other: Vector3) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Divide, .Vector3, .Vector3)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3_divide :: proc {
    vector3_divide_int,
    vector3_divide_f64,
    vector3_divide_vector3,
}
vector3_less_vector3 :: proc "contextless" (self: Vector3, other: Vector3) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less, .Vector3, .Vector3)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3_less :: proc {
    vector3_less_vector3,
}
vector3_less_equal_vector3 :: proc "contextless" (self: Vector3, other: Vector3) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Less_Equal, .Vector3, .Vector3)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3_less_equal :: proc {
    vector3_less_equal_vector3,
}
vector3_greater_vector3 :: proc "contextless" (self: Vector3, other: Vector3) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater, .Vector3, .Vector3)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3_greater :: proc {
    vector3_greater_vector3,
}
vector3_greater_equal_vector3 :: proc "contextless" (self: Vector3, other: Vector3) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Greater_Equal, .Vector3, .Vector3)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3_greater_equal :: proc {
    vector3_greater_equal_vector3,
}
vector3_add_vector3 :: proc "contextless" (self: Vector3, other: Vector3) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Add, .Vector3, .Vector3)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3_add :: proc {
    vector3_add_vector3,
}
vector3_subtract_vector3 :: proc "contextless" (self: Vector3, other: Vector3) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Subtract, .Vector3, .Vector3)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3_subtract :: proc {
    vector3_subtract_vector3,
}
vector3_in_dictionary :: proc "contextless" (self: Vector3, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector3, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3_in_array :: proc "contextless" (self: Vector3, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector3, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
vector3_in_packed_vector3_array :: proc "contextless" (self: Vector3, other: Packed_Vector3_Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Vector3, .Packed_Vector3_Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

vector3_in :: proc {
    vector3_in_dictionary,
    vector3_in_array,
    vector3_in_packed_vector3_array,
}

