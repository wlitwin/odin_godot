package godot

import __bindgen_gde "godot:gdext"

Particle_Process_Material_Constants :: enum {
}
Particle_Process_Material_Parameter :: enum int {
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
    Param_Radial_Velocity = 15,
    Param_Directional_Velocity = 16,
    Param_Scale_Over_Velocity = 17,
    Param_Max = 18,
    Param_Turb_Vel_Influence = 13,
    Param_Turb_Init_Displacement = 14,
    Param_Turb_Influence_Over_Life = 12,
}
Particle_Process_Material_Particle_Flags :: enum int {
    Particle_Flag_Align_Y_To_Velocity = 0,
    Particle_Flag_Rotate_Y = 1,
    Particle_Flag_Disable_Z = 2,
    Particle_Flag_Damping_As_Friction = 3,
    Particle_Flag_Max = 4,
}
Particle_Process_Material_Emission_Shape :: enum int {
    Emission_Shape_Point = 0,
    Emission_Shape_Sphere = 1,
    Emission_Shape_Sphere_Surface = 2,
    Emission_Shape_Box = 3,
    Emission_Shape_Points = 4,
    Emission_Shape_Directed_Points = 5,
    Emission_Shape_Ring = 6,
    Emission_Shape_Max = 7,
}
Particle_Process_Material_Sub_Emitter_Mode :: enum int {
    Sub_Emitter_Disabled = 0,
    Sub_Emitter_Constant = 1,
    Sub_Emitter_At_End = 2,
    Sub_Emitter_At_Collision = 3,
    Sub_Emitter_At_Start = 4,
    Sub_Emitter_Max = 5,
}
Particle_Process_Material_Collision_Mode :: enum int {
    Collision_Disabled = 0,
    Collision_Rigid = 1,
    Collision_Hide_On_Contact = 2,
    Collision_Max = 3,
}



particle_process_material_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

