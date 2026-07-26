package godot

import __bindgen_gde "godot:gdext"

Cpu_Particles3d_Constants :: enum {
}
Cpu_Particles3d_Draw_Order :: enum int {
    Draw_Order_Index = 0,
    Draw_Order_Lifetime = 1,
    Draw_Order_View_Depth = 2,
}
Cpu_Particles3d_Parameter :: enum int {
    Param_Initial_Linear_Velocity = 0,
    Param_Angular_Velocity = 1,
    Param_Orbit_Velocity = 2,
    Param_Linear_Accel = 3,
    Param_Radial_Accel = 4,
    Param_Tangential_Accel = 5,
    Param_Damping = 6,
    Param_Angle = 7,
    Param_Scale = 8,
    Param_Hue_Variation = 9,
    Param_Anim_Speed = 10,
    Param_Anim_Offset = 11,
    Param_Max = 12,
}
Cpu_Particles3d_Particle_Flags :: enum int {
    Particle_Flag_Align_Y_To_Velocity = 0,
    Particle_Flag_Rotate_Y = 1,
    Particle_Flag_Disable_Z = 2,
    Particle_Flag_Max = 3,
}
Cpu_Particles3d_Emission_Shape :: enum int {
    Emission_Shape_Point = 0,
    Emission_Shape_Sphere = 1,
    Emission_Shape_Sphere_Surface = 2,
    Emission_Shape_Box = 3,
    Emission_Shape_Points = 4,
    Emission_Shape_Directed_Points = 5,
    Emission_Shape_Ring = 6,
    Emission_Shape_Max = 7,
}



cpu_particles3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

