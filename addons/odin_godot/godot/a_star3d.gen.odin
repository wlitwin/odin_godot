package godot

import __bindgen_gde "godot:gdext"

A_Star3d_Constants :: enum {
}



a_star3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

a_star3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_a_star3d :: proc "contextless" () -> A_Star3d {
    return cast(A_Star3d)__bindgen_gde.classdb_construct_object(a_star3d_name_ref())
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

a_star3d__filter_neighbor :: proc "contextless" (
    self: A_Star3d,
    from_id_: Int,
    neighbor_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_filter_neighbor", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2522259332)
    }
    self := self
    from_id_ := from_id_
    neighbor_id_ := neighbor_id_
    args := []__bindgen_gde.TypePtr {
        &from_id_,
        &neighbor_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d__estimate_cost :: proc "contextless" (
    self: A_Star3d,
    from_id_: Int,
    end_id_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_estimate_cost", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    from_id_ := from_id_
    end_id_ := end_id_
    args := []__bindgen_gde.TypePtr {
        &from_id_,
        &end_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d__compute_cost :: proc "contextless" (
    self: A_Star3d,
    from_id_: Int,
    to_id_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_compute_cost", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    from_id_ := from_id_
    to_id_ := to_id_
    args := []__bindgen_gde.TypePtr {
        &from_id_,
        &to_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_get_available_point_id :: proc "contextless" (
    self: A_Star3d,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_available_point_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_add_point :: proc "contextless" (
    self: A_Star3d,
    id_: Int,
    position_: Vector3,
    weight_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_point", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1038703438)
    }
    self := self
    id_ := id_
    position_ := position_
    weight_scale_ := weight_scale_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &position_,
        &weight_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star3d_get_point_position :: proc "contextless" (
    self: A_Star3d,
    id_: Int,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 711720468)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_set_point_position :: proc "contextless" (
    self: A_Star3d,
    id_: Int,
    position_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_point_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1530502735)
    }
    self := self
    id_ := id_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star3d_get_point_weight_scale :: proc "contextless" (
    self: A_Star3d,
    id_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_weight_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_set_point_weight_scale :: proc "contextless" (
    self: A_Star3d,
    id_: Int,
    weight_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_point_weight_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    id_ := id_
    weight_scale_ := weight_scale_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &weight_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star3d_remove_point :: proc "contextless" (
    self: A_Star3d,
    id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_point", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star3d_has_point :: proc "contextless" (
    self: A_Star3d,
    id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_point", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_get_point_connections :: proc "contextless" (
    self: A_Star3d,
    id_: Int,
) -> (ret: Packed_Int64_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_connections", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2865087369)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_get_point_ids :: proc "contextless" (
    self: A_Star3d,
) -> (ret: Packed_Int64_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_ids", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3851388692)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_set_point_disabled :: proc "contextless" (
    self: A_Star3d,
    id_: Int,
    disabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_point_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 972357352)
    }
    self := self
    id_ := id_
    disabled_ := disabled_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &disabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star3d_is_point_disabled :: proc "contextless" (
    self: A_Star3d,
    id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_point_disabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_set_neighbor_filter_enabled :: proc "contextless" (
    self: A_Star3d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_neighbor_filter_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star3d_is_neighbor_filter_enabled :: proc "contextless" (
    self: A_Star3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_neighbor_filter_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_connect_points :: proc "contextless" (
    self: A_Star3d,
    id_: Int,
    to_id_: Int,
    bidirectional_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("connect_points", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3710494224)
    }
    self := self
    id_ := id_
    to_id_ := to_id_
    bidirectional_ := bidirectional_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &to_id_,
        &bidirectional_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star3d_disconnect_points :: proc "contextless" (
    self: A_Star3d,
    id_: Int,
    to_id_: Int,
    bidirectional_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("disconnect_points", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3710494224)
    }
    self := self
    id_ := id_
    to_id_ := to_id_
    bidirectional_ := bidirectional_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &to_id_,
        &bidirectional_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star3d_are_points_connected :: proc "contextless" (
    self: A_Star3d,
    id_: Int,
    to_id_: Int,
    bidirectional_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("are_points_connected", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2288175859)
    }
    self := self
    id_ := id_
    to_id_ := to_id_
    bidirectional_ := bidirectional_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &to_id_,
        &bidirectional_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_get_point_count :: proc "contextless" (
    self: A_Star3d,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_get_point_capacity :: proc "contextless" (
    self: A_Star3d,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_capacity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_reserve_space :: proc "contextless" (
    self: A_Star3d,
    num_nodes_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("reserve_space", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    num_nodes_ := num_nodes_
    args := []__bindgen_gde.TypePtr {
        &num_nodes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star3d_clear :: proc "contextless" (
    self: A_Star3d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star3d_get_closest_point :: proc "contextless" (
    self: A_Star3d,
    to_position_: Vector3,
    include_disabled_: Bool,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_closest_point", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3241074317)
    }
    self := self
    to_position_ := to_position_
    include_disabled_ := include_disabled_
    args := []__bindgen_gde.TypePtr {
        &to_position_,
        &include_disabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_get_closest_position_in_segment :: proc "contextless" (
    self: A_Star3d,
    to_position_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_closest_position_in_segment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 192990374)
    }
    self := self
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_get_point_path :: proc "contextless" (
    self: A_Star3d,
    from_id_: Int,
    to_id_: Int,
    allow_partial_path_: Bool,
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1562654675)
    }
    self := self
    from_id_ := from_id_
    to_id_ := to_id_
    allow_partial_path_ := allow_partial_path_
    args := []__bindgen_gde.TypePtr {
        &from_id_,
        &to_id_,
        &allow_partial_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star3d_get_id_path :: proc "contextless" (
    self: A_Star3d,
    from_id_: Int,
    to_id_: Int,
    allow_partial_path_: Bool,
) -> (ret: Packed_Int64_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_id_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3136199648)
    }
    self := self
    from_id_ := from_id_
    to_id_ := to_id_
    allow_partial_path_ := allow_partial_path_
    args := []__bindgen_gde.TypePtr {
        &from_id_,
        &to_id_,
        &allow_partial_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
a_star3d_get_neighbor_filter_enabled :: proc "contextless" (self: A_Star3d) -> Bool {
    return a_star3d_is_neighbor_filter_enabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
a_star3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AStar3D", true)
}

@(private = "file")
__class_name: String_Name