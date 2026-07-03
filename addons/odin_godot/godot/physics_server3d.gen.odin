package godot

import __bindgen_gde "godot:gdext"

Physics_Server3d_Constants :: enum {
}
Physics_Server3d_Joint_Type :: enum int {
    Joint_Type_Pin = 0,
    Joint_Type_Hinge = 1,
    Joint_Type_Slider = 2,
    Joint_Type_Cone_Twist = 3,
    Joint_Type_6dof = 4,
    Joint_Type_Max = 5,
}
Physics_Server3d_Pin_Joint_Param :: enum int {
    Pin_Joint_Bias = 0,
    Pin_Joint_Damping = 1,
    Pin_Joint_Impulse_Clamp = 2,
}
Physics_Server3d_Hinge_Joint_Param :: enum int {
    Hinge_Joint_Bias = 0,
    Hinge_Joint_Limit_Upper = 1,
    Hinge_Joint_Limit_Lower = 2,
    Hinge_Joint_Limit_Bias = 3,
    Hinge_Joint_Limit_Softness = 4,
    Hinge_Joint_Limit_Relaxation = 5,
    Hinge_Joint_Motor_Target_Velocity = 6,
    Hinge_Joint_Motor_Max_Impulse = 7,
}
Physics_Server3d_Hinge_Joint_Flag :: enum int {
    Hinge_Joint_Flag_Use_Limit = 0,
    Hinge_Joint_Flag_Enable_Motor = 1,
}
Physics_Server3d_Slider_Joint_Param :: enum int {
    Slider_Joint_Linear_Limit_Upper = 0,
    Slider_Joint_Linear_Limit_Lower = 1,
    Slider_Joint_Linear_Limit_Softness = 2,
    Slider_Joint_Linear_Limit_Restitution = 3,
    Slider_Joint_Linear_Limit_Damping = 4,
    Slider_Joint_Linear_Motion_Softness = 5,
    Slider_Joint_Linear_Motion_Restitution = 6,
    Slider_Joint_Linear_Motion_Damping = 7,
    Slider_Joint_Linear_Orthogonal_Softness = 8,
    Slider_Joint_Linear_Orthogonal_Restitution = 9,
    Slider_Joint_Linear_Orthogonal_Damping = 10,
    Slider_Joint_Angular_Limit_Upper = 11,
    Slider_Joint_Angular_Limit_Lower = 12,
    Slider_Joint_Angular_Limit_Softness = 13,
    Slider_Joint_Angular_Limit_Restitution = 14,
    Slider_Joint_Angular_Limit_Damping = 15,
    Slider_Joint_Angular_Motion_Softness = 16,
    Slider_Joint_Angular_Motion_Restitution = 17,
    Slider_Joint_Angular_Motion_Damping = 18,
    Slider_Joint_Angular_Orthogonal_Softness = 19,
    Slider_Joint_Angular_Orthogonal_Restitution = 20,
    Slider_Joint_Angular_Orthogonal_Damping = 21,
    Slider_Joint_Max = 22,
}
Physics_Server3d_Cone_Twist_Joint_Param :: enum int {
    Cone_Twist_Joint_Swing_Span = 0,
    Cone_Twist_Joint_Twist_Span = 1,
    Cone_Twist_Joint_Bias = 2,
    Cone_Twist_Joint_Softness = 3,
    Cone_Twist_Joint_Relaxation = 4,
}
Physics_Server3dg6dof_Joint_Axis_Param :: enum int {
    G6dof_Joint_Linear_Lower_Limit = 0,
    G6dof_Joint_Linear_Upper_Limit = 1,
    G6dof_Joint_Linear_Limit_Softness = 2,
    G6dof_Joint_Linear_Restitution = 3,
    G6dof_Joint_Linear_Damping = 4,
    G6dof_Joint_Linear_Motor_Target_Velocity = 5,
    G6dof_Joint_Linear_Motor_Force_Limit = 6,
    G6dof_Joint_Linear_Spring_Stiffness = 7,
    G6dof_Joint_Linear_Spring_Damping = 8,
    G6dof_Joint_Linear_Spring_Equilibrium_Point = 9,
    G6dof_Joint_Angular_Lower_Limit = 10,
    G6dof_Joint_Angular_Upper_Limit = 11,
    G6dof_Joint_Angular_Limit_Softness = 12,
    G6dof_Joint_Angular_Damping = 13,
    G6dof_Joint_Angular_Restitution = 14,
    G6dof_Joint_Angular_Force_Limit = 15,
    G6dof_Joint_Angular_Erp = 16,
    G6dof_Joint_Angular_Motor_Target_Velocity = 17,
    G6dof_Joint_Angular_Motor_Force_Limit = 18,
    G6dof_Joint_Angular_Spring_Stiffness = 19,
    G6dof_Joint_Angular_Spring_Damping = 20,
    G6dof_Joint_Angular_Spring_Equilibrium_Point = 21,
    G6dof_Joint_Max = 22,
}
Physics_Server3dg6dof_Joint_Axis_Flag :: enum int {
    G6dof_Joint_Flag_Enable_Linear_Limit = 0,
    G6dof_Joint_Flag_Enable_Angular_Limit = 1,
    G6dof_Joint_Flag_Enable_Angular_Spring = 2,
    G6dof_Joint_Flag_Enable_Linear_Spring = 3,
    G6dof_Joint_Flag_Enable_Motor = 4,
    G6dof_Joint_Flag_Enable_Linear_Motor = 5,
    G6dof_Joint_Flag_Max = 6,
}
Physics_Server3d_Shape_Type :: enum int {
    Shape_World_Boundary = 0,
    Shape_Separation_Ray = 1,
    Shape_Sphere = 2,
    Shape_Box = 3,
    Shape_Capsule = 4,
    Shape_Cylinder = 5,
    Shape_Convex_Polygon = 6,
    Shape_Concave_Polygon = 7,
    Shape_Heightmap = 8,
    Shape_Soft_Body = 9,
    Shape_Custom = 10,
}
Physics_Server3d_Area_Parameter :: enum int {
    Area_Param_Gravity_Override_Mode = 0,
    Area_Param_Gravity = 1,
    Area_Param_Gravity_Vector = 2,
    Area_Param_Gravity_Is_Point = 3,
    Area_Param_Gravity_Point_Unit_Distance = 4,
    Area_Param_Linear_Damp_Override_Mode = 5,
    Area_Param_Linear_Damp = 6,
    Area_Param_Angular_Damp_Override_Mode = 7,
    Area_Param_Angular_Damp = 8,
    Area_Param_Priority = 9,
    Area_Param_Wind_Force_Magnitude = 10,
    Area_Param_Wind_Source = 11,
    Area_Param_Wind_Direction = 12,
    Area_Param_Wind_Attenuation_Factor = 13,
}
Physics_Server3d_Area_Space_Override_Mode :: enum int {
    Area_Space_Override_Disabled = 0,
    Area_Space_Override_Combine = 1,
    Area_Space_Override_Combine_Replace = 2,
    Area_Space_Override_Replace = 3,
    Area_Space_Override_Replace_Combine = 4,
}
Physics_Server3d_Body_Mode :: enum int {
    Body_Mode_Static = 0,
    Body_Mode_Kinematic = 1,
    Body_Mode_Rigid = 2,
    Body_Mode_Rigid_Linear = 3,
}
Physics_Server3d_Body_Parameter :: enum int {
    Body_Param_Bounce = 0,
    Body_Param_Friction = 1,
    Body_Param_Mass = 2,
    Body_Param_Inertia = 3,
    Body_Param_Center_Of_Mass = 4,
    Body_Param_Gravity_Scale = 5,
    Body_Param_Linear_Damp_Mode = 6,
    Body_Param_Angular_Damp_Mode = 7,
    Body_Param_Linear_Damp = 8,
    Body_Param_Angular_Damp = 9,
    Body_Param_Max = 10,
}
Physics_Server3d_Body_Damp_Mode :: enum int {
    Body_Damp_Mode_Combine = 0,
    Body_Damp_Mode_Replace = 1,
}
Physics_Server3d_Body_State :: enum int {
    Body_State_Transform = 0,
    Body_State_Linear_Velocity = 1,
    Body_State_Angular_Velocity = 2,
    Body_State_Sleeping = 3,
    Body_State_Can_Sleep = 4,
}
Physics_Server3d_Area_Body_Status :: enum int {
    Area_Body_Added = 0,
    Area_Body_Removed = 1,
}
Physics_Server3d_Process_Info :: enum int {
    Info_Active_Objects = 0,
    Info_Collision_Pairs = 1,
    Info_Island_Count = 2,
}
Physics_Server3d_Space_Parameter :: enum int {
    Space_Param_Contact_Recycle_Radius = 0,
    Space_Param_Contact_Max_Separation = 1,
    Space_Param_Contact_Max_Allowed_Penetration = 2,
    Space_Param_Contact_Default_Bias = 3,
    Space_Param_Body_Linear_Velocity_Sleep_Threshold = 4,
    Space_Param_Body_Angular_Velocity_Sleep_Threshold = 5,
    Space_Param_Body_Time_To_Sleep = 6,
    Space_Param_Solver_Iterations = 7,
}
Physics_Server3d_Body_Axis :: enum int {
    Body_Axis_Linear_X = 1,
    Body_Axis_Linear_Y = 2,
    Body_Axis_Linear_Z = 4,
    Body_Axis_Angular_X = 8,
    Body_Axis_Angular_Y = 16,
    Body_Axis_Angular_Z = 32,
}



