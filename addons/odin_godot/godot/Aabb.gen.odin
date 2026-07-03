package godot

import __bindgen_gde "godot:gdext"





// members


aabb_abs :: proc "contextless" (
    self: ^Aabb,
) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("abs", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 1576868580)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_get_center :: proc "contextless" (
    self: ^Aabb,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 1776574132)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_get_volume :: proc "contextless" (
    self: ^Aabb,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_volume", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_has_volume :: proc "contextless" (
    self: ^Aabb,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_volume", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_has_surface :: proc "contextless" (
    self: ^Aabb,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_surface", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_has_point :: proc "contextless" (
    self: ^Aabb,
    point_: Vector3,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_point", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 1749054343)
    }
    point_ := point_
    args := []__bindgen_gde.TypePtr {
        &point_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_is_equal_approx :: proc "contextless" (
    self: ^Aabb,
    aabb_: Aabb,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_equal_approx", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 299946684)
    }
    aabb_ := aabb_
    args := []__bindgen_gde.TypePtr {
        &aabb_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_is_finite :: proc "contextless" (
    self: ^Aabb,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_finite", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_intersects :: proc "contextless" (
    self: ^Aabb,
    with_: Aabb,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersects", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 299946684)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_encloses :: proc "contextless" (
    self: ^Aabb,
    with_: Aabb,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("encloses", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 299946684)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_intersects_plane :: proc "contextless" (
    self: ^Aabb,
    plane_: Plane,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersects_plane", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 1150170233)
    }
    plane_ := plane_
    args := []__bindgen_gde.TypePtr {
        &plane_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_intersection :: proc "contextless" (
    self: ^Aabb,
    with_: Aabb,
) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersection", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 1271470306)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_merge :: proc "contextless" (
    self: ^Aabb,
    with_: Aabb,
) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("merge", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 1271470306)
    }
    with_ := with_
    args := []__bindgen_gde.TypePtr {
        &with_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_expand :: proc "contextless" (
    self: ^Aabb,
    to_point_: Vector3,
) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("expand", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 2851643018)
    }
    to_point_ := to_point_
    args := []__bindgen_gde.TypePtr {
        &to_point_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_grow :: proc "contextless" (
    self: ^Aabb,
    by_: f64,
) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("grow", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 239217291)
    }
    by_ := by_
    args := []__bindgen_gde.TypePtr {
        &by_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_get_support :: proc "contextless" (
    self: ^Aabb,
    direction_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_support", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 2923479887)
    }
    direction_ := direction_
    args := []__bindgen_gde.TypePtr {
        &direction_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_get_longest_axis :: proc "contextless" (
    self: ^Aabb,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_longest_axis", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 1776574132)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_get_longest_axis_index :: proc "contextless" (
    self: ^Aabb,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_longest_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_get_longest_axis_size :: proc "contextless" (
    self: ^Aabb,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_longest_axis_size", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_get_shortest_axis :: proc "contextless" (
    self: ^Aabb,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shortest_axis", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 1776574132)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_get_shortest_axis_index :: proc "contextless" (
    self: ^Aabb,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shortest_axis_index", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 3173160232)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_get_shortest_axis_size :: proc "contextless" (
    self: ^Aabb,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shortest_axis_size", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_get_endpoint :: proc "contextless" (
    self: ^Aabb,
    idx_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_endpoint", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 1394941017)
    }
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
aabb_intersects_segment :: proc "contextless" (
    self: ^Aabb,
    from_: Vector3,
    to_: Vector3,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersects_segment", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 2048133369)
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
aabb_intersects_ray :: proc "contextless" (
    self: ^Aabb,
    from_: Vector3,
    dir_: Vector3,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersects_ray", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Aabb, &_gde_name, 2048133369)
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

aabb_equal_variant :: proc "contextless" (self: Aabb, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Aabb, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
aabb_equal_aabb :: proc "contextless" (self: Aabb, other: Aabb) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Aabb, .Aabb)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

aabb_equal :: proc {
    aabb_equal_variant,
    aabb_equal_aabb,
}
aabb_not_equal_variant :: proc "contextless" (self: Aabb, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Aabb, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
aabb_not_equal_aabb :: proc "contextless" (self: Aabb, other: Aabb) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Aabb, .Aabb)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

aabb_not_equal :: proc {
    aabb_not_equal_variant,
    aabb_not_equal_aabb,
}
aabb_not_default :: proc "contextless" (self: Aabb) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Aabb, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

aabb_not :: proc {
    aabb_not_default,
}
aabb_multiply_transform3d :: proc "contextless" (self: Aabb, other: Transform3d) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Aabb, .Transform3d)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

aabb_multiply :: proc {
    aabb_multiply_transform3d,
}
aabb_in_dictionary :: proc "contextless" (self: Aabb, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Aabb, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
aabb_in_array :: proc "contextless" (self: Aabb, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Aabb, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

aabb_in :: proc {
    aabb_in_dictionary,
    aabb_in_array,
}