particle_process_material_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_particle_process_material :: proc "contextless" () -> Particle_Process_Material {
    return cast(Particle_Process_Material)__bindgen_gde.classdb_construct_object(particle_process_material_name_ref())
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

particle_process_material_set_direction :: proc "contextless" (
    self: Particle_Process_Material,
    degrees_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_direction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    degrees_ := degrees_
    args := []__bindgen_gde.TypePtr {
        &degrees_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_direction :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_set_inherit_velocity_ratio :: proc "contextless" (
    self: Particle_Process_Material,
    ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_inherit_velocity_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    ratio_ := ratio_
    args := []__bindgen_gde.TypePtr {
        &ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_inherit_velocity_ratio :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_inherit_velocity_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_spread :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_get_spread :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_set_flatness :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_get_flatness :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_set_param :: proc "contextless" (
    self: Particle_Process_Material,
    param_: Particle_Process_Material_Parameter,
    value_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 676779352)
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

particle_process_material_get_param :: proc "contextless" (
    self: Particle_Process_Material,
    param_: Particle_Process_Material_Parameter,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2623708480)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_param_min :: proc "contextless" (
    self: Particle_Process_Material,
    param_: Particle_Process_Material_Parameter,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2295964248)
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

particle_process_material_get_param_min :: proc "contextless" (
    self: Particle_Process_Material,
    param_: Particle_Process_Material_Parameter,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3903786503)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_param_max :: proc "contextless" (
    self: Particle_Process_Material,
    param_: Particle_Process_Material_Parameter,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2295964248)
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

particle_process_material_get_param_max :: proc "contextless" (
    self: Particle_Process_Material,
    param_: Particle_Process_Material_Parameter,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3903786503)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_param_texture :: proc "contextless" (
    self: Particle_Process_Material,
    param_: Particle_Process_Material_Parameter,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 526976089)
    }
    self := self
    param_ := param_
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &param_,
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_param_texture :: proc "contextless" (
    self: Particle_Process_Material,
    param_: Particle_Process_Material_Parameter,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3489372978)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_color :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_get_color :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_set_color_ramp :: proc "contextless" (
    self: Particle_Process_Material,
    ramp_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_color_ramp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    ramp_ := ramp_
    args := []__bindgen_gde.TypePtr {
        &ramp_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_color_ramp :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color_ramp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_alpha_curve :: proc "contextless" (
    self: Particle_Process_Material,
    curve_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alpha_curve", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    curve_ := curve_
    args := []__bindgen_gde.TypePtr {
        &curve_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_alpha_curve :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alpha_curve", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_emission_curve :: proc "contextless" (
    self: Particle_Process_Material,
    curve_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_curve", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    curve_ := curve_
    args := []__bindgen_gde.TypePtr {
        &curve_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_emission_curve :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_curve", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_color_initial_ramp :: proc "contextless" (
    self: Particle_Process_Material,
    ramp_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_color_initial_ramp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    ramp_ := ramp_
    args := []__bindgen_gde.TypePtr {
        &ramp_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_color_initial_ramp :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color_initial_ramp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_velocity_limit_curve :: proc "contextless" (
    self: Particle_Process_Material,
    curve_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_velocity_limit_curve", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    curve_ := curve_
    args := []__bindgen_gde.TypePtr {
        &curve_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_velocity_limit_curve :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_velocity_limit_curve", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_particle_flag :: proc "contextless" (
    self: Particle_Process_Material,
    particle_flag_: Particle_Process_Material_Particle_Flags,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_particle_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1711815571)
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

particle_process_material_get_particle_flag :: proc "contextless" (
    self: Particle_Process_Material,
    particle_flag_: Particle_Process_Material_Particle_Flags,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_particle_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3895316907)
    }
    self := self
    particle_flag_ := particle_flag_
    args := []__bindgen_gde.TypePtr {
        &particle_flag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_velocity_pivot :: proc "contextless" (
    self: Particle_Process_Material,
    pivot_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_velocity_pivot", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    pivot_ := pivot_
    args := []__bindgen_gde.TypePtr {
        &pivot_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_velocity_pivot :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_velocity_pivot", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3783033775)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_emission_shape :: proc "contextless" (
    self: Particle_Process_Material,
    shape_: Particle_Process_Material_Emission_Shape,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 461501442)
    }
    self := self
    shape_ := shape_
    args := []__bindgen_gde.TypePtr {
        &shape_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_emission_shape :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Particle_Process_Material_Emission_Shape) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3719733018)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_emission_sphere_radius :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_get_emission_sphere_radius :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_set_emission_box_extents :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_get_emission_box_extents :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_set_emission_point_texture :: proc "contextless" (
    self: Particle_Process_Material,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_point_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_emission_point_texture :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_point_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_emission_normal_texture :: proc "contextless" (
    self: Particle_Process_Material,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_normal_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_emission_normal_texture :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_normal_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_emission_color_texture :: proc "contextless" (
    self: Particle_Process_Material,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_color_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_emission_color_texture :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_color_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_emission_point_count :: proc "contextless" (
    self: Particle_Process_Material,
    point_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_point_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    point_count_ := point_count_
    args := []__bindgen_gde.TypePtr {
        &point_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_emission_point_count :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_point_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_emission_ring_axis :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_get_emission_ring_axis :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_set_emission_ring_height :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_get_emission_ring_height :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_set_emission_ring_radius :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_get_emission_ring_radius :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_set_emission_ring_inner_radius :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_get_emission_ring_inner_radius :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_set_emission_ring_cone_angle :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_get_emission_ring_cone_angle :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_set_emission_shape_offset :: proc "contextless" (
    self: Particle_Process_Material,
    emission_shape_offset_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_shape_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    emission_shape_offset_ := emission_shape_offset_
    args := []__bindgen_gde.TypePtr {
        &emission_shape_offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_emission_shape_offset :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_shape_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_emission_shape_scale :: proc "contextless" (
    self: Particle_Process_Material,
    emission_shape_scale_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_emission_shape_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    emission_shape_scale_ := emission_shape_scale_
    args := []__bindgen_gde.TypePtr {
        &emission_shape_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_emission_shape_scale :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_emission_shape_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_get_turbulence_enabled :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_turbulence_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_turbulence_enabled :: proc "contextless" (
    self: Particle_Process_Material,
    turbulence_enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_turbulence_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    turbulence_enabled_ := turbulence_enabled_
    args := []__bindgen_gde.TypePtr {
        &turbulence_enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_turbulence_noise_strength :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_turbulence_noise_strength", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_turbulence_noise_strength :: proc "contextless" (
    self: Particle_Process_Material,
    turbulence_noise_strength_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_turbulence_noise_strength", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    turbulence_noise_strength_ := turbulence_noise_strength_
    args := []__bindgen_gde.TypePtr {
        &turbulence_noise_strength_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_turbulence_noise_scale :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_turbulence_noise_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_turbulence_noise_scale :: proc "contextless" (
    self: Particle_Process_Material,
    turbulence_noise_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_turbulence_noise_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    turbulence_noise_scale_ := turbulence_noise_scale_
    args := []__bindgen_gde.TypePtr {
        &turbulence_noise_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_turbulence_noise_speed_random :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_turbulence_noise_speed_random", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_turbulence_noise_speed_random :: proc "contextless" (
    self: Particle_Process_Material,
    turbulence_noise_speed_random_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_turbulence_noise_speed_random", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    turbulence_noise_speed_random_ := turbulence_noise_speed_random_
    args := []__bindgen_gde.TypePtr {
        &turbulence_noise_speed_random_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_turbulence_noise_speed :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_turbulence_noise_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_turbulence_noise_speed :: proc "contextless" (
    self: Particle_Process_Material,
    turbulence_noise_speed_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_turbulence_noise_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    turbulence_noise_speed_ := turbulence_noise_speed_
    args := []__bindgen_gde.TypePtr {
        &turbulence_noise_speed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_gravity :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_set_gravity :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_set_lifetime_randomness :: proc "contextless" (
    self: Particle_Process_Material,
    randomness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_lifetime_randomness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    randomness_ := randomness_
    args := []__bindgen_gde.TypePtr {
        &randomness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_lifetime_randomness :: proc "contextless" (
    self: Particle_Process_Material,
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

particle_process_material_get_sub_emitter_mode :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Particle_Process_Material_Sub_Emitter_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sub_emitter_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2399052877)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_sub_emitter_mode :: proc "contextless" (
    self: Particle_Process_Material,
    mode_: Particle_Process_Material_Sub_Emitter_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sub_emitter_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2161806672)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_sub_emitter_frequency :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sub_emitter_frequency", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_sub_emitter_frequency :: proc "contextless" (
    self: Particle_Process_Material,
    hz_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sub_emitter_frequency", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    hz_ := hz_
    args := []__bindgen_gde.TypePtr {
        &hz_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_sub_emitter_amount_at_end :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sub_emitter_amount_at_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_sub_emitter_amount_at_end :: proc "contextless" (
    self: Particle_Process_Material,
    amount_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sub_emitter_amount_at_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_sub_emitter_amount_at_collision :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sub_emitter_amount_at_collision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_sub_emitter_amount_at_collision :: proc "contextless" (
    self: Particle_Process_Material,
    amount_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sub_emitter_amount_at_collision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_sub_emitter_amount_at_start :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sub_emitter_amount_at_start", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_sub_emitter_amount_at_start :: proc "contextless" (
    self: Particle_Process_Material,
    amount_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sub_emitter_amount_at_start", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_sub_emitter_keep_velocity :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sub_emitter_keep_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_sub_emitter_keep_velocity :: proc "contextless" (
    self: Particle_Process_Material,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sub_emitter_keep_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_set_attractor_interaction_enabled :: proc "contextless" (
    self: Particle_Process_Material,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_attractor_interaction_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_is_attractor_interaction_enabled :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_attractor_interaction_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_collision_mode :: proc "contextless" (
    self: Particle_Process_Material,
    mode_: Particle_Process_Material_Collision_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 653804659)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_collision_mode :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Particle_Process_Material_Collision_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 139371864)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_collision_use_scale :: proc "contextless" (
    self: Particle_Process_Material,
    radius_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_use_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    radius_ := radius_
    args := []__bindgen_gde.TypePtr {
        &radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_is_collision_using_scale :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_collision_using_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_collision_friction :: proc "contextless" (
    self: Particle_Process_Material,
    friction_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_friction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    friction_ := friction_
    args := []__bindgen_gde.TypePtr {
        &friction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_collision_friction :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_friction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

particle_process_material_set_collision_bounce :: proc "contextless" (
    self: Particle_Process_Material,
    bounce_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_bounce", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    bounce_ := bounce_
    args := []__bindgen_gde.TypePtr {
        &bounce_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

particle_process_material_get_collision_bounce :: proc "contextless" (
    self: Particle_Process_Material,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_bounce", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
particle_process_material_get_particle_flag_align_y :: proc "contextless" (self: Particle_Process_Material) -> Bool {
    return particle_process_material_get_particle_flag(self, Particle_Process_Material_Particle_Flags(0))
}
particle_process_material_set_particle_flag_align_y :: proc "contextless" (self: Particle_Process_Material, value: Bool) {
    particle_process_material_set_particle_flag(self, Particle_Process_Material_Particle_Flags(0), value)
}
particle_process_material_get_particle_flag_rotate_y :: proc "contextless" (self: Particle_Process_Material) -> Bool {
    return particle_process_material_get_particle_flag(self, Particle_Process_Material_Particle_Flags(1))
}
particle_process_material_set_particle_flag_rotate_y :: proc "contextless" (self: Particle_Process_Material, value: Bool) {
    particle_process_material_set_particle_flag(self, Particle_Process_Material_Particle_Flags(1), value)
}
particle_process_material_get_particle_flag_disable_z :: proc "contextless" (self: Particle_Process_Material) -> Bool {
    return particle_process_material_get_particle_flag(self, Particle_Process_Material_Particle_Flags(2))
}
particle_process_material_set_particle_flag_disable_z :: proc "contextless" (self: Particle_Process_Material, value: Bool) {
    particle_process_material_set_particle_flag(self, Particle_Process_Material_Particle_Flags(2), value)
}
particle_process_material_get_particle_flag_damping_as_friction :: proc "contextless" (self: Particle_Process_Material) -> Bool {
    return particle_process_material_get_particle_flag(self, Particle_Process_Material_Particle_Flags(3))
}
particle_process_material_set_particle_flag_damping_as_friction :: proc "contextless" (self: Particle_Process_Material, value: Bool) {
    particle_process_material_set_particle_flag(self, Particle_Process_Material_Particle_Flags(3), value)
}
particle_process_material_get_angle :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(7))
}
particle_process_material_set_angle :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(7), value)
}
particle_process_material_get_angle_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(7))
}
particle_process_material_set_angle_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(7), value)
}
particle_process_material_get_angle_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(7))
}
particle_process_material_set_angle_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(7), value)
}
particle_process_material_get_angle_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(7))
}
particle_process_material_set_angle_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(7), value)
}
particle_process_material_get_initial_velocity :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(0))
}
particle_process_material_set_initial_velocity :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(0), value)
}
particle_process_material_get_initial_velocity_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(0))
}
particle_process_material_set_initial_velocity_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(0), value)
}
particle_process_material_get_initial_velocity_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(0))
}
particle_process_material_set_initial_velocity_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(0), value)
}
particle_process_material_get_angular_velocity :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(1))
}
particle_process_material_set_angular_velocity :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(1), value)
}
particle_process_material_get_angular_velocity_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(1))
}
particle_process_material_set_angular_velocity_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(1), value)
}
particle_process_material_get_angular_velocity_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(1))
}
particle_process_material_set_angular_velocity_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(1), value)
}
particle_process_material_get_angular_velocity_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(1))
}
particle_process_material_set_angular_velocity_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(1), value)
}
particle_process_material_get_directional_velocity :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(16))
}
particle_process_material_set_directional_velocity :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(16), value)
}
particle_process_material_get_directional_velocity_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(16))
}
particle_process_material_set_directional_velocity_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(16), value)
}
particle_process_material_get_directional_velocity_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(16))
}
particle_process_material_set_directional_velocity_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(16), value)
}
particle_process_material_get_directional_velocity_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(16))
}
particle_process_material_set_directional_velocity_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(16), value)
}
particle_process_material_get_orbit_velocity :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(2))
}
particle_process_material_set_orbit_velocity :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(2), value)
}
particle_process_material_get_orbit_velocity_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(2))
}
particle_process_material_set_orbit_velocity_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(2), value)
}
particle_process_material_get_orbit_velocity_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(2))
}
particle_process_material_set_orbit_velocity_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(2), value)
}
particle_process_material_get_orbit_velocity_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(2))
}
particle_process_material_set_orbit_velocity_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(2), value)
}
particle_process_material_get_radial_velocity :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(15))
}
particle_process_material_set_radial_velocity :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(15), value)
}
particle_process_material_get_radial_velocity_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(15))
}
particle_process_material_set_radial_velocity_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(15), value)
}
particle_process_material_get_radial_velocity_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(15))
}
particle_process_material_set_radial_velocity_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(15), value)
}
particle_process_material_get_radial_velocity_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(15))
}
particle_process_material_set_radial_velocity_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(15), value)
}
particle_process_material_get_linear_accel :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(3))
}
particle_process_material_set_linear_accel :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(3), value)
}
particle_process_material_get_linear_accel_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(3))
}
particle_process_material_set_linear_accel_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(3), value)
}
particle_process_material_get_linear_accel_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(3))
}
particle_process_material_set_linear_accel_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(3), value)
}
particle_process_material_get_linear_accel_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(3))
}
particle_process_material_set_linear_accel_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(3), value)
}
particle_process_material_get_radial_accel :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(4))
}
particle_process_material_set_radial_accel :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(4), value)
}
particle_process_material_get_radial_accel_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(4))
}
particle_process_material_set_radial_accel_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(4), value)
}
particle_process_material_get_radial_accel_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(4))
}
particle_process_material_set_radial_accel_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(4), value)
}
particle_process_material_get_radial_accel_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(4))
}
particle_process_material_set_radial_accel_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(4), value)
}
particle_process_material_get_tangential_accel :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(5))
}
particle_process_material_set_tangential_accel :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(5), value)
}
particle_process_material_get_tangential_accel_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(5))
}
particle_process_material_set_tangential_accel_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(5), value)
}
particle_process_material_get_tangential_accel_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(5))
}
particle_process_material_set_tangential_accel_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(5), value)
}
particle_process_material_get_tangential_accel_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(5))
}
particle_process_material_set_tangential_accel_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(5), value)
}
particle_process_material_get_damping :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(6))
}
particle_process_material_set_damping :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(6), value)
}
particle_process_material_get_damping_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(6))
}
particle_process_material_set_damping_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(6), value)
}
particle_process_material_get_damping_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(6))
}
particle_process_material_set_damping_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(6), value)
}
particle_process_material_get_damping_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(6))
}
particle_process_material_set_damping_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(6), value)
}
particle_process_material_get_attractor_interaction_enabled :: proc "contextless" (self: Particle_Process_Material) -> Bool {
    return particle_process_material_is_attractor_interaction_enabled(self)
}
particle_process_material_get_scale :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(8))
}
particle_process_material_set_scale :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(8), value)
}
particle_process_material_get_scale_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(8))
}
particle_process_material_set_scale_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(8), value)
}
particle_process_material_get_scale_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(8))
}
particle_process_material_set_scale_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(8), value)
}
particle_process_material_get_scale_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(8))
}
particle_process_material_set_scale_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(8), value)
}
particle_process_material_get_scale_over_velocity :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(17))
}
particle_process_material_set_scale_over_velocity :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(17), value)
}
particle_process_material_get_scale_over_velocity_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(17))
}
particle_process_material_set_scale_over_velocity_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(17), value)
}
particle_process_material_get_scale_over_velocity_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(17))
}
particle_process_material_set_scale_over_velocity_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(17), value)
}
particle_process_material_get_scale_over_velocity_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(17))
}
particle_process_material_set_scale_over_velocity_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(17), value)
}
particle_process_material_get_hue_variation :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(9))
}
particle_process_material_set_hue_variation :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(9), value)
}
particle_process_material_get_hue_variation_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(9))
}
particle_process_material_set_hue_variation_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(9), value)
}
particle_process_material_get_hue_variation_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(9))
}
particle_process_material_set_hue_variation_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(9), value)
}
particle_process_material_get_hue_variation_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(9))
}
particle_process_material_set_hue_variation_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(9), value)
}
particle_process_material_get_anim_speed :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(10))
}
particle_process_material_set_anim_speed :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(10), value)
}
particle_process_material_get_anim_speed_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(10))
}
particle_process_material_set_anim_speed_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(10), value)
}
particle_process_material_get_anim_speed_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(10))
}
particle_process_material_set_anim_speed_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(10), value)
}
particle_process_material_get_anim_speed_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(10))
}
particle_process_material_set_anim_speed_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(10), value)
}
particle_process_material_get_anim_offset :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(11))
}
particle_process_material_set_anim_offset :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(11), value)
}
particle_process_material_get_anim_offset_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(11))
}
particle_process_material_set_anim_offset_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(11), value)
}
particle_process_material_get_anim_offset_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(11))
}
particle_process_material_set_anim_offset_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(11), value)
}
particle_process_material_get_anim_offset_curve :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(11))
}
particle_process_material_set_anim_offset_curve :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(11), value)
}
particle_process_material_get_turbulence_influence :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(13))
}
particle_process_material_set_turbulence_influence :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(13), value)
}
particle_process_material_get_turbulence_influence_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(13))
}
particle_process_material_set_turbulence_influence_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(13), value)
}
particle_process_material_get_turbulence_influence_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(13))
}
particle_process_material_set_turbulence_influence_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(13), value)
}
particle_process_material_get_turbulence_initial_displacement :: proc "contextless" (self: Particle_Process_Material) -> Vector2 {
    return particle_process_material_get_param(self, Particle_Process_Material_Parameter(14))
}
particle_process_material_set_turbulence_initial_displacement :: proc "contextless" (self: Particle_Process_Material, value: Vector2) {
    particle_process_material_set_param(self, Particle_Process_Material_Parameter(14), value)
}
particle_process_material_get_turbulence_initial_displacement_min :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_min(self, Particle_Process_Material_Parameter(14))
}
particle_process_material_set_turbulence_initial_displacement_min :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_min(self, Particle_Process_Material_Parameter(14), value)
}
particle_process_material_get_turbulence_initial_displacement_max :: proc "contextless" (self: Particle_Process_Material) -> f64 {
    return particle_process_material_get_param_max(self, Particle_Process_Material_Parameter(14))
}
particle_process_material_set_turbulence_initial_displacement_max :: proc "contextless" (self: Particle_Process_Material, value: f64) {
    particle_process_material_set_param_max(self, Particle_Process_Material_Parameter(14), value)
}
particle_process_material_get_turbulence_influence_over_life :: proc "contextless" (self: Particle_Process_Material) -> Texture2d {
    return particle_process_material_get_param_texture(self, Particle_Process_Material_Parameter(12))
}
particle_process_material_set_turbulence_influence_over_life :: proc "contextless" (self: Particle_Process_Material, value: Texture2d) {
    particle_process_material_set_param_texture(self, Particle_Process_Material_Parameter(12), value)
}
particle_process_material_get_collision_use_scale :: proc "contextless" (self: Particle_Process_Material) -> Bool {
    return particle_process_material_is_collision_using_scale(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
particle_process_material_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ParticleProcessMaterial", true)
}

@(private = "file")
__class_name: String_Name