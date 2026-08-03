package godot

import __bindgen_gde "godot:gdext"

Rigid_Body3d_Constants :: enum {
}
Rigid_Body3d_Freeze_Mode :: enum int {
    Freeze_Mode_Static = 0,
    Freeze_Mode_Kinematic = 1,
}
Rigid_Body3d_Center_Of_Mass_Mode :: enum int {
    Center_Of_Mass_Mode_Auto = 0,
    Center_Of_Mass_Mode_Custom = 1,
}
Rigid_Body3d_Damp_Mode :: enum int {
    Damp_Mode_Combine = 0,
    Damp_Mode_Replace = 1,
}



rigid_body3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

rigid_body3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_rigid_body3d :: proc "contextless" () -> Rigid_Body3d {
    return cast(Rigid_Body3d)__bindgen_gde.classdb_construct_object(rigid_body3d_name_ref())
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

rigid_body3d__integrate_forces :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_set_mass :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_get_mass :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_set_inertia :: proc "contextless" (
    self: Rigid_Body3d,
    inertia_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_inertia", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    inertia_ := inertia_
    args := []__bindgen_gde.TypePtr {
        &inertia_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_get_inertia :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_inertia", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_center_of_mass_mode :: proc "contextless" (
    self: Rigid_Body3d,
    mode_: Rigid_Body3d_Center_Of_Mass_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_center_of_mass_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3625866032)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_get_center_of_mass_mode :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Rigid_Body3d_Center_Of_Mass_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center_of_mass_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 237405040)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_center_of_mass :: proc "contextless" (
    self: Rigid_Body3d,
    center_of_mass_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_center_of_mass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    center_of_mass_ := center_of_mass_
    args := []__bindgen_gde.TypePtr {
        &center_of_mass_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_get_center_of_mass :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center_of_mass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_physics_material_override :: proc "contextless" (
    self: Rigid_Body3d,
    physics_material_override_: Physics_Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_physics_material_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1784508650)
    }
    self := self
    physics_material_override_ := physics_material_override_
    args := []__bindgen_gde.TypePtr {
        &physics_material_override_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_get_physics_material_override :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Physics_Material) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_physics_material_override", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2521850424)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_linear_velocity :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_get_linear_velocity :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_set_angular_velocity :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_get_angular_velocity :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_get_inverse_inertia_tensor :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Basis) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_inverse_inertia_tensor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2716978435)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_gravity_scale :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_get_gravity_scale :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_set_linear_damp_mode :: proc "contextless" (
    self: Rigid_Body3d,
    linear_damp_mode_: Rigid_Body3d_Damp_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_linear_damp_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1802035050)
    }
    self := self
    linear_damp_mode_ := linear_damp_mode_
    args := []__bindgen_gde.TypePtr {
        &linear_damp_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_get_linear_damp_mode :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Rigid_Body3d_Damp_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_linear_damp_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1366206940)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_angular_damp_mode :: proc "contextless" (
    self: Rigid_Body3d,
    angular_damp_mode_: Rigid_Body3d_Damp_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_angular_damp_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1802035050)
    }
    self := self
    angular_damp_mode_ := angular_damp_mode_
    args := []__bindgen_gde.TypePtr {
        &angular_damp_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_get_angular_damp_mode :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Rigid_Body3d_Damp_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_angular_damp_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1366206940)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_linear_damp :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_get_linear_damp :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_set_angular_damp :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_get_angular_damp :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_set_max_contacts_reported :: proc "contextless" (
    self: Rigid_Body3d,
    amount_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_contacts_reported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_get_max_contacts_reported :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_contacts_reported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_get_contact_count :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_contact_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_use_custom_integrator :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_is_using_custom_integrator :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_set_contact_monitor :: proc "contextless" (
    self: Rigid_Body3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_contact_monitor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_is_contact_monitor_enabled :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_contact_monitor_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_use_continuous_collision_detection :: proc "contextless" (
    self: Rigid_Body3d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_continuous_collision_detection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_is_using_continuous_collision_detection :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_continuous_collision_detection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_axis_velocity :: proc "contextless" (
    self: Rigid_Body3d,
    axis_velocity_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_axis_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    axis_velocity_ := axis_velocity_
    args := []__bindgen_gde.TypePtr {
        &axis_velocity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_apply_central_impulse :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_apply_impulse :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_apply_torque_impulse :: proc "contextless" (
    self: Rigid_Body3d,
    impulse_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("apply_torque_impulse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    impulse_ := impulse_
    args := []__bindgen_gde.TypePtr {
        &impulse_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_apply_central_force :: proc "contextless" (
    self: Rigid_Body3d,
    force_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("apply_central_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_apply_force :: proc "contextless" (
    self: Rigid_Body3d,
    force_: Vector3,
    position_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("apply_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2754756483)
    }
    self := self
    force_ := force_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &force_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_apply_torque :: proc "contextless" (
    self: Rigid_Body3d,
    torque_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("apply_torque", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    torque_ := torque_
    args := []__bindgen_gde.TypePtr {
        &torque_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_add_constant_central_force :: proc "contextless" (
    self: Rigid_Body3d,
    force_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_constant_central_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_add_constant_force :: proc "contextless" (
    self: Rigid_Body3d,
    force_: Vector3,
    position_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_constant_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2754756483)
    }
    self := self
    force_ := force_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &force_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_add_constant_torque :: proc "contextless" (
    self: Rigid_Body3d,
    torque_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_constant_torque", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    torque_ := torque_
    args := []__bindgen_gde.TypePtr {
        &torque_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_set_constant_force :: proc "contextless" (
    self: Rigid_Body3d,
    force_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_constant_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_get_constant_force :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_constant_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_constant_torque :: proc "contextless" (
    self: Rigid_Body3d,
    torque_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_constant_torque", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    torque_ := torque_
    args := []__bindgen_gde.TypePtr {
        &torque_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_get_constant_torque :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_constant_torque", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_sleeping :: proc "contextless" (
    self: Rigid_Body3d,
    sleeping_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sleeping", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    sleeping_ := sleeping_
    args := []__bindgen_gde.TypePtr {
        &sleeping_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_is_sleeping :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_sleeping", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_can_sleep :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_is_able_to_sleep :: proc "contextless" (
    self: Rigid_Body3d,
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

rigid_body3d_set_lock_rotation_enabled :: proc "contextless" (
    self: Rigid_Body3d,
    lock_rotation_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_lock_rotation_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    lock_rotation_ := lock_rotation_
    args := []__bindgen_gde.TypePtr {
        &lock_rotation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_is_lock_rotation_enabled :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_lock_rotation_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_freeze_enabled :: proc "contextless" (
    self: Rigid_Body3d,
    freeze_mode_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_freeze_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    freeze_mode_ := freeze_mode_
    args := []__bindgen_gde.TypePtr {
        &freeze_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_is_freeze_enabled :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_freeze_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_set_freeze_mode :: proc "contextless" (
    self: Rigid_Body3d,
    freeze_mode_: Rigid_Body3d_Freeze_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_freeze_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1319914653)
    }
    self := self
    freeze_mode_ := freeze_mode_
    args := []__bindgen_gde.TypePtr {
        &freeze_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

rigid_body3d_get_freeze_mode :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Rigid_Body3d_Freeze_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_freeze_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2008423905)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

rigid_body3d_get_colliding_bodies :: proc "contextless" (
    self: Rigid_Body3d,
) -> (ret: Typed_Array(Node3d)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_colliding_bodies", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
rigid_body3d_get_sleeping :: proc "contextless" (self: Rigid_Body3d) -> Bool {
    return rigid_body3d_is_sleeping(self)
}
rigid_body3d_get_can_sleep :: proc "contextless" (self: Rigid_Body3d) -> Bool {
    return rigid_body3d_is_able_to_sleep(self)
}
rigid_body3d_get_lock_rotation :: proc "contextless" (self: Rigid_Body3d) -> Bool {
    return rigid_body3d_is_lock_rotation_enabled(self)
}
rigid_body3d_set_lock_rotation :: proc "contextless" (self: Rigid_Body3d, value: Bool) {
    rigid_body3d_set_lock_rotation_enabled(self, value)
}
rigid_body3d_get_freeze :: proc "contextless" (self: Rigid_Body3d) -> Bool {
    return rigid_body3d_is_freeze_enabled(self)
}
rigid_body3d_set_freeze :: proc "contextless" (self: Rigid_Body3d, value: Bool) {
    rigid_body3d_set_freeze_enabled(self, value)
}
rigid_body3d_get_custom_integrator :: proc "contextless" (self: Rigid_Body3d) -> Bool {
    return rigid_body3d_is_using_custom_integrator(self)
}
rigid_body3d_set_custom_integrator :: proc "contextless" (self: Rigid_Body3d, value: Bool) {
    rigid_body3d_set_use_custom_integrator(self, value)
}
rigid_body3d_get_continuous_cd :: proc "contextless" (self: Rigid_Body3d) -> Bool {
    return rigid_body3d_is_using_continuous_collision_detection(self)
}
rigid_body3d_set_continuous_cd :: proc "contextless" (self: Rigid_Body3d, value: Bool) {
    rigid_body3d_set_use_continuous_collision_detection(self, value)
}
rigid_body3d_get_contact_monitor :: proc "contextless" (self: Rigid_Body3d) -> Bool {
    return rigid_body3d_is_contact_monitor_enabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
rigid_body3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("RigidBody3D", true)
}

@(private = "file")
__class_name: String_Name