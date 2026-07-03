package godot

import __bindgen_gde "godot:gdext"

Geometry3d_Constants :: enum {
}



geometry3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

geometry3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_geometry3d :: proc "contextless" () -> Geometry3d {
    return __bindgen_gde.classdb_construct_object(geometry3d_name_ref())
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

geometry3d_compute_convex_mesh_points :: proc "contextless" (
    self: Geometry3d,
    planes_: Typed_Array(Plane),
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("compute_convex_mesh_points", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1936902142)
    }
    self := self
    planes_ := planes_
    args := []__bindgen_gde.TypePtr {
        &planes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_build_box_planes :: proc "contextless" (
    self: Geometry3d,
    extents_: Vector3,
) -> (ret: Typed_Array(Plane)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("build_box_planes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3622277145)
    }
    self := self
    extents_ := extents_
    args := []__bindgen_gde.TypePtr {
        &extents_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_build_cylinder_planes :: proc "contextless" (
    self: Geometry3d,
    radius_: f64,
    height_: f64,
    sides_: Int,
    axis_: Vector3_Vector3_Axis,
) -> (ret: Typed_Array(Plane)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("build_cylinder_planes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 449920067)
    }
    self := self
    radius_ := radius_
    height_ := height_
    sides_ := sides_
    axis_ := axis_
    args := []__bindgen_gde.TypePtr {
        &radius_,
        &height_,
        &sides_,
        &axis_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_build_capsule_planes :: proc "contextless" (
    self: Geometry3d,
    radius_: f64,
    height_: f64,
    sides_: Int,
    lats_: Int,
    axis_: Vector3_Vector3_Axis,
) -> (ret: Typed_Array(Plane)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("build_capsule_planes", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2113592876)
    }
    self := self
    radius_ := radius_
    height_ := height_
    sides_ := sides_
    lats_ := lats_
    axis_ := axis_
    args := []__bindgen_gde.TypePtr {
        &radius_,
        &height_,
        &sides_,
        &lats_,
        &axis_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_get_closest_points_between_segments :: proc "contextless" (
    self: Geometry3d,
    p1_: Vector3,
    p2_: Vector3,
    q1_: Vector3,
    q2_: Vector3,
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_closest_points_between_segments", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1056373962)
    }
    self := self
    p1_ := p1_
    p2_ := p2_
    q1_ := q1_
    q2_ := q2_
    args := []__bindgen_gde.TypePtr {
        &p1_,
        &p2_,
        &q1_,
        &q2_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_get_closest_point_to_segment :: proc "contextless" (
    self: Geometry3d,
    point_: Vector3,
    s1_: Vector3,
    s2_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_closest_point_to_segment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2168193209)
    }
    self := self
    point_ := point_
    s1_ := s1_
    s2_ := s2_
    args := []__bindgen_gde.TypePtr {
        &point_,
        &s1_,
        &s2_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_get_closest_point_to_segment_uncapped :: proc "contextless" (
    self: Geometry3d,
    point_: Vector3,
    s1_: Vector3,
    s2_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_closest_point_to_segment_uncapped", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2168193209)
    }
    self := self
    point_ := point_
    s1_ := s1_
    s2_ := s2_
    args := []__bindgen_gde.TypePtr {
        &point_,
        &s1_,
        &s2_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_get_triangle_barycentric_coords :: proc "contextless" (
    self: Geometry3d,
    point_: Vector3,
    a_: Vector3,
    b_: Vector3,
    c_: Vector3,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_triangle_barycentric_coords", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1362048029)
    }
    self := self
    point_ := point_
    a_ := a_
    b_ := b_
    c_ := c_
    args := []__bindgen_gde.TypePtr {
        &point_,
        &a_,
        &b_,
        &c_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_ray_intersects_triangle :: proc "contextless" (
    self: Geometry3d,
    from_: Vector3,
    dir_: Vector3,
    a_: Vector3,
    b_: Vector3,
    c_: Vector3,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("ray_intersects_triangle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1718655448)
    }
    self := self
    from_ := from_
    dir_ := dir_
    a_ := a_
    b_ := b_
    c_ := c_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &dir_,
        &a_,
        &b_,
        &c_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_segment_intersects_triangle :: proc "contextless" (
    self: Geometry3d,
    from_: Vector3,
    to_: Vector3,
    a_: Vector3,
    b_: Vector3,
    c_: Vector3,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("segment_intersects_triangle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1718655448)
    }
    self := self
    from_ := from_
    to_ := to_
    a_ := a_
    b_ := b_
    c_ := c_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &to_,
        &a_,
        &b_,
        &c_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_segment_intersects_sphere :: proc "contextless" (
    self: Geometry3d,
    from_: Vector3,
    to_: Vector3,
    sphere_position_: Vector3,
    sphere_radius_: f64,
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("segment_intersects_sphere", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4080141172)
    }
    self := self
    from_ := from_
    to_ := to_
    sphere_position_ := sphere_position_
    sphere_radius_ := sphere_radius_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &to_,
        &sphere_position_,
        &sphere_radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_segment_intersects_cylinder :: proc "contextless" (
    self: Geometry3d,
    from_: Vector3,
    to_: Vector3,
    height_: f64,
    radius_: f64,
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("segment_intersects_cylinder", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2361316491)
    }
    self := self
    from_ := from_
    to_ := to_
    height_ := height_
    radius_ := radius_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &to_,
        &height_,
        &radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_segment_intersects_convex :: proc "contextless" (
    self: Geometry3d,
    from_: Vector3,
    to_: Vector3,
    planes_: Typed_Array(Plane),
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("segment_intersects_convex", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 537425332)
    }
    self := self
    from_ := from_
    to_ := to_
    planes_ := planes_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &to_,
        &planes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_clip_polygon :: proc "contextless" (
    self: Geometry3d,
    points_: Packed_Vector3_Array,
    plane_: Plane,
) -> (ret: Packed_Vector3_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clip_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2603188319)
    }
    self := self
    points_ := points_
    plane_ := plane_
    args := []__bindgen_gde.TypePtr {
        &points_,
        &plane_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry3d_tetrahedralize_delaunay :: proc "contextless" (
    self: Geometry3d,
    points_: Packed_Vector3_Array,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tetrahedralize_delaunay", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1230191221)
    }
    self := self
    points_ := points_
    args := []__bindgen_gde.TypePtr {
        &points_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
geometry3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Geometry3D", true)
}

@(private = "file")
__class_name: String_Name