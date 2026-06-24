package godot

import __bindgen_gde "godot:gdext"

Kinematic_Collision3d_Constants :: enum {
}



kinematic_collision3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

kinematic_collision3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_kinematic_collision3d :: proc "contextless" () -> Kinematic_Collision3d {
    return cast(Kinematic_Collision3d)__bindgen_gde.classdb_construct_object(kinematic_collision3d_name_ref())
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

kinematic_collision3d_get_travel :: proc "contextless" (
    self: Kinematic_Collision3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_travel", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

kinematic_collision3d_get_remainder :: proc "contextless" (
    self: Kinematic_Collision3d,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_remainder", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

kinematic_collision3d_get_depth :: proc "contextless" (
    self: Kinematic_Collision3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_depth", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

kinematic_collision3d_get_collision_count :: proc "contextless" (
    self: Kinematic_Collision3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

kinematic_collision3d_get_position :: proc "contextless" (
    self: Kinematic_Collision3d,
    collision_index_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1914908202)
    }
    self := self
    collision_index_ := collision_index_
    args := []__bindgen_gde.TypePtr {
        &collision_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

kinematic_collision3d_get_normal :: proc "contextless" (
    self: Kinematic_Collision3d,
    collision_index_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_normal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1914908202)
    }
    self := self
    collision_index_ := collision_index_
    args := []__bindgen_gde.TypePtr {
        &collision_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

kinematic_collision3d_get_angle :: proc "contextless" (
    self: Kinematic_Collision3d,
    collision_index_: Int,
    up_direction_: Vector3,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_angle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1242741860)
    }
    self := self
    collision_index_ := collision_index_
    up_direction_ := up_direction_
    args := []__bindgen_gde.TypePtr {
        &collision_index_,
        &up_direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

kinematic_collision3d_get_local_shape :: proc "contextless" (
    self: Kinematic_Collision3d,
    collision_index_: Int,
) -> (ret: Object) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_local_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2639523548)
    }
    self := self
    collision_index_ := collision_index_
    args := []__bindgen_gde.TypePtr {
        &collision_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

kinematic_collision3d_get_collider :: proc "contextless" (
    self: Kinematic_Collision3d,
    collision_index_: Int,
) -> (ret: Object) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collider", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2639523548)
    }
    self := self
    collision_index_ := collision_index_
    args := []__bindgen_gde.TypePtr {
        &collision_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

kinematic_collision3d_get_collider_id :: proc "contextless" (
    self: Kinematic_Collision3d,
    collision_index_: Int,
) -> (ret: u64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collider_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    collision_index_ := collision_index_
    args := []__bindgen_gde.TypePtr {
        &collision_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

kinematic_collision3d_get_collider_rid :: proc "contextless" (
    self: Kinematic_Collision3d,
    collision_index_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collider_rid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1231817359)
    }
    self := self
    collision_index_ := collision_index_
    args := []__bindgen_gde.TypePtr {
        &collision_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

kinematic_collision3d_get_collider_shape :: proc "contextless" (
    self: Kinematic_Collision3d,
    collision_index_: Int,
) -> (ret: Object) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collider_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2639523548)
    }
    self := self
    collision_index_ := collision_index_
    args := []__bindgen_gde.TypePtr {
        &collision_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

kinematic_collision3d_get_collider_shape_index :: proc "contextless" (
    self: Kinematic_Collision3d,
    collision_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collider_shape_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1591665591)
    }
    self := self
    collision_index_ := collision_index_
    args := []__bindgen_gde.TypePtr {
        &collision_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

kinematic_collision3d_get_collider_velocity :: proc "contextless" (
    self: Kinematic_Collision3d,
    collision_index_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collider_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1914908202)
    }
    self := self
    collision_index_ := collision_index_
    args := []__bindgen_gde.TypePtr {
        &collision_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
kinematic_collision3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("KinematicCollision3D", true)
}

@(private = "file")
__class_name: String_Name