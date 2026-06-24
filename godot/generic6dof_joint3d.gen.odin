package godot

import __bindgen_gde "godot:gdext"

Generic6dof_Joint3d_Constants :: enum {
}
Generic6dof_Joint3d_Param :: enum int {
    Param_Linear_Lower_Limit = 0,
    Param_Linear_Upper_Limit = 1,
    Param_Linear_Limit_Softness = 2,
    Param_Linear_Restitution = 3,
    Param_Linear_Damping = 4,
    Param_Linear_Motor_Target_Velocity = 5,
    Param_Linear_Motor_Force_Limit = 6,
    Param_Linear_Spring_Stiffness = 7,
    Param_Linear_Spring_Damping = 8,
    Param_Linear_Spring_Equilibrium_Point = 9,
    Param_Angular_Lower_Limit = 10,
    Param_Angular_Upper_Limit = 11,
    Param_Angular_Limit_Softness = 12,
    Param_Angular_Damping = 13,
    Param_Angular_Restitution = 14,
    Param_Angular_Force_Limit = 15,
    Param_Angular_Erp = 16,
    Param_Angular_Motor_Target_Velocity = 17,
    Param_Angular_Motor_Force_Limit = 18,
    Param_Angular_Spring_Stiffness = 19,
    Param_Angular_Spring_Damping = 20,
    Param_Angular_Spring_Equilibrium_Point = 21,
    Param_Max = 22,
}
Generic6dof_Joint3d_Flag :: enum int {
    Flag_Enable_Linear_Limit = 0,
    Flag_Enable_Angular_Limit = 1,
    Flag_Enable_Linear_Spring = 3,
    Flag_Enable_Angular_Spring = 2,
    Flag_Enable_Motor = 4,
    Flag_Enable_Linear_Motor = 5,
    Flag_Max = 6,
}



generic6dof_joint3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

generic6dof_joint3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_generic6dof_joint3d :: proc "contextless" () -> Generic6dof_Joint3d {
    return __bindgen_gde.classdb_construct_object(generic6dof_joint3d_name_ref())
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

generic6dof_joint3d_set_param_x :: proc "contextless" (
    self: Generic6dof_Joint3d,
    param_: Generic6dof_Joint3d_Param,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param_x", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2018184242)
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

generic6dof_joint3d_get_param_x :: proc "contextless" (
    self: Generic6dof_Joint3d,
    param_: Generic6dof_Joint3d_Param,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param_x", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2599835054)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

generic6dof_joint3d_set_param_y :: proc "contextless" (
    self: Generic6dof_Joint3d,
    param_: Generic6dof_Joint3d_Param,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param_y", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2018184242)
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

generic6dof_joint3d_get_param_y :: proc "contextless" (
    self: Generic6dof_Joint3d,
    param_: Generic6dof_Joint3d_Param,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param_y", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2599835054)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

generic6dof_joint3d_set_param_z :: proc "contextless" (
    self: Generic6dof_Joint3d,
    param_: Generic6dof_Joint3d_Param,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_param_z", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2018184242)
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

generic6dof_joint3d_get_param_z :: proc "contextless" (
    self: Generic6dof_Joint3d,
    param_: Generic6dof_Joint3d_Param,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_param_z", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2599835054)
    }
    self := self
    param_ := param_
    args := []__bindgen_gde.TypePtr {
        &param_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

generic6dof_joint3d_set_flag_x :: proc "contextless" (
    self: Generic6dof_Joint3d,
    flag_: Generic6dof_Joint3d_Flag,
    value_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flag_x", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2451594564)
    }
    self := self
    flag_ := flag_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &flag_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

generic6dof_joint3d_get_flag_x :: proc "contextless" (
    self: Generic6dof_Joint3d,
    flag_: Generic6dof_Joint3d_Flag,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_flag_x", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2122427807)
    }
    self := self
    flag_ := flag_
    args := []__bindgen_gde.TypePtr {
        &flag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

generic6dof_joint3d_set_flag_y :: proc "contextless" (
    self: Generic6dof_Joint3d,
    flag_: Generic6dof_Joint3d_Flag,
    value_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flag_y", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2451594564)
    }
    self := self
    flag_ := flag_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &flag_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

generic6dof_joint3d_get_flag_y :: proc "contextless" (
    self: Generic6dof_Joint3d,
    flag_: Generic6dof_Joint3d_Flag,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_flag_y", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2122427807)
    }
    self := self
    flag_ := flag_
    args := []__bindgen_gde.TypePtr {
        &flag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

generic6dof_joint3d_set_flag_z :: proc "contextless" (
    self: Generic6dof_Joint3d,
    flag_: Generic6dof_Joint3d_Flag,
    value_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flag_z", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2451594564)
    }
    self := self
    flag_ := flag_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &flag_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

generic6dof_joint3d_get_flag_z :: proc "contextless" (
    self: Generic6dof_Joint3d,
    flag_: Generic6dof_Joint3d_Flag,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_flag_z", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2122427807)
    }
    self := self
    flag_ := flag_
    args := []__bindgen_gde.TypePtr {
        &flag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
generic6dof_joint3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Generic6DOFJoint3D", true)
}

@(private = "file")
__class_name: String_Name