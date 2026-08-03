package godot

import __bindgen_gde "godot:gdext"

Physical_Bone3d_Constants :: enum {
}
Physical_Bone3d_Damp_Mode :: enum int {
    Damp_Mode_Combine = 0,
    Damp_Mode_Replace = 1,
}
Physical_Bone3d_Joint_Type :: enum int {
    Joint_Type_None = 0,
    Joint_Type_Pin = 1,
    Joint_Type_Cone = 2,
    Joint_Type_Hinge = 3,
    Joint_Type_Slider = 4,
    Joint_Type_6dof = 5,
}



physical_bone3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

physical_bone3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_physical_bone3d :: proc "contextless" () -> Physical_Bone3d {
    return cast(Physical_Bone3d)__bindgen_gde.classdb_construct_object(physical_bone3d_name_ref())
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

physical_bone3d__integrate_forces :: proc "contextless" (
    self: Physical_Bone3d,
    state_: Physics_Direct_Body_State3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_integrate_forces", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 420958145)
    }
    self := self
    state_ := state_
    args := []__bindgen_gde.TypePtr {
        &state_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_apply_central_impulse :: proc "contextless" (
    self: Physical_Bone3d,
    impulse_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("apply_central_impulse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    impulse_ := impulse_
    args := []__bindgen_gde.TypePtr {
        &impulse_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_apply_impulse :: proc "contextless" (
    self: Physical_Bone3d,
    impulse_: Vector3,
    position_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("apply_impulse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2754756483)
    }
    self := self
    impulse_ := impulse_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &impulse_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_set_joint_type :: proc "contextless" (
    self: Physical_Bone3d,
    joint_type_: Physical_Bone3d_Joint_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2289552604)
    }
    self := self
    joint_type_ := joint_type_
    args := []__bindgen_gde.TypePtr {
        &joint_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_joint_type :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: Physical_Bone3d_Joint_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 931347320)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_joint_offset :: proc "contextless" (
    self: Physical_Bone3d,
    offset_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2952846383)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_joint_offset :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3229777777)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_joint_rotation :: proc "contextless" (
    self: Physical_Bone3d,
    euler_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_joint_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    euler_ := euler_
    args := []__bindgen_gde.TypePtr {
        &euler_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_joint_rotation :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_joint_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_body_offset :: proc "contextless" (
    self: Physical_Bone3d,
    offset_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_body_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2952846383)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_body_offset :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_body_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3229777777)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_get_simulate_physics :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_simulate_physics", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_is_simulating_physics :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_simulating_physics", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_get_bone_id :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bone_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_mass :: proc "contextless" (
    self: Physical_Bone3d,
    mass_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    mass_ := mass_
    args := []__bindgen_gde.TypePtr {
        &mass_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_mass :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_friction :: proc "contextless" (
    self: Physical_Bone3d,
    friction_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_friction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    friction_ := friction_
    args := []__bindgen_gde.TypePtr {
        &friction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_friction :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_friction", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_bounce :: proc "contextless" (
    self: Physical_Bone3d,
    bounce_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bounce", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    bounce_ := bounce_
    args := []__bindgen_gde.TypePtr {
        &bounce_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_bounce :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bounce", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_gravity_scale :: proc "contextless" (
    self: Physical_Bone3d,
    gravity_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gravity_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    gravity_scale_ := gravity_scale_
    args := []__bindgen_gde.TypePtr {
        &gravity_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_gravity_scale :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gravity_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_linear_damp_mode :: proc "contextless" (
    self: Physical_Bone3d,
    linear_damp_mode_: Physical_Bone3d_Damp_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_linear_damp_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1244972221)
    }
    self := self
    linear_damp_mode_ := linear_damp_mode_
    args := []__bindgen_gde.TypePtr {
        &linear_damp_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_linear_damp_mode :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: Physical_Bone3d_Damp_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_linear_damp_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 205884699)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_angular_damp_mode :: proc "contextless" (
    self: Physical_Bone3d,
    angular_damp_mode_: Physical_Bone3d_Damp_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_angular_damp_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1244972221)
    }
    self := self
    angular_damp_mode_ := angular_damp_mode_
    args := []__bindgen_gde.TypePtr {
        &angular_damp_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_angular_damp_mode :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: Physical_Bone3d_Damp_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_angular_damp_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 205884699)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_linear_damp :: proc "contextless" (
    self: Physical_Bone3d,
    linear_damp_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_linear_damp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    linear_damp_ := linear_damp_
    args := []__bindgen_gde.TypePtr {
        &linear_damp_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_linear_damp :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_linear_damp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_angular_damp :: proc "contextless" (
    self: Physical_Bone3d,
    angular_damp_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_angular_damp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    angular_damp_ := angular_damp_
    args := []__bindgen_gde.TypePtr {
        &angular_damp_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_angular_damp :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_angular_damp", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_linear_velocity :: proc "contextless" (
    self: Physical_Bone3d,
    linear_velocity_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_linear_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    linear_velocity_ := linear_velocity_
    args := []__bindgen_gde.TypePtr {
        &linear_velocity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_linear_velocity :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_linear_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_angular_velocity :: proc "contextless" (
    self: Physical_Bone3d,
    angular_velocity_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_angular_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    angular_velocity_ := angular_velocity_
    args := []__bindgen_gde.TypePtr {
        &angular_velocity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_get_angular_velocity :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_angular_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_use_custom_integrator :: proc "contextless" (
    self: Physical_Bone3d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_custom_integrator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_is_using_custom_integrator :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_custom_integrator", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2240911060)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physical_bone3d_set_can_sleep :: proc "contextless" (
    self: Physical_Bone3d,
    able_to_sleep_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_can_sleep", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    able_to_sleep_ := able_to_sleep_
    args := []__bindgen_gde.TypePtr {
        &able_to_sleep_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physical_bone3d_is_able_to_sleep :: proc "contextless" (
    self: Physical_Bone3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_able_to_sleep", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
physical_bone3d_get_custom_integrator :: proc "contextless" (self: Physical_Bone3d) -> Bool {
    return physical_bone3d_is_using_custom_integrator(self)
}
physical_bone3d_set_custom_integrator :: proc "contextless" (self: Physical_Bone3d, value: Bool) {
    physical_bone3d_set_use_custom_integrator(self, value)
}
physical_bone3d_get_can_sleep :: proc "contextless" (self: Physical_Bone3d) -> Bool {
    return physical_bone3d_is_able_to_sleep(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
physical_bone3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PhysicalBone3D", true)
}

@(private = "file")
__class_name: String_Name