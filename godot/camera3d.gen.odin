package godot

import __bindgen_gde "godot:gdext"

Camera3d_Constants :: enum {
}
Camera3d_Projection_Type :: enum int {
    Projection_Perspective = 0,
    Projection_Orthogonal = 1,
    Projection_Frustum = 2,
}
Camera3d_Keep_Aspect :: enum int {
    Keep_Width = 0,
    Keep_Height = 1,
}
Camera3d_Doppler_Tracking :: enum int {
    Doppler_Tracking_Disabled = 0,
    Doppler_Tracking_Idle_Step = 1,
    Doppler_Tracking_Physics_Step = 2,
}



camera3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

camera3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_camera3d :: proc "contextless" () -> Camera3d {
    return cast(Camera3d)__bindgen_gde.classdb_construct_object(camera3d_name_ref())
}

// methods
//
// Method binds are resolved LAZILY on first call (the `@(static) __ptr` guard),
// NOT eagerly in `_init`. Many engine classes (Node, Control, the *Server
// singletons, ...) are only registered with ClassDB at later initialization
// levels (Servers/Scene), while `godot.init()` runs at the extension entry
// (Core level). Eagerly fetching every bind there returned null for ~91% of
// methods (a 16k-line `mb is null` flood). Resolving on first call defers the
// fetch to a point where the owning class is registered, mirroring how the
// builtin/variant methods already work. A genuinely unresolvable bind stays
// nil and the following ptrcall surfaces it at the call site.
//
// VARARG methods (`is_vararg` in extension_api.json) cannot use ptrcall — Godot
// aborts with "ptrcall can't be used with vararg methods". They instead go
// through `object_method_bind_call`: the fixed declared args are marshalled to
// Variants, the variadic `extra: ..Variant` are appended, and the returned
// Variant is converted to the declared return type (Variant passed through,
// `Error`/ints via variant_to_int, void ignored).