cpu_particles3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_cpu_particles3d :: proc "contextless" () -> Cpu_Particles3d {
    return __bindgen_gde.classdb_construct_object(cpu_particles3d_name_ref())
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

cpu_particles3d_set_emitting :: proc "contextless" (
    self: Cpu_Particles3d,
    emitting_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emitting", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    emitting_ := emitting_
    args := []__bindgen_gde.TypePtr {
        &emitting_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_set_amount :: proc "contextless" (
    self: Cpu_Particles3d,
    amount_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_amount", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_set_lifetime :: proc "contextless" (
    self: Cpu_Particles3d,
    secs_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_lifetime", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    secs_ := secs_
    args := []__bindgen_gde.TypePtr {
        &secs_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_set_one_shot :: proc "contextless" (
    self: Cpu_Particles3d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_one_shot", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_set_pre_process_time :: proc "contextless" (
    self: Cpu_Particles3d,
    secs_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_pre_process_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    secs_ := secs_
    args := []__bindgen_gde.TypePtr {
        &secs_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_set_explosiveness_ratio :: proc "contextless" (
    self: Cpu_Particles3d,
    ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_explosiveness_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    ratio_ := ratio_
    args := []__bindgen_gde.TypePtr {
        &ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_set_randomness_ratio :: proc "contextless" (
    self: Cpu_Particles3d,
    ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_randomness_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    ratio_ := ratio_
    args := []__bindgen_gde.TypePtr {
        &ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_set_visibility_aabb :: proc "contextless" (
    self: Cpu_Particles3d,
    aabb_: Aabb,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_aabb", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 259215842)
    }
    self := self
    aabb_ := aabb_
    args := []__bindgen_gde.TypePtr {
        &aabb_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_set_lifetime_randomness :: proc "contextless" (
    self: Cpu_Particles3d,
    random_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_lifetime_randomness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    random_ := random_
    args := []__bindgen_gde.TypePtr {
        &random_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_set_use_local_coordinates :: proc "contextless" (
    self: Cpu_Particles3d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_local_coordinates", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_set_fixed_fps :: proc "contextless" (
    self: Cpu_Particles3d,
    fps_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fixed_fps", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    fps_ := fps_
    args := []__bindgen_gde.TypePtr {
        &fps_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_set_fractional_delta :: proc "contextless" (
    self: Cpu_Particles3d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fractional_delta", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_set_speed_scale :: proc "contextless" (
    self: Cpu_Particles3d,
    scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_speed_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_is_emitting :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_emitting", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_get_amount :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_amount", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_get_lifetime :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_lifetime", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_get_one_shot :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_one_shot", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_get_pre_process_time :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pre_process_time", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_get_explosiveness_ratio :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_explosiveness_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_get_randomness_ratio :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_randomness_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_get_visibility_aabb :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_aabb", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1068685055)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_get_lifetime_randomness :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_lifetime_randomness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_get_use_local_coordinates :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_use_local_coordinates", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_get_fixed_fps :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fixed_fps", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_get_fractional_delta :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fractional_delta", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_get_speed_scale :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_speed_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_draw_order :: proc "contextless" (
    self: Cpu_Particles3d,
    order_: Cpu_Particles3d_Draw_Order,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_order", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1427401774)
    }
    self := self
    order_ := order_
    args := []__bindgen_gde.TypePtr {
        &order_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_draw_order :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Cpu_Particles3d_Draw_Order) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_draw_order", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1321900776)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_mesh :: proc "contextless" (
    self: Cpu_Particles3d,
    mesh_: Mesh,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 194775623)
    }
    self := self
    mesh_ := mesh_
    args := []__bindgen_gde.TypePtr {
        &mesh_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_mesh :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1808005922)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_use_fixed_seed :: proc "contextless" (
    self: Cpu_Particles3d,
    use_fixed_seed_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_fixed_seed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    use_fixed_seed_ := use_fixed_seed_
    args := []__bindgen_gde.TypePtr {
        &use_fixed_seed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_use_fixed_seed :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_use_fixed_seed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_seed :: proc "contextless" (
    self: Cpu_Particles3d,
    seed_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_seed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    seed_ := seed_
    args := []__bindgen_gde.TypePtr {
        &seed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_seed :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_seed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_restart :: proc "contextless" (
    self: Cpu_Particles3d,
    keep_seed_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("restart", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 107499316)
    }
    self := self
    keep_seed_ := keep_seed_
    args := []__bindgen_gde.TypePtr {
        &keep_seed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_request_particles_process :: proc "contextless" (
    self: Cpu_Particles3d,
    process_time_: f64,
    process_time_residual_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("request_particles_process", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 66938510)
    }
    self := self
    process_time_ := process_time_
    process_time_residual_ := process_time_residual_
    args := []__bindgen_gde.TypePtr {
        &process_time_,
        &process_time_residual_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_capture_aabb :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("capture_aabb", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1068685055)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_direction :: proc "contextless" (
    self: Cpu_Particles3d,
    direction_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    direction_ := direction_
    args := []__bindgen_gde.TypePtr {
        &direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_direction :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_spread :: proc "contextless" (
    self: Cpu_Particles3d,
    degrees_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_spread", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    degrees_ := degrees_
    args := []__bindgen_gde.TypePtr {
        &degrees_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_spread :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_spread", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_flatness :: proc "contextless" (
    self: Cpu_Particles3d,
    amount_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flatness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_flatness :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_flatness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_param_min :: proc "contextless" (
    self: Cpu_Particles3d,
    param_: Cpu_Particles3d_Parameter,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 557936109)
    }
    self := self
    param_ := param_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &param_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_param_min :: proc "contextless" (
    self: Cpu_Particles3d,
    param_: Cpu_Particles3d_Parameter,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 597646162)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_param_max :: proc "contextless" (
    self: Cpu_Particles3d,
    param_: Cpu_Particles3d_Parameter,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 557936109)
    }
    self := self
    param_ := param_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &param_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_param_max :: proc "contextless" (
    self: Cpu_Particles3d,
    param_: Cpu_Particles3d_Parameter,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 597646162)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_param_curve :: proc "contextless" (
    self: Cpu_Particles3d,
    param_: Cpu_Particles3d_Parameter,
    curve_: Curve,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param_curve", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4044142537)
    }
    self := self
    param_ := param_
    curve_ := curve_
    args := []__bindgen_gde.TypePtr {
        &param_,
        &curve_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_param_curve :: proc "contextless" (
    self: Cpu_Particles3d,
    param_: Cpu_Particles3d_Parameter,
) -> (ret: Curve) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param_curve", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4132790277)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_color :: proc "contextless" (
    self: Cpu_Particles3d,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_color :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_color_ramp :: proc "contextless" (
    self: Cpu_Particles3d,
    ramp_: Gradient,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_color_ramp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2756054477)
    }
    self := self
    ramp_ := ramp_
    args := []__bindgen_gde.TypePtr {
        &ramp_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_color_ramp :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Gradient) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color_ramp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 132272999)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_color_initial_ramp :: proc "contextless" (
    self: Cpu_Particles3d,
    ramp_: Gradient,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_color_initial_ramp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2756054477)
    }
    self := self
    ramp_ := ramp_
    args := []__bindgen_gde.TypePtr {
        &ramp_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_color_initial_ramp :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Gradient) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color_initial_ramp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 132272999)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_particle_flag :: proc "contextless" (
    self: Cpu_Particles3d,
    particle_flag_: Cpu_Particles3d_Particle_Flags,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_particle_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3515406498)
    }
    self := self
    particle_flag_ := particle_flag_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &particle_flag_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_particle_flag :: proc "contextless" (
    self: Cpu_Particles3d,
    particle_flag_: Cpu_Particles3d_Particle_Flags,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_particle_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2845201987)
    }
    self := self
    particle_flag_ := particle_flag_
    args := []__bindgen_gde.TypePtr {
        &particle_flag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_emission_shape :: proc "contextless" (
    self: Cpu_Particles3d,
    shape_: Cpu_Particles3d_Emission_Shape,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 491823814)
    }
    self := self
    shape_ := shape_
    args := []__bindgen_gde.TypePtr {
        &shape_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_emission_shape :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Cpu_Particles3d_Emission_Shape) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2961454842)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_emission_sphere_radius :: proc "contextless" (
    self: Cpu_Particles3d,
    radius_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_sphere_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    radius_ := radius_
    args := []__bindgen_gde.TypePtr {
        &radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_emission_sphere_radius :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_sphere_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_emission_box_extents :: proc "contextless" (
    self: Cpu_Particles3d,
    extents_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_box_extents", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    extents_ := extents_
    args := []__bindgen_gde.TypePtr {
        &extents_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_emission_box_extents :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_box_extents", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_emission_points :: proc "contextless" (
    self: Cpu_Particles3d,
    array_: Packed_Vector3_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_points", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 334873810)
    }
    self := self
    array_ := array_
    args := []__bindgen_gde.TypePtr {
        &array_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_emission_points :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_points", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 497664490)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_emission_normals :: proc "contextless" (
    self: Cpu_Particles3d,
    array_: Packed_Vector3_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_normals", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 334873810)
    }
    self := self
    array_ := array_
    args := []__bindgen_gde.TypePtr {
        &array_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_emission_normals :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_normals", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 497664490)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_emission_colors :: proc "contextless" (
    self: Cpu_Particles3d,
    array_: Packed_Color_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_colors", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3546319833)
    }
    self := self
    array_ := array_
    args := []__bindgen_gde.TypePtr {
        &array_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_emission_colors :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Packed_Color_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_colors", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1392750486)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_emission_ring_axis :: proc "contextless" (
    self: Cpu_Particles3d,
    axis_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_ring_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    axis_ := axis_
    args := []__bindgen_gde.TypePtr {
        &axis_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_emission_ring_axis :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_ring_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_emission_ring_height :: proc "contextless" (
    self: Cpu_Particles3d,
    height_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_ring_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    height_ := height_
    args := []__bindgen_gde.TypePtr {
        &height_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_emission_ring_height :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_ring_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_emission_ring_radius :: proc "contextless" (
    self: Cpu_Particles3d,
    radius_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_ring_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    radius_ := radius_
    args := []__bindgen_gde.TypePtr {
        &radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_emission_ring_radius :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_ring_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_emission_ring_inner_radius :: proc "contextless" (
    self: Cpu_Particles3d,
    inner_radius_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_ring_inner_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    inner_radius_ := inner_radius_
    args := []__bindgen_gde.TypePtr {
        &inner_radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_emission_ring_inner_radius :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_ring_inner_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_emission_ring_cone_angle :: proc "contextless" (
    self: Cpu_Particles3d,
    cone_angle_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_ring_cone_angle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    cone_angle_ := cone_angle_
    args := []__bindgen_gde.TypePtr {
        &cone_angle_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_emission_ring_cone_angle :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_ring_cone_angle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_get_gravity :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_gravity :: proc "contextless" (
    self: Cpu_Particles3d,
    accel_vec_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gravity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    accel_vec_ := accel_vec_
    args := []__bindgen_gde.TypePtr {
        &accel_vec_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_split_scale :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_split_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_split_scale :: proc "contextless" (
    self: Cpu_Particles3d,
    split_scale_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_split_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    split_scale_ := split_scale_
    args := []__bindgen_gde.TypePtr {
        &split_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_scale_curve_x :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Curve) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scale_curve_x", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2460114913)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_scale_curve_x :: proc "contextless" (
    self: Cpu_Particles3d,
    scale_curve_: Curve,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scale_curve_x", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 270443179)
    }
    self := self
    scale_curve_ := scale_curve_
    args := []__bindgen_gde.TypePtr {
        &scale_curve_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_scale_curve_y :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Curve) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scale_curve_y", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2460114913)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_scale_curve_y :: proc "contextless" (
    self: Cpu_Particles3d,
    scale_curve_: Curve,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scale_curve_y", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 270443179)
    }
    self := self
    scale_curve_ := scale_curve_
    args := []__bindgen_gde.TypePtr {
        &scale_curve_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_get_scale_curve_z :: proc "contextless" (
    self: Cpu_Particles3d,
) -> (ret: Curve) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scale_curve_z", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2460114913)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

cpu_particles3d_set_scale_curve_z :: proc "contextless" (
    self: Cpu_Particles3d,
    scale_curve_: Curve,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scale_curve_z", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 270443179)
    }
    self := self
    scale_curve_ := scale_curve_
    args := []__bindgen_gde.TypePtr {
        &scale_curve_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

cpu_particles3d_convert_from_particles :: proc "contextless" (
    self: Cpu_Particles3d,
    particles_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("convert_from_particles", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    particles_ := particles_
    args := []__bindgen_gde.TypePtr {
        &particles_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}


// properties
cpu_particles3d_get_emitting :: proc "contextless" (self: Cpu_Particles3d) -> Bool {
    return cpu_particles3d_is_emitting(self)
}
cpu_particles3d_get_preprocess :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_pre_process_time(self)
}
cpu_particles3d_set_preprocess :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_pre_process_time(self, value)
}
cpu_particles3d_get_explosiveness :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_explosiveness_ratio(self)
}
cpu_particles3d_set_explosiveness :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_explosiveness_ratio(self, value)
}
cpu_particles3d_get_randomness :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_randomness_ratio(self)
}
cpu_particles3d_set_randomness :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_randomness_ratio(self, value)
}
cpu_particles3d_get_fract_delta :: proc "contextless" (self: Cpu_Particles3d) -> Bool {
    return cpu_particles3d_get_fractional_delta(self)
}
cpu_particles3d_set_fract_delta :: proc "contextless" (self: Cpu_Particles3d, value: Bool) {
    cpu_particles3d_set_fractional_delta(self, value)
}
cpu_particles3d_get_local_coords :: proc "contextless" (self: Cpu_Particles3d) -> Bool {
    return cpu_particles3d_get_use_local_coordinates(self)
}
cpu_particles3d_set_local_coords :: proc "contextless" (self: Cpu_Particles3d, value: Bool) {
    cpu_particles3d_set_use_local_coordinates(self, value)
}
cpu_particles3d_get_particle_flag_align_y :: proc "contextless" (self: Cpu_Particles3d) -> Bool {
    return cpu_particles3d_get_particle_flag(self, Cpu_Particles3d_Particle_Flags(0))
}
cpu_particles3d_set_particle_flag_align_y :: proc "contextless" (self: Cpu_Particles3d, value: Bool) {
    cpu_particles3d_set_particle_flag(self, Cpu_Particles3d_Particle_Flags(0), value)
}
cpu_particles3d_get_particle_flag_rotate_y :: proc "contextless" (self: Cpu_Particles3d) -> Bool {
    return cpu_particles3d_get_particle_flag(self, Cpu_Particles3d_Particle_Flags(1))
}
cpu_particles3d_set_particle_flag_rotate_y :: proc "contextless" (self: Cpu_Particles3d, value: Bool) {
    cpu_particles3d_set_particle_flag(self, Cpu_Particles3d_Particle_Flags(1), value)
}
cpu_particles3d_get_particle_flag_disable_z :: proc "contextless" (self: Cpu_Particles3d) -> Bool {
    return cpu_particles3d_get_particle_flag(self, Cpu_Particles3d_Particle_Flags(2))
}
cpu_particles3d_set_particle_flag_disable_z :: proc "contextless" (self: Cpu_Particles3d, value: Bool) {
    cpu_particles3d_set_particle_flag(self, Cpu_Particles3d_Particle_Flags(2), value)
}
cpu_particles3d_get_initial_velocity_min :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_min(self, Cpu_Particles3d_Parameter(0))
}
cpu_particles3d_set_initial_velocity_min :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_min(self, Cpu_Particles3d_Parameter(0), value)
}
cpu_particles3d_get_initial_velocity_max :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_max(self, Cpu_Particles3d_Parameter(0))
}
cpu_particles3d_set_initial_velocity_max :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_max(self, Cpu_Particles3d_Parameter(0), value)
}
cpu_particles3d_get_angular_velocity_min :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_min(self, Cpu_Particles3d_Parameter(1))
}
cpu_particles3d_set_angular_velocity_min :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_min(self, Cpu_Particles3d_Parameter(1), value)
}
cpu_particles3d_get_angular_velocity_max :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_max(self, Cpu_Particles3d_Parameter(1))
}
cpu_particles3d_set_angular_velocity_max :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_max(self, Cpu_Particles3d_Parameter(1), value)
}
cpu_particles3d_get_angular_velocity_curve :: proc "contextless" (self: Cpu_Particles3d) -> Curve {
    return cpu_particles3d_get_param_curve(self, Cpu_Particles3d_Parameter(1))
}
cpu_particles3d_set_angular_velocity_curve :: proc "contextless" (self: Cpu_Particles3d, value: Curve) {
    cpu_particles3d_set_param_curve(self, Cpu_Particles3d_Parameter(1), value)
}
cpu_particles3d_get_orbit_velocity_min :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_min(self, Cpu_Particles3d_Parameter(2))
}
cpu_particles3d_set_orbit_velocity_min :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_min(self, Cpu_Particles3d_Parameter(2), value)
}
cpu_particles3d_get_orbit_velocity_max :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_max(self, Cpu_Particles3d_Parameter(2))
}
cpu_particles3d_set_orbit_velocity_max :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_max(self, Cpu_Particles3d_Parameter(2), value)
}
cpu_particles3d_get_orbit_velocity_curve :: proc "contextless" (self: Cpu_Particles3d) -> Curve {
    return cpu_particles3d_get_param_curve(self, Cpu_Particles3d_Parameter(2))
}
cpu_particles3d_set_orbit_velocity_curve :: proc "contextless" (self: Cpu_Particles3d, value: Curve) {
    cpu_particles3d_set_param_curve(self, Cpu_Particles3d_Parameter(2), value)
}
cpu_particles3d_get_linear_accel_min :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_min(self, Cpu_Particles3d_Parameter(3))
}
cpu_particles3d_set_linear_accel_min :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_min(self, Cpu_Particles3d_Parameter(3), value)
}
cpu_particles3d_get_linear_accel_max :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_max(self, Cpu_Particles3d_Parameter(3))
}
cpu_particles3d_set_linear_accel_max :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_max(self, Cpu_Particles3d_Parameter(3), value)
}
cpu_particles3d_get_linear_accel_curve :: proc "contextless" (self: Cpu_Particles3d) -> Curve {
    return cpu_particles3d_get_param_curve(self, Cpu_Particles3d_Parameter(3))
}
cpu_particles3d_set_linear_accel_curve :: proc "contextless" (self: Cpu_Particles3d, value: Curve) {
    cpu_particles3d_set_param_curve(self, Cpu_Particles3d_Parameter(3), value)
}
cpu_particles3d_get_radial_accel_min :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_min(self, Cpu_Particles3d_Parameter(4))
}
cpu_particles3d_set_radial_accel_min :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_min(self, Cpu_Particles3d_Parameter(4), value)
}
cpu_particles3d_get_radial_accel_max :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_max(self, Cpu_Particles3d_Parameter(4))
}
cpu_particles3d_set_radial_accel_max :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_max(self, Cpu_Particles3d_Parameter(4), value)
}
cpu_particles3d_get_radial_accel_curve :: proc "contextless" (self: Cpu_Particles3d) -> Curve {
    return cpu_particles3d_get_param_curve(self, Cpu_Particles3d_Parameter(4))
}
cpu_particles3d_set_radial_accel_curve :: proc "contextless" (self: Cpu_Particles3d, value: Curve) {
    cpu_particles3d_set_param_curve(self, Cpu_Particles3d_Parameter(4), value)
}
cpu_particles3d_get_tangential_accel_min :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_min(self, Cpu_Particles3d_Parameter(5))
}
cpu_particles3d_set_tangential_accel_min :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_min(self, Cpu_Particles3d_Parameter(5), value)
}
cpu_particles3d_get_tangential_accel_max :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_max(self, Cpu_Particles3d_Parameter(5))
}
cpu_particles3d_set_tangential_accel_max :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_max(self, Cpu_Particles3d_Parameter(5), value)
}
cpu_particles3d_get_tangential_accel_curve :: proc "contextless" (self: Cpu_Particles3d) -> Curve {
    return cpu_particles3d_get_param_curve(self, Cpu_Particles3d_Parameter(5))
}
cpu_particles3d_set_tangential_accel_curve :: proc "contextless" (self: Cpu_Particles3d, value: Curve) {
    cpu_particles3d_set_param_curve(self, Cpu_Particles3d_Parameter(5), value)
}
cpu_particles3d_get_damping_min :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_min(self, Cpu_Particles3d_Parameter(6))
}
cpu_particles3d_set_damping_min :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_min(self, Cpu_Particles3d_Parameter(6), value)
}
cpu_particles3d_get_damping_max :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_max(self, Cpu_Particles3d_Parameter(6))
}
cpu_particles3d_set_damping_max :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_max(self, Cpu_Particles3d_Parameter(6), value)
}
cpu_particles3d_get_damping_curve :: proc "contextless" (self: Cpu_Particles3d) -> Curve {
    return cpu_particles3d_get_param_curve(self, Cpu_Particles3d_Parameter(6))
}
cpu_particles3d_set_damping_curve :: proc "contextless" (self: Cpu_Particles3d, value: Curve) {
    cpu_particles3d_set_param_curve(self, Cpu_Particles3d_Parameter(6), value)
}
cpu_particles3d_get_angle_min :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_min(self, Cpu_Particles3d_Parameter(7))
}
cpu_particles3d_set_angle_min :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_min(self, Cpu_Particles3d_Parameter(7), value)
}
cpu_particles3d_get_angle_max :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_max(self, Cpu_Particles3d_Parameter(7))
}
cpu_particles3d_set_angle_max :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_max(self, Cpu_Particles3d_Parameter(7), value)
}
cpu_particles3d_get_angle_curve :: proc "contextless" (self: Cpu_Particles3d) -> Curve {
    return cpu_particles3d_get_param_curve(self, Cpu_Particles3d_Parameter(7))
}
cpu_particles3d_set_angle_curve :: proc "contextless" (self: Cpu_Particles3d, value: Curve) {
    cpu_particles3d_set_param_curve(self, Cpu_Particles3d_Parameter(7), value)
}
cpu_particles3d_get_scale_amount_min :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_min(self, Cpu_Particles3d_Parameter(8))
}
cpu_particles3d_set_scale_amount_min :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_min(self, Cpu_Particles3d_Parameter(8), value)
}
cpu_particles3d_get_scale_amount_max :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_max(self, Cpu_Particles3d_Parameter(8))
}
cpu_particles3d_set_scale_amount_max :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_max(self, Cpu_Particles3d_Parameter(8), value)
}
cpu_particles3d_get_scale_amount_curve :: proc "contextless" (self: Cpu_Particles3d) -> Curve {
    return cpu_particles3d_get_param_curve(self, Cpu_Particles3d_Parameter(8))
}
cpu_particles3d_set_scale_amount_curve :: proc "contextless" (self: Cpu_Particles3d, value: Curve) {
    cpu_particles3d_set_param_curve(self, Cpu_Particles3d_Parameter(8), value)
}
cpu_particles3d_get_hue_variation_min :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_min(self, Cpu_Particles3d_Parameter(9))
}
cpu_particles3d_set_hue_variation_min :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_min(self, Cpu_Particles3d_Parameter(9), value)
}
cpu_particles3d_get_hue_variation_max :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_max(self, Cpu_Particles3d_Parameter(9))
}
cpu_particles3d_set_hue_variation_max :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_max(self, Cpu_Particles3d_Parameter(9), value)
}
cpu_particles3d_get_hue_variation_curve :: proc "contextless" (self: Cpu_Particles3d) -> Curve {
    return cpu_particles3d_get_param_curve(self, Cpu_Particles3d_Parameter(9))
}
cpu_particles3d_set_hue_variation_curve :: proc "contextless" (self: Cpu_Particles3d, value: Curve) {
    cpu_particles3d_set_param_curve(self, Cpu_Particles3d_Parameter(9), value)
}
cpu_particles3d_get_anim_speed_min :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_min(self, Cpu_Particles3d_Parameter(10))
}
cpu_particles3d_set_anim_speed_min :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_min(self, Cpu_Particles3d_Parameter(10), value)
}
cpu_particles3d_get_anim_speed_max :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_max(self, Cpu_Particles3d_Parameter(10))
}
cpu_particles3d_set_anim_speed_max :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_max(self, Cpu_Particles3d_Parameter(10), value)
}
cpu_particles3d_get_anim_speed_curve :: proc "contextless" (self: Cpu_Particles3d) -> Curve {
    return cpu_particles3d_get_param_curve(self, Cpu_Particles3d_Parameter(10))
}
cpu_particles3d_set_anim_speed_curve :: proc "contextless" (self: Cpu_Particles3d, value: Curve) {
    cpu_particles3d_set_param_curve(self, Cpu_Particles3d_Parameter(10), value)
}
cpu_particles3d_get_anim_offset_min :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_min(self, Cpu_Particles3d_Parameter(11))
}
cpu_particles3d_set_anim_offset_min :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_min(self, Cpu_Particles3d_Parameter(11), value)
}
cpu_particles3d_get_anim_offset_max :: proc "contextless" (self: Cpu_Particles3d) -> f64 {
    return cpu_particles3d_get_param_max(self, Cpu_Particles3d_Parameter(11))
}
cpu_particles3d_set_anim_offset_max :: proc "contextless" (self: Cpu_Particles3d, value: f64) {
    cpu_particles3d_set_param_max(self, Cpu_Particles3d_Parameter(11), value)
}
cpu_particles3d_get_anim_offset_curve :: proc "contextless" (self: Cpu_Particles3d) -> Curve {
    return cpu_particles3d_get_param_curve(self, Cpu_Particles3d_Parameter(11))
}
cpu_particles3d_set_anim_offset_curve :: proc "contextless" (self: Cpu_Particles3d, value: Curve) {
    cpu_particles3d_set_param_curve(self, Cpu_Particles3d_Parameter(11), value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
cpu_particles3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("CPUParticles3D", true)
}

@(private = "file")
__class_name: String_Name