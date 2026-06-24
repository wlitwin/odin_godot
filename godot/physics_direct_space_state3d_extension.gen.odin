package godot

import __bindgen_gde "godot:gdext"

Physics_Direct_Space_State3d_Extension_Constants :: enum {
}



physics_direct_space_state3d_extension_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

physics_direct_space_state3d_extension_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_physics_direct_space_state3d_extension :: proc "contextless" () -> Physics_Direct_Space_State3d_Extension {
    return __bindgen_gde.classdb_construct_object(physics_direct_space_state3d_extension_name_ref())
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

physics_direct_space_state3d_extension__intersect_ray :: proc "contextless" (
    self: Physics_Direct_Space_State3d_Extension,
    from_: Vector3,
    to_: Vector3,
    collision_mask_: Int,
    collide_with_bodies_: Bool,
    collide_with_areas_: Bool,
    hit_from_inside_: Bool,
    hit_back_faces_: Bool,
    pick_ray_: Bool,
    result_: ^Physics_Server3d_Extension_Ray_Result,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_intersect_ray", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2022529123)
    }
    self := self
    from_ := from_
    to_ := to_
    collision_mask_ := collision_mask_
    collide_with_bodies_ := collide_with_bodies_
    collide_with_areas_ := collide_with_areas_
    hit_from_inside_ := hit_from_inside_
    hit_back_faces_ := hit_back_faces_
    pick_ray_ := pick_ray_
    result_ := result_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &to_,
        &collision_mask_,
        &collide_with_bodies_,
        &collide_with_areas_,
        &hit_from_inside_,
        &hit_back_faces_,
        &pick_ray_,
        &result_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_direct_space_state3d_extension__intersect_point :: proc "contextless" (
    self: Physics_Direct_Space_State3d_Extension,
    position_: Vector3,
    collision_mask_: Int,
    collide_with_bodies_: Bool,
    collide_with_areas_: Bool,
    results_: ^Physics_Server3d_Extension_Shape_Result,
    max_results_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_intersect_point", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3378904092)
    }
    self := self
    position_ := position_
    collision_mask_ := collision_mask_
    collide_with_bodies_ := collide_with_bodies_
    collide_with_areas_ := collide_with_areas_
    results_ := results_
    max_results_ := max_results_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &collision_mask_,
        &collide_with_bodies_,
        &collide_with_areas_,
        &results_,
        &max_results_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_direct_space_state3d_extension__intersect_shape :: proc "contextless" (
    self: Physics_Direct_Space_State3d_Extension,
    shape_rid_: Rid,
    transform_: Transform3d,
    motion_: Vector3,
    margin_: f64,
    collision_mask_: Int,
    collide_with_bodies_: Bool,
    collide_with_areas_: Bool,
    result_count_: ^Physics_Server3d_Extension_Shape_Result,
    max_results_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_intersect_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 728953575)
    }
    self := self
    shape_rid_ := shape_rid_
    transform_ := transform_
    motion_ := motion_
    margin_ := margin_
    collision_mask_ := collision_mask_
    collide_with_bodies_ := collide_with_bodies_
    collide_with_areas_ := collide_with_areas_
    result_count_ := result_count_
    max_results_ := max_results_
    args := []__bindgen_gde.TypePtr {
        &shape_rid_,
        &transform_,
        &motion_,
        &margin_,
        &collision_mask_,
        &collide_with_bodies_,
        &collide_with_areas_,
        &result_count_,
        &max_results_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_direct_space_state3d_extension__cast_motion :: proc "contextless" (
    self: Physics_Direct_Space_State3d_Extension,
    shape_rid_: Rid,
    transform_: Transform3d,
    motion_: Vector3,
    margin_: f64,
    collision_mask_: Int,
    collide_with_bodies_: Bool,
    collide_with_areas_: Bool,
    closest_safe_: ^f32,
    closest_unsafe_: ^f32,
    info_: ^Physics_Server3d_Extension_Shape_Rest_Info,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_cast_motion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2320624824)
    }
    self := self
    shape_rid_ := shape_rid_
    transform_ := transform_
    motion_ := motion_
    margin_ := margin_
    collision_mask_ := collision_mask_
    collide_with_bodies_ := collide_with_bodies_
    collide_with_areas_ := collide_with_areas_
    closest_safe_ := closest_safe_
    closest_unsafe_ := closest_unsafe_
    info_ := info_
    args := []__bindgen_gde.TypePtr {
        &shape_rid_,
        &transform_,
        &motion_,
        &margin_,
        &collision_mask_,
        &collide_with_bodies_,
        &collide_with_areas_,
        &closest_safe_,
        &closest_unsafe_,
        &info_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_direct_space_state3d_extension__collide_shape :: proc "contextless" (
    self: Physics_Direct_Space_State3d_Extension,
    shape_rid_: Rid,
    transform_: Transform3d,
    motion_: Vector3,
    margin_: f64,
    collision_mask_: Int,
    collide_with_bodies_: Bool,
    collide_with_areas_: Bool,
    results_: rawptr,
    max_results_: Int,
    result_count_: ^i32,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_collide_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2320624824)
    }
    self := self
    shape_rid_ := shape_rid_
    transform_ := transform_
    motion_ := motion_
    margin_ := margin_
    collision_mask_ := collision_mask_
    collide_with_bodies_ := collide_with_bodies_
    collide_with_areas_ := collide_with_areas_
    results_ := results_
    max_results_ := max_results_
    result_count_ := result_count_
    args := []__bindgen_gde.TypePtr {
        &shape_rid_,
        &transform_,
        &motion_,
        &margin_,
        &collision_mask_,
        &collide_with_bodies_,
        &collide_with_areas_,
        &results_,
        &max_results_,
        &result_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_direct_space_state3d_extension__rest_info :: proc "contextless" (
    self: Physics_Direct_Space_State3d_Extension,
    shape_rid_: Rid,
    transform_: Transform3d,
    motion_: Vector3,
    margin_: f64,
    collision_mask_: Int,
    collide_with_bodies_: Bool,
    collide_with_areas_: Bool,
    rest_info_: ^Physics_Server3d_Extension_Shape_Rest_Info,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_rest_info", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 856242757)
    }
    self := self
    shape_rid_ := shape_rid_
    transform_ := transform_
    motion_ := motion_
    margin_ := margin_
    collision_mask_ := collision_mask_
    collide_with_bodies_ := collide_with_bodies_
    collide_with_areas_ := collide_with_areas_
    rest_info_ := rest_info_
    args := []__bindgen_gde.TypePtr {
        &shape_rid_,
        &transform_,
        &motion_,
        &margin_,
        &collision_mask_,
        &collide_with_bodies_,
        &collide_with_areas_,
        &rest_info_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_direct_space_state3d_extension__get_closest_point_to_object_volume :: proc "contextless" (
    self: Physics_Direct_Space_State3d_Extension,
    object_: Rid,
    point_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_closest_point_to_object_volume", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2056183332)
    }
    self := self
    object_ := object_
    point_ := point_
    args := []__bindgen_gde.TypePtr {
        &object_,
        &point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

physics_direct_space_state3d_extension_is_body_excluded_from_query :: proc "contextless" (
    self: Physics_Direct_Space_State3d_Extension,
    body_: Rid,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_body_excluded_from_query", true)
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


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
physics_direct_space_state3d_extension_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("PhysicsDirectSpaceState3DExtension", true)
}

@(private = "file")
__class_name: String_Name