physics_server3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

physics_server3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_physics_server3d :: proc "contextless" () -> Physics_Server3d {
    return __bindgen_gde.classdb_construct_object(physics_server3d_name_ref())
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

physics_server3d_world_boundary_shape_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("world_boundary_shape_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_separation_ray_shape_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("separation_ray_shape_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_sphere_shape_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sphere_shape_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_box_shape_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("box_shape_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_capsule_shape_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("capsule_shape_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_cylinder_shape_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cylinder_shape_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_convex_polygon_shape_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("convex_polygon_shape_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_concave_polygon_shape_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("concave_polygon_shape_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_heightmap_shape_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("heightmap_shape_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_custom_shape_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("custom_shape_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_shape_set_data :: proc "contextless" (
    self: Physics_Server3d,
    shape_: Rid,
    data_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shape_set_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3175752987)
    }
    self := self
    shape_ := shape_
    data_ := data_
    args := []__bindgen_gde.TypePtr {
        &shape_,
        &data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_shape_set_margin :: proc "contextless" (
    self: Physics_Server3d,
    shape_: Rid,
    margin_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shape_set_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    shape_ := shape_
    margin_ := margin_
    args := []__bindgen_gde.TypePtr {
        &shape_,
        &margin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_shape_get_type :: proc "contextless" (
    self: Physics_Server3d,
    shape_: Rid,
) -> (ret: Physics_Server3d_Shape_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shape_get_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3418923367)
    }
    self := self
    shape_ := shape_
    args := []__bindgen_gde.TypePtr {
        &shape_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_shape_get_data :: proc "contextless" (
    self: Physics_Server3d,
    shape_: Rid,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shape_get_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4171304767)
    }
    self := self
    shape_ := shape_
    args := []__bindgen_gde.TypePtr {
        &shape_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_shape_get_margin :: proc "contextless" (
    self: Physics_Server3d,
    shape_: Rid,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("shape_get_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866169185)
    }
    self := self
    shape_ := shape_
    args := []__bindgen_gde.TypePtr {
        &shape_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_space_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("space_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_space_set_active :: proc "contextless" (
    self: Physics_Server3d,
    space_: Rid,
    active_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("space_set_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    space_ := space_
    active_ := active_
    args := []__bindgen_gde.TypePtr {
        &space_,
        &active_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_space_is_active :: proc "contextless" (
    self: Physics_Server3d,
    space_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("space_is_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155700596)
    }
    self := self
    space_ := space_
    args := []__bindgen_gde.TypePtr {
        &space_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_space_set_param :: proc "contextless" (
    self: Physics_Server3d,
    space_: Rid,
    param_: Physics_Server3d_Space_Parameter,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("space_set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2406017470)
    }
    self := self
    space_ := space_
    param_ := param_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &space_,
        &param_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_space_get_param :: proc "contextless" (
    self: Physics_Server3d,
    space_: Rid,
    param_: Physics_Server3d_Space_Parameter,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("space_get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1523206731)
    }
    self := self
    space_ := space_
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &space_,
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_space_get_direct_state :: proc "contextless" (
    self: Physics_Server3d,
    space_: Rid,
) -> (ret: Physics_Direct_Space_State3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("space_get_direct_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2048616813)
    }
    self := self
    space_ := space_
    args := []__bindgen_gde.TypePtr {
        &space_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_area_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_area_set_space :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    space_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_set_space", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    area_ := area_
    space_ := space_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &space_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_get_space :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_get_space", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814569979)
    }
    self := self
    area_ := area_
    args := []__bindgen_gde.TypePtr {
        &area_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_area_add_shape :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    shape_: Rid,
    transform_: Transform3d,
    disabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_add_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3711419014)
    }
    self := self
    area_ := area_
    shape_ := shape_
    transform_ := transform_
    disabled_ := disabled_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &shape_,
        &transform_,
        &disabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_set_shape :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    shape_idx_: Int,
    shape_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_set_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2310537182)
    }
    self := self
    area_ := area_
    shape_idx_ := shape_idx_
    shape_ := shape_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &shape_idx_,
        &shape_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_set_shape_transform :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    shape_idx_: Int,
    transform_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_set_shape_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 675327471)
    }
    self := self
    area_ := area_
    shape_idx_ := shape_idx_
    transform_ := transform_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &shape_idx_,
        &transform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_set_shape_disabled :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    shape_idx_: Int,
    disabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_set_shape_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2658558584)
    }
    self := self
    area_ := area_
    shape_idx_ := shape_idx_
    disabled_ := disabled_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &shape_idx_,
        &disabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_get_shape_count :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_get_shape_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    area_ := area_
    args := []__bindgen_gde.TypePtr {
        &area_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_area_get_shape :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    shape_idx_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_get_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1066463050)
    }
    self := self
    area_ := area_
    shape_idx_ := shape_idx_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &shape_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_area_get_shape_transform :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    shape_idx_: Int,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_get_shape_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1050775521)
    }
    self := self
    area_ := area_
    shape_idx_ := shape_idx_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &shape_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_area_remove_shape :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    shape_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_remove_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    area_ := area_
    shape_idx_ := shape_idx_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &shape_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_clear_shapes :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_clear_shapes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    area_ := area_
    args := []__bindgen_gde.TypePtr {
        &area_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_set_collision_layer :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_set_collision_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    area_ := area_
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_get_collision_layer :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_get_collision_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    area_ := area_
    args := []__bindgen_gde.TypePtr {
        &area_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_area_set_collision_mask :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_set_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    area_ := area_
    mask_ := mask_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_get_collision_mask :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_get_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    area_ := area_
    args := []__bindgen_gde.TypePtr {
        &area_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_area_set_param :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    param_: Physics_Server3d_Area_Parameter,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2980114638)
    }
    self := self
    area_ := area_
    param_ := param_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &param_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_set_transform :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    transform_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_set_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3935195649)
    }
    self := self
    area_ := area_
    transform_ := transform_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &transform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_get_param :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    param_: Physics_Server3d_Area_Parameter,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 890056067)
    }
    self := self
    area_ := area_
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_area_get_transform :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_get_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1128465797)
    }
    self := self
    area_ := area_
    args := []__bindgen_gde.TypePtr {
        &area_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_area_attach_object_instance_id :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_attach_object_instance_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    area_ := area_
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_get_object_instance_id :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_get_object_instance_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    area_ := area_
    args := []__bindgen_gde.TypePtr {
        &area_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_area_set_monitor_callback :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_set_monitor_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3379118538)
    }
    self := self
    area_ := area_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_set_area_monitor_callback :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    callback_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_set_area_monitor_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3379118538)
    }
    self := self
    area_ := area_
    callback_ := callback_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &callback_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_set_monitorable :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    monitorable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_set_monitorable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    area_ := area_
    monitorable_ := monitorable_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &monitorable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_area_set_ray_pickable :: proc "contextless" (
    self: Physics_Server3d,
    area_: Rid,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("area_set_ray_pickable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    area_ := area_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &area_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_set_space :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    space_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_space", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    body_ := body_
    space_ := space_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &space_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_get_space :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_space", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814569979)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_set_mode :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    mode_: Physics_Server3d_Body_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 606803466)
    }
    self := self
    body_ := body_
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_get_mode :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: Physics_Server3d_Body_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2488819728)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_set_collision_layer :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_collision_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    body_ := body_
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_get_collision_layer :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_collision_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_set_collision_mask :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    body_ := body_
    mask_ := mask_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_get_collision_mask :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_set_collision_priority :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    priority_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_collision_priority", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    body_ := body_
    priority_ := priority_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &priority_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_get_collision_priority :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_collision_priority", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866169185)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_add_shape :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    shape_: Rid,
    transform_: Transform3d,
    disabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_add_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3711419014)
    }
    self := self
    body_ := body_
    shape_ := shape_
    transform_ := transform_
    disabled_ := disabled_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &shape_,
        &transform_,
        &disabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_set_shape :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    shape_idx_: Int,
    shape_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2310537182)
    }
    self := self
    body_ := body_
    shape_idx_ := shape_idx_
    shape_ := shape_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &shape_idx_,
        &shape_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_set_shape_transform :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    shape_idx_: Int,
    transform_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_shape_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 675327471)
    }
    self := self
    body_ := body_
    shape_idx_ := shape_idx_
    transform_ := transform_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &shape_idx_,
        &transform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_set_shape_disabled :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    shape_idx_: Int,
    disabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_shape_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2658558584)
    }
    self := self
    body_ := body_
    shape_idx_ := shape_idx_
    disabled_ := disabled_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &shape_idx_,
        &disabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_get_shape_count :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_shape_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_get_shape :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    shape_idx_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1066463050)
    }
    self := self
    body_ := body_
    shape_idx_ := shape_idx_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &shape_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_get_shape_transform :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    shape_idx_: Int,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_shape_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1050775521)
    }
    self := self
    body_ := body_
    shape_idx_ := shape_idx_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &shape_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_remove_shape :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    shape_idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_remove_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    body_ := body_
    shape_idx_ := shape_idx_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &shape_idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_clear_shapes :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_clear_shapes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_attach_object_instance_id :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_attach_object_instance_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    body_ := body_
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_get_object_instance_id :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_object_instance_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_set_enable_continuous_collision_detection :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_enable_continuous_collision_detection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    body_ := body_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_is_continuous_collision_detection_enabled :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_is_continuous_collision_detection_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155700596)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_set_param :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    param_: Physics_Server3d_Body_Parameter,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 910941953)
    }
    self := self
    body_ := body_
    param_ := param_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &param_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_get_param :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    param_: Physics_Server3d_Body_Parameter,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3385027841)
    }
    self := self
    body_ := body_
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_reset_mass_properties :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_reset_mass_properties", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_set_state :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    state_: Physics_Server3d_Body_State,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 599977762)
    }
    self := self
    body_ := body_
    state_ := state_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &state_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_get_state :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    state_: Physics_Server3d_Body_State,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1850449534)
    }
    self := self
    body_ := body_
    state_ := state_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &state_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_apply_central_impulse :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    impulse_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_apply_central_impulse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3227306858)
    }
    self := self
    body_ := body_
    impulse_ := impulse_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &impulse_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_apply_impulse :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    impulse_: Vector3,
    position_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_apply_impulse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 390416203)
    }
    self := self
    body_ := body_
    impulse_ := impulse_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &impulse_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_apply_torque_impulse :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    impulse_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_apply_torque_impulse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3227306858)
    }
    self := self
    body_ := body_
    impulse_ := impulse_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &impulse_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_apply_central_force :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    force_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_apply_central_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3227306858)
    }
    self := self
    body_ := body_
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_apply_force :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    force_: Vector3,
    position_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_apply_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 390416203)
    }
    self := self
    body_ := body_
    force_ := force_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &force_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_apply_torque :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    torque_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_apply_torque", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3227306858)
    }
    self := self
    body_ := body_
    torque_ := torque_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &torque_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_add_constant_central_force :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    force_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_add_constant_central_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3227306858)
    }
    self := self
    body_ := body_
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_add_constant_force :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    force_: Vector3,
    position_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_add_constant_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 390416203)
    }
    self := self
    body_ := body_
    force_ := force_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &force_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_add_constant_torque :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    torque_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_add_constant_torque", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3227306858)
    }
    self := self
    body_ := body_
    torque_ := torque_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &torque_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_set_constant_force :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    force_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_constant_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3227306858)
    }
    self := self
    body_ := body_
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_get_constant_force :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_constant_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 531438156)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_set_constant_torque :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    torque_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_constant_torque", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3227306858)
    }
    self := self
    body_ := body_
    torque_ := torque_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &torque_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_get_constant_torque :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_constant_torque", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 531438156)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_set_axis_velocity :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    axis_velocity_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_axis_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3227306858)
    }
    self := self
    body_ := body_
    axis_velocity_ := axis_velocity_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &axis_velocity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_set_axis_lock :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    axis_: Physics_Server3d_Body_Axis,
    lock_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_axis_lock", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2020836892)
    }
    self := self
    body_ := body_
    axis_ := axis_
    lock_ := lock_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &axis_,
        &lock_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_is_axis_locked :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    axis_: Physics_Server3d_Body_Axis,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_is_axis_locked", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 587853580)
    }
    self := self
    body_ := body_
    axis_ := axis_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &axis_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_add_collision_exception :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    excepted_body_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_add_collision_exception", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    body_ := body_
    excepted_body_ := excepted_body_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &excepted_body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_remove_collision_exception :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    excepted_body_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_remove_collision_exception", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    body_ := body_
    excepted_body_ := excepted_body_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &excepted_body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_set_max_contacts_reported :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    amount_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_max_contacts_reported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    body_ := body_
    amount_ := amount_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &amount_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_get_max_contacts_reported :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_max_contacts_reported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_set_omit_force_integration :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_omit_force_integration", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    body_ := body_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_is_omitting_force_integration :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_is_omitting_force_integration", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155700596)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_set_state_sync_callback :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    callable_: Callable,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_state_sync_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3379118538)
    }
    self := self
    body_ := body_
    callable_ := callable_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &callable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_set_force_integration_callback :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    callable_: Callable,
    userdata_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_force_integration_callback", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3059434249)
    }
    self := self
    body_ := body_
    callable_ := callable_
    userdata_ := userdata_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &callable_,
        &userdata_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_set_ray_pickable :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_set_ray_pickable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    body_ := body_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_body_test_motion :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    parameters_: Physics_Test_Motion_Parameters3d,
    result_: Physics_Test_Motion_Result3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_test_motion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1944921792)
    }
    self := self
    body_ := body_
    parameters_ := parameters_
    result_ := result_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &parameters_,
        &result_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_body_get_direct_state :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: Physics_Direct_Body_State3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("body_get_direct_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3029727957)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_update_rendering_server :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    rendering_server_handler_: Physics_Server3d_Rendering_Server_Handler,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_update_rendering_server", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2218179753)
    }
    self := self
    body_ := body_
    rendering_server_handler_ := rendering_server_handler_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &rendering_server_handler_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_set_space :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    space_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_space", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    body_ := body_
    space_ := space_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &space_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_get_space :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_get_space", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814569979)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_set_mesh :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    mesh_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    body_ := body_
    mesh_ := mesh_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &mesh_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_get_bounds :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: Aabb) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_get_bounds", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 974181306)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_set_collision_layer :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_collision_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    body_ := body_
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_get_collision_layer :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_get_collision_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_set_collision_mask :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    body_ := body_
    mask_ := mask_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_get_collision_mask :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_get_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_add_collision_exception :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    body_b_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_add_collision_exception", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    body_ := body_
    body_b_ := body_b_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &body_b_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_remove_collision_exception :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    body_b_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_remove_collision_exception", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 395945892)
    }
    self := self
    body_ := body_
    body_b_ := body_b_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &body_b_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_set_state :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    state_: Physics_Server3d_Body_State,
    variant_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 599977762)
    }
    self := self
    body_ := body_
    state_ := state_
    variant_ := variant_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &state_,
        &variant_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_get_state :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    state_: Physics_Server3d_Body_State,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_get_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1850449534)
    }
    self := self
    body_ := body_
    state_ := state_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &state_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_set_transform :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    transform_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3935195649)
    }
    self := self
    body_ := body_
    transform_ := transform_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &transform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_set_ray_pickable :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_ray_pickable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    body_ := body_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_set_simulation_precision :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    simulation_precision_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_simulation_precision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    body_ := body_
    simulation_precision_ := simulation_precision_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &simulation_precision_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_get_simulation_precision :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_get_simulation_precision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_set_total_mass :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    total_mass_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_total_mass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    body_ := body_
    total_mass_ := total_mass_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &total_mass_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_get_total_mass :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_get_total_mass", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866169185)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_set_linear_stiffness :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    stiffness_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_linear_stiffness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    body_ := body_
    stiffness_ := stiffness_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &stiffness_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_get_linear_stiffness :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_get_linear_stiffness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866169185)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_set_shrinking_factor :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    shrinking_factor_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_shrinking_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    body_ := body_
    shrinking_factor_ := shrinking_factor_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &shrinking_factor_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_get_shrinking_factor :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_get_shrinking_factor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866169185)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_set_pressure_coefficient :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    pressure_coefficient_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_pressure_coefficient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    body_ := body_
    pressure_coefficient_ := pressure_coefficient_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &pressure_coefficient_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_get_pressure_coefficient :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_get_pressure_coefficient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866169185)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_set_damping_coefficient :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    damping_coefficient_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_damping_coefficient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    body_ := body_
    damping_coefficient_ := damping_coefficient_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &damping_coefficient_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_get_damping_coefficient :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_get_damping_coefficient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866169185)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_set_drag_coefficient :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    drag_coefficient_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_set_drag_coefficient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1794382983)
    }
    self := self
    body_ := body_
    drag_coefficient_ := drag_coefficient_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &drag_coefficient_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_get_drag_coefficient :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_get_drag_coefficient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 866169185)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_move_point :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    point_index_: Int,
    global_position_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_move_point", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 831953689)
    }
    self := self
    body_ := body_
    point_index_ := point_index_
    global_position_ := global_position_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &point_index_,
        &global_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_get_point_global_position :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    point_index_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_get_point_global_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3440143363)
    }
    self := self
    body_ := body_
    point_index_ := point_index_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &point_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_remove_all_pinned_points :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_remove_all_pinned_points", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_pin_point :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    point_index_: Int,
    pin_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_pin_point", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2658558584)
    }
    self := self
    body_ := body_
    point_index_ := point_index_
    pin_ := pin_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &point_index_,
        &pin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_is_point_pinned :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    point_index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_is_point_pinned", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3120086654)
    }
    self := self
    body_ := body_
    point_index_ := point_index_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &point_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_soft_body_apply_point_impulse :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    point_index_: Int,
    impulse_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_apply_point_impulse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 831953689)
    }
    self := self
    body_ := body_
    point_index_ := point_index_
    impulse_ := impulse_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &point_index_,
        &impulse_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_apply_point_force :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    point_index_: Int,
    force_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_apply_point_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 831953689)
    }
    self := self
    body_ := body_
    point_index_ := point_index_
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &point_index_,
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_apply_central_impulse :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    impulse_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_apply_central_impulse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3227306858)
    }
    self := self
    body_ := body_
    impulse_ := impulse_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &impulse_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_soft_body_apply_central_force :: proc "contextless" (
    self: Physics_Server3d,
    body_: Rid,
    force_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("soft_body_apply_central_force", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3227306858)
    }
    self := self
    body_ := body_
    force_ := force_
    args := []__bindgen_gde.TypePtr {
        &body_,
        &force_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_joint_create :: proc "contextless" (
    self: Physics_Server3d,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("joint_create", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 529393457)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_joint_clear :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("joint_clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_joint_make_pin :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    body_A_: Rid,
    local_A_: Vector3,
    body_B_: Rid,
    local_B_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("joint_make_pin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4280171926)
    }
    self := self
    joint_ := joint_
    body_A_ := body_A_
    local_A_ := local_A_
    body_B_ := body_B_
    local_B_ := local_B_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &body_A_,
        &local_A_,
        &body_B_,
        &local_B_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_pin_joint_set_param :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    param_: Physics_Server3d_Pin_Joint_Param,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pin_joint_set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 810685294)
    }
    self := self
    joint_ := joint_
    param_ := param_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &param_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_pin_joint_get_param :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    param_: Physics_Server3d_Pin_Joint_Param,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pin_joint_get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2817972347)
    }
    self := self
    joint_ := joint_
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_pin_joint_set_local_a :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    local_A_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pin_joint_set_local_a", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3227306858)
    }
    self := self
    joint_ := joint_
    local_A_ := local_A_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &local_A_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_pin_joint_get_local_a :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pin_joint_get_local_a", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 531438156)
    }
    self := self
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_pin_joint_set_local_b :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    local_B_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pin_joint_set_local_b", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3227306858)
    }
    self := self
    joint_ := joint_
    local_B_ := local_B_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &local_B_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_pin_joint_get_local_b :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("pin_joint_get_local_b", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 531438156)
    }
    self := self
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_joint_make_hinge :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    body_A_: Rid,
    hinge_A_: Transform3d,
    body_B_: Rid,
    hinge_B_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("joint_make_hinge", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1684107643)
    }
    self := self
    joint_ := joint_
    body_A_ := body_A_
    hinge_A_ := hinge_A_
    body_B_ := body_B_
    hinge_B_ := hinge_B_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &body_A_,
        &hinge_A_,
        &body_B_,
        &hinge_B_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_hinge_joint_set_param :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    param_: Physics_Server3d_Hinge_Joint_Param,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hinge_joint_set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3165502333)
    }
    self := self
    joint_ := joint_
    param_ := param_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &param_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_hinge_joint_get_param :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    param_: Physics_Server3d_Hinge_Joint_Param,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hinge_joint_get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2129207581)
    }
    self := self
    joint_ := joint_
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_hinge_joint_set_flag :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    flag_: Physics_Server3d_Hinge_Joint_Flag,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hinge_joint_set_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1601626188)
    }
    self := self
    joint_ := joint_
    flag_ := flag_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &flag_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_hinge_joint_get_flag :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    flag_: Physics_Server3d_Hinge_Joint_Flag,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hinge_joint_get_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4165147865)
    }
    self := self
    joint_ := joint_
    flag_ := flag_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &flag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_joint_make_slider :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    body_A_: Rid,
    local_ref_A_: Transform3d,
    body_B_: Rid,
    local_ref_B_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("joint_make_slider", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1684107643)
    }
    self := self
    joint_ := joint_
    body_A_ := body_A_
    local_ref_A_ := local_ref_A_
    body_B_ := body_B_
    local_ref_B_ := local_ref_B_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &body_A_,
        &local_ref_A_,
        &body_B_,
        &local_ref_B_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_slider_joint_set_param :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    param_: Physics_Server3d_Slider_Joint_Param,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("slider_joint_set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2264833593)
    }
    self := self
    joint_ := joint_
    param_ := param_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &param_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_slider_joint_get_param :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    param_: Physics_Server3d_Slider_Joint_Param,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("slider_joint_get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3498644957)
    }
    self := self
    joint_ := joint_
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_joint_make_cone_twist :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    body_A_: Rid,
    local_ref_A_: Transform3d,
    body_B_: Rid,
    local_ref_B_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("joint_make_cone_twist", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1684107643)
    }
    self := self
    joint_ := joint_
    body_A_ := body_A_
    local_ref_A_ := local_ref_A_
    body_B_ := body_B_
    local_ref_B_ := local_ref_B_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &body_A_,
        &local_ref_A_,
        &body_B_,
        &local_ref_B_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_cone_twist_joint_set_param :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    param_: Physics_Server3d_Cone_Twist_Joint_Param,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cone_twist_joint_set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 808587618)
    }
    self := self
    joint_ := joint_
    param_ := param_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &param_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_cone_twist_joint_get_param :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    param_: Physics_Server3d_Cone_Twist_Joint_Param,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cone_twist_joint_get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1134789658)
    }
    self := self
    joint_ := joint_
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_joint_get_type :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
) -> (ret: Physics_Server3d_Joint_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("joint_get_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4290791900)
    }
    self := self
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_joint_set_solver_priority :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    priority_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("joint_set_solver_priority", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3411492887)
    }
    self := self
    joint_ := joint_
    priority_ := priority_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &priority_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_joint_get_solver_priority :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("joint_get_solver_priority", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2198884583)
    }
    self := self
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_joint_disable_collisions_between_bodies :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    disable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("joint_disable_collisions_between_bodies", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1265174801)
    }
    self := self
    joint_ := joint_
    disable_ := disable_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &disable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_joint_is_disabled_collisions_between_bodies :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("joint_is_disabled_collisions_between_bodies", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4155700596)
    }
    self := self
    joint_ := joint_
    args := []__bindgen_gde.TypePtr {
        &joint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_joint_make_generic_6dof :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    body_A_: Rid,
    local_ref_A_: Transform3d,
    body_B_: Rid,
    local_ref_B_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("joint_make_generic_6dof", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1684107643)
    }
    self := self
    joint_ := joint_
    body_A_ := body_A_
    local_ref_A_ := local_ref_A_
    body_B_ := body_B_
    local_ref_B_ := local_ref_B_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &body_A_,
        &local_ref_A_,
        &body_B_,
        &local_ref_B_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_generic_6dof_joint_set_param :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    axis_: Vector3_Vector3_Axis,
    param_: Physics_Server3dg6dof_Joint_Axis_Param,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generic_6dof_joint_set_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2600081391)
    }
    self := self
    joint_ := joint_
    axis_ := axis_
    param_ := param_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &axis_,
        &param_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_generic_6dof_joint_get_param :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    axis_: Vector3_Vector3_Axis,
    param_: Physics_Server3dg6dof_Joint_Axis_Param,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generic_6dof_joint_get_param", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 467122058)
    }
    self := self
    joint_ := joint_
    axis_ := axis_
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &axis_,
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_generic_6dof_joint_set_flag :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    axis_: Vector3_Vector3_Axis,
    flag_: Physics_Server3dg6dof_Joint_Axis_Flag,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generic_6dof_joint_set_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3570926903)
    }
    self := self
    joint_ := joint_
    axis_ := axis_
    flag_ := flag_
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &axis_,
        &flag_,
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_generic_6dof_joint_get_flag :: proc "contextless" (
    self: Physics_Server3d,
    joint_: Rid,
    axis_: Vector3_Vector3_Axis,
    flag_: Physics_Server3dg6dof_Joint_Axis_Flag,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generic_6dof_joint_get_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4158090196)
    }
    self := self
    joint_ := joint_
    axis_ := axis_
    flag_ := flag_
    args := []__bindgen_gde.TypePtr {
        &joint_,
        &axis_,
        &flag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_server3d_free_rid :: proc "contextless" (
    self: Physics_Server3d,
    rid_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("free_rid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2722037293)
    }
    self := self
    rid_ := rid_
    args := []__bindgen_gde.TypePtr {
        &rid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_set_active :: proc "contextless" (
    self: Physics_Server3d,
    active_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    active_ := active_
    args := []__bindgen_gde.TypePtr {
        &active_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

physics_server3d_get_process_info :: proc "contextless" (
    self: Physics_Server3d,
    process_info_: Physics_Server3d_Process_Info,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_process_info", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1332958745)
    }
    self := self
    process_info_ := process_info_
    args := []__bindgen_gde.TypePtr {
        &process_info_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
physics_server3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PhysicsServer3D", true)
}

@(private = "file")
__class_name: String_Name