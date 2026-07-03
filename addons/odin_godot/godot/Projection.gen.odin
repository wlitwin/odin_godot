package godot

import __bindgen_gde "godot:gdext"
Projection_Projection_Planes :: enum int {
    Plane_Near = 0,
    Plane_Far = 1,
    Plane_Left = 2,
    Plane_Top = 3,
    Plane_Right = 4,
    Plane_Bottom = 5,
}





// members

projection_create_depth_correction :: proc "contextless" (
    flip_y_: Bool,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_depth_correction", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 1228516048)
    }
    flip_y_ := flip_y_
    args := []__bindgen_gde.TypePtr {
        &flip_y_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
projection_create_light_atlas_rect :: proc "contextless" (
    rect_: Rect2,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_light_atlas_rect", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 2654950662)
    }
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &rect_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
projection_create_perspective :: proc "contextless" (
    fovy_: f64,
    aspect_: f64,
    z_near_: f64,
    z_far_: f64,
    flip_fov_: Bool,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_perspective", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 390915442)
    }
    fovy_ := fovy_
    aspect_ := aspect_
    z_near_ := z_near_
    z_far_ := z_far_
    flip_fov_ := flip_fov_
    args := []__bindgen_gde.TypePtr {
        &fovy_,
        &aspect_,
        &z_near_,
        &z_far_,
        &flip_fov_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
projection_create_perspective_hmd :: proc "contextless" (
    fovy_: f64,
    aspect_: f64,
    z_near_: f64,
    z_far_: f64,
    flip_fov_: Bool,
    eye_: Int,
    intraocular_dist_: f64,
    convergence_dist_: f64,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_perspective_hmd", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 2857674800)
    }
    fovy_ := fovy_
    aspect_ := aspect_
    z_near_ := z_near_
    z_far_ := z_far_
    flip_fov_ := flip_fov_
    eye_ := eye_
    intraocular_dist_ := intraocular_dist_
    convergence_dist_ := convergence_dist_
    args := []__bindgen_gde.TypePtr {
        &fovy_,
        &aspect_,
        &z_near_,
        &z_far_,
        &flip_fov_,
        &eye_,
        &intraocular_dist_,
        &convergence_dist_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
projection_create_for_hmd :: proc "contextless" (
    eye_: Int,
    aspect_: f64,
    intraocular_dist_: f64,
    display_width_: f64,
    display_to_lens_: f64,
    oversample_: f64,
    z_near_: f64,
    z_far_: f64,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_for_hmd", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 4184144994)
    }
    eye_ := eye_
    aspect_ := aspect_
    intraocular_dist_ := intraocular_dist_
    display_width_ := display_width_
    display_to_lens_ := display_to_lens_
    oversample_ := oversample_
    z_near_ := z_near_
    z_far_ := z_far_
    args := []__bindgen_gde.TypePtr {
        &eye_,
        &aspect_,
        &intraocular_dist_,
        &display_width_,
        &display_to_lens_,
        &oversample_,
        &z_near_,
        &z_far_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
projection_create_orthogonal :: proc "contextless" (
    left_: f64,
    right_: f64,
    bottom_: f64,
    top_: f64,
    z_near_: f64,
    z_far_: f64,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_orthogonal", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 3707929169)
    }
    left_ := left_
    right_ := right_
    bottom_ := bottom_
    top_ := top_
    z_near_ := z_near_
    z_far_ := z_far_
    args := []__bindgen_gde.TypePtr {
        &left_,
        &right_,
        &bottom_,
        &top_,
        &z_near_,
        &z_far_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
projection_create_orthogonal_aspect :: proc "contextless" (
    size_: f64,
    aspect_: f64,
    z_near_: f64,
    z_far_: f64,
    flip_fov_: Bool,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_orthogonal_aspect", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 390915442)
    }
    size_ := size_
    aspect_ := aspect_
    z_near_ := z_near_
    z_far_ := z_far_
    flip_fov_ := flip_fov_
    args := []__bindgen_gde.TypePtr {
        &size_,
        &aspect_,
        &z_near_,
        &z_far_,
        &flip_fov_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
projection_create_frustum :: proc "contextless" (
    left_: f64,
    right_: f64,
    bottom_: f64,
    top_: f64,
    z_near_: f64,
    z_far_: f64,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_frustum", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 3707929169)
    }
    left_ := left_
    right_ := right_
    bottom_ := bottom_
    top_ := top_
    z_near_ := z_near_
    z_far_ := z_far_
    args := []__bindgen_gde.TypePtr {
        &left_,
        &right_,
        &bottom_,
        &top_,
        &z_near_,
        &z_far_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
projection_create_frustum_aspect :: proc "contextless" (
    size_: f64,
    aspect_: f64,
    offset_: Vector2,
    z_near_: f64,
    z_far_: f64,
    flip_fov_: Bool,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_frustum_aspect", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 1535076251)
    }
    size_ := size_
    aspect_ := aspect_
    offset_ := offset_
    z_near_ := z_near_
    z_far_ := z_far_
    flip_fov_ := flip_fov_
    args := []__bindgen_gde.TypePtr {
        &size_,
        &aspect_,
        &offset_,
        &z_near_,
        &z_far_,
        &flip_fov_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
projection_create_fit_aabb :: proc "contextless" (
    aabb_: Aabb,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_fit_aabb", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 2264694907)
    }
    aabb_ := aabb_
    args := []__bindgen_gde.TypePtr {
        &aabb_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}
projection_get_fovy :: proc "contextless" (
    fovx_: f64,
    aspect_: f64,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fovy", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 3514207532)
    }
    fovx_ := fovx_
    aspect_ := aspect_
    args := []__bindgen_gde.TypePtr {
        &fovx_,
        &aspect_,
    }
    __ptr(nil, raw_data(args), &ret, len(args))
    return
}

projection_determinant :: proc "contextless" (
    self: ^Projection,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("determinant", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_perspective_znear_adjusted :: proc "contextless" (
    self: ^Projection,
    new_znear_: f64,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("perspective_znear_adjusted", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 3584785443)
    }
    new_znear_ := new_znear_
    args := []__bindgen_gde.TypePtr {
        &new_znear_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_get_projection_plane :: proc "contextless" (
    self: ^Projection,
    plane_: Int,
) -> (ret: Plane) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_projection_plane", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 1551184160)
    }
    plane_ := plane_
    args := []__bindgen_gde.TypePtr {
        &plane_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_flipped_y :: proc "contextless" (
    self: ^Projection,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("flipped_y", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 4212530932)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_jitter_offseted :: proc "contextless" (
    self: ^Projection,
    offset_: Vector2,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("jitter_offseted", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 2448438599)
    }
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_get_z_far :: proc "contextless" (
    self: ^Projection,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_z_far", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_get_z_near :: proc "contextless" (
    self: ^Projection,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_z_near", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_get_aspect :: proc "contextless" (
    self: ^Projection,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_aspect", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_get_fov :: proc "contextless" (
    self: ^Projection,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fov", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_is_orthogonal :: proc "contextless" (
    self: ^Projection,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_orthogonal", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 3918633141)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_get_viewport_half_extents :: proc "contextless" (
    self: ^Projection,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_viewport_half_extents", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 2428350749)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_get_far_plane_half_extents :: proc "contextless" (
    self: ^Projection,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_far_plane_half_extents", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 2428350749)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_inverse :: proc "contextless" (
    self: ^Projection,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("inverse", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 4212530932)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_get_pixels_per_meter :: proc "contextless" (
    self: ^Projection,
    for_pixel_width_: Int,
) -> (ret: Int) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pixels_per_meter", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 4103005248)
    }
    for_pixel_width_ := for_pixel_width_
    args := []__bindgen_gde.TypePtr {
        &for_pixel_width_,
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}
projection_get_lod_multiplier :: proc "contextless" (
    self: ^Projection,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.PtrBuiltInMethod
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_lod_multiplier", true)
        __ptr = __bindgen_gde.variant_get_ptr_builtin_method(.Projection, &_gde_name, 466405837)
    }
    args := []__bindgen_gde.TypePtr {
    }
    __ptr(self, raw_data(args), &ret, len(args))
    return
}

projection_equal_variant :: proc "contextless" (self: Projection, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Projection, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
projection_equal_projection :: proc "contextless" (self: Projection, other: Projection) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Equal, .Projection, .Projection)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

projection_equal :: proc {
    projection_equal_variant,
    projection_equal_projection,
}
projection_not_equal_variant :: proc "contextless" (self: Projection, other: Variant) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Projection, .Nil)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
projection_not_equal_projection :: proc "contextless" (self: Projection, other: Projection) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not_Equal, .Projection, .Projection)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

projection_not_equal :: proc {
    projection_not_equal_variant,
    projection_not_equal_projection,
}
projection_not_default :: proc "contextless" (self: Projection) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Not, .Projection, .Nil)
    }

    self := self
    __ptr(&self, nil, &ret)
    return
}

projection_not :: proc {
    projection_not_default,
}
projection_multiply_vector4 :: proc "contextless" (self: Projection, other: Vector4) -> (ret: Vector4) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Projection, .Vector4)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
projection_multiply_projection :: proc "contextless" (self: Projection, other: Projection) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.Multiply, .Projection, .Projection)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

projection_multiply :: proc {
    projection_multiply_vector4,
    projection_multiply_projection,
}
projection_in_dictionary :: proc "contextless" (self: Projection, other: Dictionary) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Projection, .Dictionary)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}
projection_in_array :: proc "contextless" (self: Projection, other: Array) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.PtrOperatorEvaluator
    if __ptr == nil {
        __ptr = __bindgen_gde.variant_get_ptr_operator_evaluator(.In, .Projection, .Array)
    }

    self := self
    other := other
    __ptr(&self, &other, &ret)
    return
}

projection_in :: proc {
    projection_in_dictionary,
    projection_in_array,
}

