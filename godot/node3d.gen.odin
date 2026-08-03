package godot

import __bindgen_gde "godot:gdext"

Node3d_Constants :: enum {
    NOTIFICATION_TRANSFORM_CHANGED = 2000,
    NOTIFICATION_ENTER_WORLD = 41,
    NOTIFICATION_EXIT_WORLD = 42,
    NOTIFICATION_VISIBILITY_CHANGED = 43,
    NOTIFICATION_LOCAL_TRANSFORM_CHANGED = 44,
}
Node3d_Rotation_Edit_Mode :: enum int {
    Rotation_Edit_Mode_Euler = 0,
    Rotation_Edit_Mode_Quaternion = 1,
    Rotation_Edit_Mode_Basis = 2,
}



node3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

node3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_node3d :: proc "contextless" () -> Node3d {
    return cast(Node3d)__bindgen_gde.classdb_construct_object(node3d_name_ref())
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

node3d_set_transform :: proc "contextless" (
    self: Node3d,
    local_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2952846383)
    }
    self := self
    local_ := local_
    args := []__bindgen_gde.TypePtr {
        &local_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_transform :: proc "contextless" (
    self: Node3d,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3229777777)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_position :: proc "contextless" (
    self: Node3d,
    position_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_position :: proc "contextless" (
    self: Node3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_rotation :: proc "contextless" (
    self: Node3d,
    euler_radians_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    euler_radians_ := euler_radians_
    args := []__bindgen_gde.TypePtr {
        &euler_radians_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_rotation :: proc "contextless" (
    self: Node3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_rotation_degrees :: proc "contextless" (
    self: Node3d,
    euler_degrees_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rotation_degrees", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    euler_degrees_ := euler_degrees_
    args := []__bindgen_gde.TypePtr {
        &euler_degrees_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_rotation_degrees :: proc "contextless" (
    self: Node3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rotation_degrees", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_rotation_order :: proc "contextless" (
    self: Node3d,
    order_: Euler_Order,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rotation_order", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1820889989)
    }
    self := self
    order_ := order_
    args := []__bindgen_gde.TypePtr {
        &order_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_rotation_order :: proc "contextless" (
    self: Node3d,
) -> (ret: Euler_Order) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rotation_order", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 916939469)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_rotation_edit_mode :: proc "contextless" (
    self: Node3d,
    edit_mode_: Node3d_Rotation_Edit_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rotation_edit_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 141483330)
    }
    self := self
    edit_mode_ := edit_mode_
    args := []__bindgen_gde.TypePtr {
        &edit_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_rotation_edit_mode :: proc "contextless" (
    self: Node3d,
) -> (ret: Node3d_Rotation_Edit_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rotation_edit_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1572188370)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_scale :: proc "contextless" (
    self: Node3d,
    scale_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_scale :: proc "contextless" (
    self: Node3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_quaternion :: proc "contextless" (
    self: Node3d,
    quaternion_: Quaternion,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_quaternion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1727505552)
    }
    self := self
    quaternion_ := quaternion_
    args := []__bindgen_gde.TypePtr {
        &quaternion_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_quaternion :: proc "contextless" (
    self: Node3d,
) -> (ret: Quaternion) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_quaternion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1222331677)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_basis :: proc "contextless" (
    self: Node3d,
    basis_: Basis,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_basis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1055510324)
    }
    self := self
    basis_ := basis_
    args := []__bindgen_gde.TypePtr {
        &basis_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_basis :: proc "contextless" (
    self: Node3d,
) -> (ret: Basis) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_basis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2716978435)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_global_transform :: proc "contextless" (
    self: Node3d,
    global_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_global_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2952846383)
    }
    self := self
    global_ := global_
    args := []__bindgen_gde.TypePtr {
        &global_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_global_transform :: proc "contextless" (
    self: Node3d,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3229777777)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_get_global_transform_interpolated :: proc "contextless" (
    self: Node3d,
) -> (ret: Transform3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_transform_interpolated", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4183770049)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_global_position :: proc "contextless" (
    self: Node3d,
    position_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_global_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_global_position :: proc "contextless" (
    self: Node3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_global_basis :: proc "contextless" (
    self: Node3d,
    basis_: Basis,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_global_basis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1055510324)
    }
    self := self
    basis_ := basis_
    args := []__bindgen_gde.TypePtr {
        &basis_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_global_basis :: proc "contextless" (
    self: Node3d,
) -> (ret: Basis) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_basis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2716978435)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_global_rotation :: proc "contextless" (
    self: Node3d,
    euler_radians_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_global_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    euler_radians_ := euler_radians_
    args := []__bindgen_gde.TypePtr {
        &euler_radians_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_global_rotation :: proc "contextless" (
    self: Node3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_global_rotation_degrees :: proc "contextless" (
    self: Node3d,
    euler_degrees_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_global_rotation_degrees", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    euler_degrees_ := euler_degrees_
    args := []__bindgen_gde.TypePtr {
        &euler_degrees_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_global_rotation_degrees :: proc "contextless" (
    self: Node3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_rotation_degrees", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_get_parent_node_3d :: proc "contextless" (
    self: Node3d,
) -> (ret: Node3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_parent_node_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 151077316)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_ignore_transform_notification :: proc "contextless" (
    self: Node3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_ignore_transform_notification", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_set_as_top_level :: proc "contextless" (
    self: Node3d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_as_top_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_is_set_as_top_level :: proc "contextless" (
    self: Node3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_set_as_top_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_disable_scale :: proc "contextless" (
    self: Node3d,
    disable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_disable_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    disable_ := disable_
    args := []__bindgen_gde.TypePtr {
        &disable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_is_scale_disabled :: proc "contextless" (
    self: Node3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_scale_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_get_world_3d :: proc "contextless" (
    self: Node3d,
) -> (ret: World3d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_world_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 317588385)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_force_update_transform :: proc "contextless" (
    self: Node3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("force_update_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_set_visibility_parent :: proc "contextless" (
    self: Node3d,
    path_: Node_Path,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_parent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1348162250)
    }
    self := self
    path_ := path_
    args := []__bindgen_gde.TypePtr {
        &path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_visibility_parent :: proc "contextless" (
    self: Node3d,
) -> (ret: Node_Path) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_parent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4075236667)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_update_gizmos :: proc "contextless" (
    self: Node3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_gizmos", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_add_gizmo :: proc "contextless" (
    self: Node3d,
    gizmo_: Node3d_Gizmo,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_gizmo", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1544533845)
    }
    self := self
    gizmo_ := gizmo_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_get_gizmos :: proc "contextless" (
    self: Node3d,
) -> (ret: Typed_Array(Node3d_Gizmo)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gizmos", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_clear_gizmos :: proc "contextless" (
    self: Node3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_gizmos", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_set_subgizmo_selection :: proc "contextless" (
    self: Node3d,
    gizmo_: Node3d_Gizmo,
    id_: Int,
    transform_: Transform3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_subgizmo_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3317607635)
    }
    self := self
    gizmo_ := gizmo_
    id_ := id_
    transform_ := transform_
    args := []__bindgen_gde.TypePtr {
        &gizmo_,
        &id_,
        &transform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_clear_subgizmo_selection :: proc "contextless" (
    self: Node3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_subgizmo_selection", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_set_visible :: proc "contextless" (
    self: Node3d,
    visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    visible_ := visible_
    args := []__bindgen_gde.TypePtr {
        &visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_is_visible :: proc "contextless" (
    self: Node3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_is_visible_in_tree :: proc "contextless" (
    self: Node3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_visible_in_tree", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_show :: proc "contextless" (
    self: Node3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("show", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_hide :: proc "contextless" (
    self: Node3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hide", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_set_notify_local_transform :: proc "contextless" (
    self: Node3d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_notify_local_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_is_local_transform_notification_enabled :: proc "contextless" (
    self: Node3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_local_transform_notification_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_set_notify_transform :: proc "contextless" (
    self: Node3d,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_notify_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_is_transform_notification_enabled :: proc "contextless" (
    self: Node3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_transform_notification_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_rotate :: proc "contextless" (
    self: Node3d,
    axis_: Vector3,
    angle_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3436291937)
    }
    self := self
    axis_ := axis_
    angle_ := angle_
    args := []__bindgen_gde.TypePtr {
        &axis_,
        &angle_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_global_rotate :: proc "contextless" (
    self: Node3d,
    axis_: Vector3,
    angle_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_rotate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3436291937)
    }
    self := self
    axis_ := axis_
    angle_ := angle_
    args := []__bindgen_gde.TypePtr {
        &axis_,
        &angle_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_global_scale :: proc "contextless" (
    self: Node3d,
    scale_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_global_translate :: proc "contextless" (
    self: Node3d,
    offset_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_translate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_rotate_object_local :: proc "contextless" (
    self: Node3d,
    axis_: Vector3,
    angle_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotate_object_local", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3436291937)
    }
    self := self
    axis_ := axis_
    angle_ := angle_
    args := []__bindgen_gde.TypePtr {
        &axis_,
        &angle_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_scale_object_local :: proc "contextless" (
    self: Node3d,
    scale_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("scale_object_local", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_translate_object_local :: proc "contextless" (
    self: Node3d,
    offset_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("translate_object_local", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_rotate_x :: proc "contextless" (
    self: Node3d,
    angle_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotate_x", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    angle_ := angle_
    args := []__bindgen_gde.TypePtr {
        &angle_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_rotate_y :: proc "contextless" (
    self: Node3d,
    angle_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotate_y", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    angle_ := angle_
    args := []__bindgen_gde.TypePtr {
        &angle_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_rotate_z :: proc "contextless" (
    self: Node3d,
    angle_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotate_z", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    angle_ := angle_
    args := []__bindgen_gde.TypePtr {
        &angle_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_translate :: proc "contextless" (
    self: Node3d,
    offset_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("translate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_orthonormalize :: proc "contextless" (
    self: Node3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("orthonormalize", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_set_identity :: proc "contextless" (
    self: Node3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_identity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_look_at :: proc "contextless" (
    self: Node3d,
    target_: Vector3,
    up_: Vector3,
    use_model_front_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("look_at", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2882425029)
    }
    self := self
    target_ := target_
    up_ := up_
    use_model_front_ := use_model_front_
    args := []__bindgen_gde.TypePtr {
        &target_,
        &up_,
        &use_model_front_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_look_at_from_position :: proc "contextless" (
    self: Node3d,
    position_: Vector3,
    target_: Vector3,
    up_: Vector3,
    use_model_front_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("look_at_from_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2086826090)
    }
    self := self
    position_ := position_
    target_ := target_
    up_ := up_
    use_model_front_ := use_model_front_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &target_,
        &up_,
        &use_model_front_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node3d_to_local :: proc "contextless" (
    self: Node3d,
    global_point_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_local", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 192990374)
    }
    self := self
    global_point_ := global_point_
    args := []__bindgen_gde.TypePtr {
        &global_point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node3d_to_global :: proc "contextless" (
    self: Node3d,
    local_point_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_global", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 192990374)
    }
    self := self
    local_point_ := local_point_
    args := []__bindgen_gde.TypePtr {
        &local_point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
node3d_get_top_level :: proc "contextless" (self: Node3d) -> Bool {
    return node3d_is_set_as_top_level(self)
}
node3d_set_top_level :: proc "contextless" (self: Node3d, value: Bool) {
    node3d_set_as_top_level(self, value)
}
node3d_get_visible :: proc "contextless" (self: Node3d) -> Bool {
    return node3d_is_visible(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
node3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Node3D", true)
}

@(private = "file")
__class_name: String_Name