camera3d_project_ray_normal :: proc "contextless" (
    self: Camera3d,
    screen_point_: Vector2,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("project_ray_normal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1718073306)
    }
    self := self
    screen_point_ := screen_point_
    args := []__bindgen_gde.TypePtr {
        &screen_point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_project_local_ray_normal :: proc "contextless" (
    self: Camera3d,
    screen_point_: Vector2,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("project_local_ray_normal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1718073306)
    }
    self := self
    screen_point_ := screen_point_
    args := []__bindgen_gde.TypePtr {
        &screen_point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_project_ray_origin :: proc "contextless" (
    self: Camera3d,
    screen_point_: Vector2,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("project_ray_origin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1718073306)
    }
    self := self
    screen_point_ := screen_point_
    args := []__bindgen_gde.TypePtr {
        &screen_point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_unproject_position :: proc "contextless" (
    self: Camera3d,
    world_point_: Vector3,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("unproject_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3758901831)
    }
    self := self
    world_point_ := world_point_
    args := []__bindgen_gde.TypePtr {
        &world_point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_is_position_behind :: proc "contextless" (
    self: Camera3d,
    world_point_: Vector3,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_position_behind", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3108956480)
    }
    self := self
    world_point_ := world_point_
    args := []__bindgen_gde.TypePtr {
        &world_point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_project_position :: proc "contextless" (
    self: Camera3d,
    screen_point_: Vector2,
    z_depth_: f64,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("project_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2171975744)
    }
    self := self
    screen_point_ := screen_point_
    z_depth_ := z_depth_
    args := []__bindgen_gde.TypePtr {
        &screen_point_,
        &z_depth_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_set_perspective :: proc "contextless" (
    self: Camera3d,
    fov_: f64,
    z_near_: f64,
    z_far_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_perspective", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2385087082)
    }
    self := self
    fov_ := fov_
    z_near_ := z_near_
    z_far_ := z_far_
    args := []__bindgen_gde.TypePtr {
        &fov_,
        &z_near_,
        &z_far_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_set_orthogonal :: proc "contextless" (
    self: Camera3d,
    size_: f64,
    z_near_: f64,
    z_far_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_orthogonal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2385087082)
    }
    self := self
    size_ := size_
    z_near_ := z_near_
    z_far_ := z_far_
    args := []__bindgen_gde.TypePtr {
        &size_,
        &z_near_,
        &z_far_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_set_frustum :: proc "contextless" (
    self: Camera3d,
    size_: f64,
    offset_: Vector2,
    z_near_: f64,
    z_far_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_frustum", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 354890663)
    }
    self := self
    size_ := size_
    offset_ := offset_
    z_near_ := z_near_
    z_far_ := z_far_
    args := []__bindgen_gde.TypePtr {
        &size_,
        &offset_,
        &z_near_,
        &z_far_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_make_current :: proc "contextless" (
    self: Camera3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_current", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_clear_current :: proc "contextless" (
    self: Camera3d,
    enable_next_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_current", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3216645846)
    }
    self := self
    enable_next_ := enable_next_
    args := []__bindgen_gde.TypePtr {
        &enable_next_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_set_current :: proc "contextless" (
    self: Camera3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_current", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_is_current :: proc "contextless" (
    self: Camera3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_current", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_get_camera_transform :: proc "contextless" (
    self: Camera3d,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_camera_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3229777777)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_get_camera_projection :: proc "contextless" (
    self: Camera3d,
) -> (ret: Projection) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_camera_projection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2910717950)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_get_fov :: proc "contextless" (
    self: Camera3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fov", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_get_frustum_offset :: proc "contextless" (
    self: Camera3d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_frustum_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_get_size :: proc "contextless" (
    self: Camera3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_get_far :: proc "contextless" (
    self: Camera3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_far", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_get_near :: proc "contextless" (
    self: Camera3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_near", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_set_fov :: proc "contextless" (
    self: Camera3d,
    fov_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fov", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    fov_ := fov_
    args := []__bindgen_gde.TypePtr {
        &fov_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_set_frustum_offset :: proc "contextless" (
    self: Camera3d,
    offset_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_frustum_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_set_size :: proc "contextless" (
    self: Camera3d,
    size_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_set_far :: proc "contextless" (
    self: Camera3d,
    far_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_far", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    far_ := far_
    args := []__bindgen_gde.TypePtr {
        &far_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_set_near :: proc "contextless" (
    self: Camera3d,
    near_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_near", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    near_ := near_
    args := []__bindgen_gde.TypePtr {
        &near_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_get_projection :: proc "contextless" (
    self: Camera3d,
) -> (ret: Camera3d_Projection_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_projection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2624185235)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_set_projection :: proc "contextless" (
    self: Camera3d,
    mode_: Camera3d_Projection_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_projection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4218540108)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_set_h_offset :: proc "contextless" (
    self: Camera3d,
    offset_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_h_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_get_h_offset :: proc "contextless" (
    self: Camera3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_h_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_set_v_offset :: proc "contextless" (
    self: Camera3d,
    offset_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_v_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_get_v_offset :: proc "contextless" (
    self: Camera3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_v_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_set_cull_mask :: proc "contextless" (
    self: Camera3d,
    mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cull_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    mask_ := mask_
    args := []__bindgen_gde.TypePtr {
        &mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_get_cull_mask :: proc "contextless" (
    self: Camera3d,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cull_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_set_environment :: proc "contextless" (
    self: Camera3d,
    env_: Environment,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_environment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4143518816)
    }
    self := self
    env_ := env_
    args := []__bindgen_gde.TypePtr {
        &env_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_get_environment :: proc "contextless" (
    self: Camera3d,
) -> (ret: Environment) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_environment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3082064660)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_set_attributes :: proc "contextless" (
    self: Camera3d,
    env_: Camera_Attributes,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_attributes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2817810567)
    }
    self := self
    env_ := env_
    args := []__bindgen_gde.TypePtr {
        &env_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_get_attributes :: proc "contextless" (
    self: Camera3d,
) -> (ret: Camera_Attributes) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_attributes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3921283215)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_set_compositor :: proc "contextless" (
    self: Camera3d,
    compositor_: Compositor,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_compositor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1586754307)
    }
    self := self
    compositor_ := compositor_
    args := []__bindgen_gde.TypePtr {
        &compositor_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_get_compositor :: proc "contextless" (
    self: Camera3d,
) -> (ret: Compositor) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_compositor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3647707413)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_set_keep_aspect_mode :: proc "contextless" (
    self: Camera3d,
    mode_: Camera3d_Keep_Aspect,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_keep_aspect_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740651252)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_get_keep_aspect_mode :: proc "contextless" (
    self: Camera3d,
) -> (ret: Camera3d_Keep_Aspect) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_keep_aspect_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2790278316)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_set_doppler_tracking :: proc "contextless" (
    self: Camera3d,
    mode_: Camera3d_Doppler_Tracking,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_doppler_tracking", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3109431270)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_get_doppler_tracking :: proc "contextless" (
    self: Camera3d,
) -> (ret: Camera3d_Doppler_Tracking) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_doppler_tracking", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1584483649)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_get_frustum :: proc "contextless" (
    self: Camera3d,
) -> (ret: Typed_Array(Plane)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_frustum", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_is_position_in_frustum :: proc "contextless" (
    self: Camera3d,
    world_point_: Vector3,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_position_in_frustum", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3108956480)
    }
    self := self
    world_point_ := world_point_
    args := []__bindgen_gde.TypePtr {
        &world_point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_get_camera_rid :: proc "contextless" (
    self: Camera3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_camera_rid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2944877500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_get_pyramid_shape_rid :: proc "contextless" (
    self: Camera3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pyramid_shape_rid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera3d_set_cull_mask_value :: proc "contextless" (
    self: Camera3d,
    layer_number_: Int,
    value_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cull_mask_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    layer_number_ := layer_number_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &layer_number_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera3d_get_cull_mask_value :: proc "contextless" (
    self: Camera3d,
    layer_number_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cull_mask_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    layer_number_ := layer_number_
    args := []__bindgen_gde.TypePtr {
        &layer_number_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
camera3d_get_keep_aspect :: proc "contextless" (self: Camera3d) -> Camera3d_Keep_Aspect {
    return camera3d_get_keep_aspect_mode(self)
}
camera3d_set_keep_aspect :: proc "contextless" (self: Camera3d, value: Camera3d_Keep_Aspect) {
    camera3d_set_keep_aspect_mode(self, value)
}
camera3d_get_current :: proc "contextless" (self: Camera3d) -> Bool {
    return camera3d_is_current(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
camera3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Camera3D", true)
}

@(private = "file")
__class_name: String_Name