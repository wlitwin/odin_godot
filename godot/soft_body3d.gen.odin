package godot

import __bindgen_gde "godot:gdext"

Soft_Body3d_Constants :: enum {
}
Soft_Body3d_Disable_Mode :: enum int {
    Disable_Mode_Remove = 0,
    Disable_Mode_Keep_Active = 1,
}



soft_body3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

soft_body3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_soft_body3d :: proc "contextless" () -> Soft_Body3d {
    return cast(Soft_Body3d)__bindgen_gde.classdb_construct_object(soft_body3d_name_ref())
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

soft_body3d_get_physics_rid :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_physics_rid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2944877500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_set_collision_mask :: proc "contextless" (
    self: Soft_Body3d,
    collision_mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    collision_mask_ := collision_mask_
    args := []__bindgen_gde.TypePtr {
        &collision_mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_get_collision_mask :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_set_collision_layer :: proc "contextless" (
    self: Soft_Body3d,
    collision_layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    collision_layer_ := collision_layer_
    args := []__bindgen_gde.TypePtr {
        &collision_layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_get_collision_layer :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_set_collision_mask_value :: proc "contextless" (
    self: Soft_Body3d,
    layer_number_: Int,
    value_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_mask_value", true)
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

soft_body3d_get_collision_mask_value :: proc "contextless" (
    self: Soft_Body3d,
    layer_number_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_mask_value", true)
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

soft_body3d_set_collision_layer_value :: proc "contextless" (
    self: Soft_Body3d,
    layer_number_: Int,
    value_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_layer_value", true)
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

soft_body3d_get_collision_layer_value :: proc "contextless" (
    self: Soft_Body3d,
    layer_number_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_layer_value", true)
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

soft_body3d_set_parent_collision_ignore :: proc "contextless" (
    self: Soft_Body3d,
    parent_collision_ignore_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_parent_collision_ignore", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1348162250)
    }
    self := self
    parent_collision_ignore_ := parent_collision_ignore_
    args := []__bindgen_gde.TypePtr {
        &parent_collision_ignore_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_get_parent_collision_ignore :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_parent_collision_ignore", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4075236667)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_set_disable_mode :: proc "contextless" (
    self: Soft_Body3d,
    mode_: Soft_Body3d_Disable_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_disable_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1104158384)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_get_disable_mode :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: Soft_Body3d_Disable_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_disable_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4135042476)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_get_collision_exceptions :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: Typed_Array(Physics_Body3d)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_exceptions", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2915620761)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_add_collision_exception_with :: proc "contextless" (
    self: Soft_Body3d,
    body_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_collision_exception_with", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_remove_collision_exception_with :: proc "contextless" (
    self: Soft_Body3d,
    body_: Node,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_collision_exception_with", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1078189570)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_set_simulation_precision :: proc "contextless" (
    self: Soft_Body3d,
    simulation_precision_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_simulation_precision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    simulation_precision_ := simulation_precision_
    args := []__bindgen_gde.TypePtr {
        &simulation_precision_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_get_simulation_precision :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_simulation_precision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_set_total_mass :: proc "contextless" (
    self: Soft_Body3d,
    mass_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_total_mass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    mass_ := mass_
    args := []__bindgen_gde.TypePtr {
        &mass_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_get_total_mass :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_total_mass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_set_linear_stiffness :: proc "contextless" (
    self: Soft_Body3d,
    linear_stiffness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_linear_stiffness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    linear_stiffness_ := linear_stiffness_
    args := []__bindgen_gde.TypePtr {
        &linear_stiffness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_get_linear_stiffness :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_linear_stiffness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_set_shrinking_factor :: proc "contextless" (
    self: Soft_Body3d,
    shrinking_factor_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shrinking_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    shrinking_factor_ := shrinking_factor_
    args := []__bindgen_gde.TypePtr {
        &shrinking_factor_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_get_shrinking_factor :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shrinking_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_set_pressure_coefficient :: proc "contextless" (
    self: Soft_Body3d,
    pressure_coefficient_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_pressure_coefficient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    pressure_coefficient_ := pressure_coefficient_
    args := []__bindgen_gde.TypePtr {
        &pressure_coefficient_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_get_pressure_coefficient :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pressure_coefficient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_set_damping_coefficient :: proc "contextless" (
    self: Soft_Body3d,
    damping_coefficient_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_damping_coefficient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    damping_coefficient_ := damping_coefficient_
    args := []__bindgen_gde.TypePtr {
        &damping_coefficient_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_get_damping_coefficient :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_damping_coefficient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_set_drag_coefficient :: proc "contextless" (
    self: Soft_Body3d,
    drag_coefficient_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_drag_coefficient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    drag_coefficient_ := drag_coefficient_
    args := []__bindgen_gde.TypePtr {
        &drag_coefficient_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_get_drag_coefficient :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_drag_coefficient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_get_point_transform :: proc "contextless" (
    self: Soft_Body3d,
    point_index_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 871989493)
    }
    self := self
    point_index_ := point_index_
    args := []__bindgen_gde.TypePtr {
        &point_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_apply_impulse :: proc "contextless" (
    self: Soft_Body3d,
    point_index_: Int,
    impulse_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("apply_impulse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1530502735)
    }
    self := self
    point_index_ := point_index_
    impulse_ := impulse_
    args := []__bindgen_gde.TypePtr {
        &point_index_,
        &impulse_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_apply_force :: proc "contextless" (
    self: Soft_Body3d,
    point_index_: Int,
    force_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("apply_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1530502735)
    }
    self := self
    point_index_ := point_index_
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &point_index_,
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_apply_central_impulse :: proc "contextless" (
    self: Soft_Body3d,
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

soft_body3d_apply_central_force :: proc "contextless" (
    self: Soft_Body3d,
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

soft_body3d_set_point_pinned :: proc "contextless" (
    self: Soft_Body3d,
    point_index_: Int,
    pinned_: Bool,
    attachment_path_: Node_Path,
    insert_at_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_point_pinned", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 528784402)
    }
    self := self
    point_index_ := point_index_
    pinned_ := pinned_
    attachment_path_ := attachment_path_
    insert_at_ := insert_at_
    args := []__bindgen_gde.TypePtr {
        &point_index_,
        &pinned_,
        &attachment_path_,
        &insert_at_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_is_point_pinned :: proc "contextless" (
    self: Soft_Body3d,
    point_index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_point_pinned", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    point_index_ := point_index_
    args := []__bindgen_gde.TypePtr {
        &point_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

soft_body3d_set_ray_pickable :: proc "contextless" (
    self: Soft_Body3d,
    ray_pickable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_ray_pickable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    ray_pickable_ := ray_pickable_
    args := []__bindgen_gde.TypePtr {
        &ray_pickable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

soft_body3d_is_ray_pickable :: proc "contextless" (
    self: Soft_Body3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_ray_pickable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
soft_body3d_get_ray_pickable :: proc "contextless" (self: Soft_Body3d) -> Bool {
    return soft_body3d_is_ray_pickable(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
soft_body3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SoftBody3D", true)
}

@(private = "file")
__class_name: String_Name