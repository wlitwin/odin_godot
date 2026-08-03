package godot

import __bindgen_gde "godot:gdext"

Gpu_Particles3d_Constants :: enum {
    MAX_DRAW_PASSES = 4,
}
Gpu_Particles3d_Draw_Order :: enum int {
    Draw_Order_Index = 0,
    Draw_Order_Lifetime = 1,
    Draw_Order_Reverse_Lifetime = 2,
    Draw_Order_View_Depth = 3,
}
Gpu_Particles3d_Emit_Flags :: enum int {
    Emit_Flag_Position = 1,
    Emit_Flag_Rotation_Scale = 2,
    Emit_Flag_Velocity = 4,
    Emit_Flag_Color = 8,
    Emit_Flag_Custom = 16,
}
Gpu_Particles3d_Transform_Align :: enum int {
    Transform_Align_Disabled = 0,
    Transform_Align_Z_Billboard = 1,
    Transform_Align_Y_To_Velocity = 2,
    Transform_Align_Z_Billboard_Y_To_Velocity = 3,
    Transform_Align_Local_Billboard = 4,
}



gpu_particles3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

gpu_particles3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_gpu_particles3d :: proc "contextless" () -> Gpu_Particles3d {
    return cast(Gpu_Particles3d)__bindgen_gde.classdb_construct_object(gpu_particles3d_name_ref())
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

gpu_particles3d_set_emitting :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_amount :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_lifetime :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_one_shot :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_pre_process_time :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_explosiveness_ratio :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_randomness_ratio :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_visibility_aabb :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_use_local_coordinates :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_fixed_fps :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_fractional_delta :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_interpolate :: proc "contextless" (
    self: Gpu_Particles3d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_interpolate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_set_process_material :: proc "contextless" (
    self: Gpu_Particles3d,
    material_: Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_process_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2757459619)
    }
    self := self
    material_ := material_
    args := []__bindgen_gde.TypePtr {
        &material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_set_speed_scale :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_collision_base_size :: proc "contextless" (
    self: Gpu_Particles3d,
    size_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_base_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_set_interp_to_end :: proc "contextless" (
    self: Gpu_Particles3d,
    interp_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_interp_to_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    interp_ := interp_
    args := []__bindgen_gde.TypePtr {
        &interp_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_is_emitting :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_amount :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_lifetime :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_one_shot :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_pre_process_time :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_explosiveness_ratio :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_randomness_ratio :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_visibility_aabb :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_use_local_coordinates :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_fixed_fps :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_fractional_delta :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_interpolate :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_interpolate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_get_process_material :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: Material) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_process_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 5934680)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_get_speed_scale :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_collision_base_size :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_base_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_get_interp_to_end :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_interp_to_end", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_set_use_fixed_seed :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_use_fixed_seed :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_seed :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_get_seed :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_draw_order :: proc "contextless" (
    self: Gpu_Particles3d,
    order_: Gpu_Particles3d_Draw_Order,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_order", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1208074815)
    }
    self := self
    order_ := order_
    args := []__bindgen_gde.TypePtr {
        &order_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_get_draw_order :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: Gpu_Particles3d_Draw_Order) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_draw_order", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3770381780)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_set_draw_passes :: proc "contextless" (
    self: Gpu_Particles3d,
    passes_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_passes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    passes_ := passes_
    args := []__bindgen_gde.TypePtr {
        &passes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_set_draw_pass_mesh :: proc "contextless" (
    self: Gpu_Particles3d,
    pass_: Int,
    mesh_: Mesh,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_pass_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 969122797)
    }
    self := self
    pass_ := pass_
    mesh_ := mesh_
    args := []__bindgen_gde.TypePtr {
        &pass_,
        &mesh_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_get_draw_passes :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_draw_passes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_get_draw_pass_mesh :: proc "contextless" (
    self: Gpu_Particles3d,
    pass_: Int,
) -> (ret: Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_draw_pass_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1576363275)
    }
    self := self
    pass_ := pass_
    args := []__bindgen_gde.TypePtr {
        &pass_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_set_skin :: proc "contextless" (
    self: Gpu_Particles3d,
    skin_: Skin,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_skin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3971435618)
    }
    self := self
    skin_ := skin_
    args := []__bindgen_gde.TypePtr {
        &skin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_get_skin :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: Skin) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2074563878)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_restart :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_capture_aabb :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_sub_emitter :: proc "contextless" (
    self: Gpu_Particles3d,
    path_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sub_emitter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1348162250)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_get_sub_emitter :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sub_emitter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4075236667)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_emit_particle :: proc "contextless" (
    self: Gpu_Particles3d,
    xform_: Transform3d,
    velocity_: Vector3,
    color_: Color,
    custom_: Color,
    flags_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("emit_particle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 992173727)
    }
    self := self
    xform_ := xform_
    velocity_ := velocity_
    color_ := color_
    custom_ := custom_
    flags_ := flags_
    args := []__bindgen_gde.TypePtr {
        &xform_,
        &velocity_,
        &color_,
        &custom_,
        &flags_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_set_trail_enabled :: proc "contextless" (
    self: Gpu_Particles3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_trail_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_set_trail_lifetime :: proc "contextless" (
    self: Gpu_Particles3d,
    secs_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_trail_lifetime", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    secs_ := secs_
    args := []__bindgen_gde.TypePtr {
        &secs_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_is_trail_enabled :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_trail_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_get_trail_lifetime :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_trail_lifetime", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_set_transform_align :: proc "contextless" (
    self: Gpu_Particles3d,
    align_: Gpu_Particles3d_Transform_Align,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transform_align", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3892425954)
    }
    self := self
    align_ := align_
    args := []__bindgen_gde.TypePtr {
        &align_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_get_transform_align :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: Gpu_Particles3d_Transform_Align) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transform_align", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2100992166)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_set_transform_align_channel_filter :: proc "contextless" (
    self: Gpu_Particles3d,
    channel_filter_: Rendering_Server_Particles_Transform_Align_Custom_Src,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transform_align_channel_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 540833286)
    }
    self := self
    channel_filter_ := channel_filter_
    args := []__bindgen_gde.TypePtr {
        &channel_filter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_get_transform_align_channel_filter :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: Rendering_Server_Particles_Transform_Align_Custom_Src) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transform_align_channel_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1664431231)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_set_transform_align_axis :: proc "contextless" (
    self: Gpu_Particles3d,
    align_: Rendering_Server_Particles_Transform_Align_Axis,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transform_align_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3781785913)
    }
    self := self
    align_ := align_
    args := []__bindgen_gde.TypePtr {
        &align_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_get_transform_align_axis :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: Rendering_Server_Particles_Transform_Align_Axis) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transform_align_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2427180841)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_convert_from_particles :: proc "contextless" (
    self: Gpu_Particles3d,
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

gpu_particles3d_set_amount_ratio :: proc "contextless" (
    self: Gpu_Particles3d,
    ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_amount_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    ratio_ := ratio_
    args := []__bindgen_gde.TypePtr {
        &ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gpu_particles3d_get_amount_ratio :: proc "contextless" (
    self: Gpu_Particles3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_amount_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gpu_particles3d_request_particles_process :: proc "contextless" (
    self: Gpu_Particles3d,
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


// properties
gpu_particles3d_get_emitting :: proc "contextless" (self: Gpu_Particles3d) -> Bool {
    return gpu_particles3d_is_emitting(self)
}
gpu_particles3d_get_preprocess :: proc "contextless" (self: Gpu_Particles3d) -> f64 {
    return gpu_particles3d_get_pre_process_time(self)
}
gpu_particles3d_set_preprocess :: proc "contextless" (self: Gpu_Particles3d, value: f64) {
    gpu_particles3d_set_pre_process_time(self, value)
}
gpu_particles3d_get_explosiveness :: proc "contextless" (self: Gpu_Particles3d) -> f64 {
    return gpu_particles3d_get_explosiveness_ratio(self)
}
gpu_particles3d_set_explosiveness :: proc "contextless" (self: Gpu_Particles3d, value: f64) {
    gpu_particles3d_set_explosiveness_ratio(self, value)
}
gpu_particles3d_get_randomness :: proc "contextless" (self: Gpu_Particles3d) -> f64 {
    return gpu_particles3d_get_randomness_ratio(self)
}
gpu_particles3d_set_randomness :: proc "contextless" (self: Gpu_Particles3d, value: f64) {
    gpu_particles3d_set_randomness_ratio(self, value)
}
gpu_particles3d_get_fract_delta :: proc "contextless" (self: Gpu_Particles3d) -> Bool {
    return gpu_particles3d_get_fractional_delta(self)
}
gpu_particles3d_set_fract_delta :: proc "contextless" (self: Gpu_Particles3d, value: Bool) {
    gpu_particles3d_set_fractional_delta(self, value)
}
gpu_particles3d_get_local_coords :: proc "contextless" (self: Gpu_Particles3d) -> Bool {
    return gpu_particles3d_get_use_local_coordinates(self)
}
gpu_particles3d_set_local_coords :: proc "contextless" (self: Gpu_Particles3d, value: Bool) {
    gpu_particles3d_set_use_local_coordinates(self, value)
}
gpu_particles3d_get_trail_enabled :: proc "contextless" (self: Gpu_Particles3d) -> Bool {
    return gpu_particles3d_is_trail_enabled(self)
}
gpu_particles3d_get_draw_pass_1 :: proc "contextless" (self: Gpu_Particles3d) -> Mesh {
    return gpu_particles3d_get_draw_pass_mesh(self, Int(0))
}
gpu_particles3d_set_draw_pass_1 :: proc "contextless" (self: Gpu_Particles3d, value: Mesh) {
    gpu_particles3d_set_draw_pass_mesh(self, Int(0), value)
}
gpu_particles3d_get_draw_pass_2 :: proc "contextless" (self: Gpu_Particles3d) -> Mesh {
    return gpu_particles3d_get_draw_pass_mesh(self, Int(1))
}
gpu_particles3d_set_draw_pass_2 :: proc "contextless" (self: Gpu_Particles3d, value: Mesh) {
    gpu_particles3d_set_draw_pass_mesh(self, Int(1), value)
}
gpu_particles3d_get_draw_pass_3 :: proc "contextless" (self: Gpu_Particles3d) -> Mesh {
    return gpu_particles3d_get_draw_pass_mesh(self, Int(2))
}
gpu_particles3d_set_draw_pass_3 :: proc "contextless" (self: Gpu_Particles3d, value: Mesh) {
    gpu_particles3d_set_draw_pass_mesh(self, Int(2), value)
}
gpu_particles3d_get_draw_pass_4 :: proc "contextless" (self: Gpu_Particles3d) -> Mesh {
    return gpu_particles3d_get_draw_pass_mesh(self, Int(3))
}
gpu_particles3d_set_draw_pass_4 :: proc "contextless" (self: Gpu_Particles3d, value: Mesh) {
    gpu_particles3d_set_draw_pass_mesh(self, Int(3), value)
}
gpu_particles3d_get_draw_skin :: proc "contextless" (self: Gpu_Particles3d) -> Skin {
    return gpu_particles3d_get_skin(self)
}
gpu_particles3d_set_draw_skin :: proc "contextless" (self: Gpu_Particles3d, value: Skin) {
    gpu_particles3d_set_skin(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
gpu_particles3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GPUParticles3D", true)
}

@(private = "file")
__class_name: String_Name