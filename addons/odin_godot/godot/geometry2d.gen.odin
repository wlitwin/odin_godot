package godot

import __bindgen_gde "godot:gdext"

Geometry2d_Constants :: enum {
}
Geometry2d_Poly_Boolean_Operation :: enum int {
    Operation_Union = 0,
    Operation_Difference = 1,
    Operation_Intersection = 2,
    Operation_Xor = 3,
}
Geometry2d_Poly_Join_Type :: enum int {
    Join_Square = 0,
    Join_Round = 1,
    Join_Miter = 2,
}
Geometry2d_Poly_End_Type :: enum int {
    End_Polygon = 0,
    End_Joined = 1,
    End_Butt = 2,
    End_Square = 3,
    End_Round = 4,
}



geometry2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

geometry2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_geometry2d :: proc "contextless" () -> Geometry2d {
    return __bindgen_gde.classdb_construct_object(geometry2d_name_ref())
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

geometry2d_is_point_in_circle :: proc "contextless" (
    self: Geometry2d,
    point_: Vector2,
    circle_position_: Vector2,
    circle_radius_: f64,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_point_in_circle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2929491703)
    }
    self := self
    point_ := point_
    circle_position_ := circle_position_
    circle_radius_ := circle_radius_
    args := []__bindgen_gde.TypePtr {
        &point_,
        &circle_position_,
        &circle_radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_segment_intersects_circle :: proc "contextless" (
    self: Geometry2d,
    segment_from_: Vector2,
    segment_to_: Vector2,
    circle_position_: Vector2,
    circle_radius_: f64,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("segment_intersects_circle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1356928167)
    }
    self := self
    segment_from_ := segment_from_
    segment_to_ := segment_to_
    circle_position_ := circle_position_
    circle_radius_ := circle_radius_
    args := []__bindgen_gde.TypePtr {
        &segment_from_,
        &segment_to_,
        &circle_position_,
        &circle_radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_segment_intersects_segment :: proc "contextless" (
    self: Geometry2d,
    from_a_: Vector2,
    to_a_: Vector2,
    from_b_: Vector2,
    to_b_: Vector2,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("segment_intersects_segment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2058025344)
    }
    self := self
    from_a_ := from_a_
    to_a_ := to_a_
    from_b_ := from_b_
    to_b_ := to_b_
    args := []__bindgen_gde.TypePtr {
        &from_a_,
        &to_a_,
        &from_b_,
        &to_b_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_line_intersects_line :: proc "contextless" (
    self: Geometry2d,
    from_a_: Vector2,
    dir_a_: Vector2,
    from_b_: Vector2,
    dir_b_: Vector2,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("line_intersects_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2058025344)
    }
    self := self
    from_a_ := from_a_
    dir_a_ := dir_a_
    from_b_ := from_b_
    dir_b_ := dir_b_
    args := []__bindgen_gde.TypePtr {
        &from_a_,
        &dir_a_,
        &from_b_,
        &dir_b_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_get_closest_points_between_segments :: proc "contextless" (
    self: Geometry2d,
    p1_: Vector2,
    q1_: Vector2,
    p2_: Vector2,
    q2_: Vector2,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_closest_points_between_segments", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3344690961)
    }
    self := self
    p1_ := p1_
    q1_ := q1_
    p2_ := p2_
    q2_ := q2_
    args := []__bindgen_gde.TypePtr {
        &p1_,
        &q1_,
        &p2_,
        &q2_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_get_closest_point_to_segment :: proc "contextless" (
    self: Geometry2d,
    point_: Vector2,
    s1_: Vector2,
    s2_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_closest_point_to_segment", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4172901909)
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

geometry2d_get_closest_point_to_segment_uncapped :: proc "contextless" (
    self: Geometry2d,
    point_: Vector2,
    s1_: Vector2,
    s2_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_closest_point_to_segment_uncapped", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4172901909)
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

geometry2d_point_is_inside_triangle :: proc "contextless" (
    self: Geometry2d,
    point_: Vector2,
    a_: Vector2,
    b_: Vector2,
    c_: Vector2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("point_is_inside_triangle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025948137)
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

geometry2d_is_polygon_clockwise :: proc "contextless" (
    self: Geometry2d,
    polygon_: Packed_Vector2_Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_polygon_clockwise", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1361156557)
    }
    self := self
    polygon_ := polygon_
    args := []__bindgen_gde.TypePtr {
        &polygon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_is_point_in_polygon :: proc "contextless" (
    self: Geometry2d,
    point_: Vector2,
    polygon_: Packed_Vector2_Array,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_point_in_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 738277916)
    }
    self := self
    point_ := point_
    polygon_ := polygon_
    args := []__bindgen_gde.TypePtr {
        &point_,
        &polygon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_triangulate_polygon :: proc "contextless" (
    self: Geometry2d,
    polygon_: Packed_Vector2_Array,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("triangulate_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1389921771)
    }
    self := self
    polygon_ := polygon_
    args := []__bindgen_gde.TypePtr {
        &polygon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_triangulate_delaunay :: proc "contextless" (
    self: Geometry2d,
    points_: Packed_Vector2_Array,
) -> (ret: Packed_Int32_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("triangulate_delaunay", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1389921771)
    }
    self := self
    points_ := points_
    args := []__bindgen_gde.TypePtr {
        &points_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_convex_hull :: proc "contextless" (
    self: Geometry2d,
    points_: Packed_Vector2_Array,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("convex_hull", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2004331998)
    }
    self := self
    points_ := points_
    args := []__bindgen_gde.TypePtr {
        &points_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_decompose_polygon_in_convex :: proc "contextless" (
    self: Geometry2d,
    polygon_: Packed_Vector2_Array,
) -> (ret: Typed_Array(Packed_Vector2_Array)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("decompose_polygon_in_convex", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3982393695)
    }
    self := self
    polygon_ := polygon_
    args := []__bindgen_gde.TypePtr {
        &polygon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_merge_polygons :: proc "contextless" (
    self: Geometry2d,
    polygon_a_: Packed_Vector2_Array,
    polygon_b_: Packed_Vector2_Array,
) -> (ret: Typed_Array(Packed_Vector2_Array)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("merge_polygons", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3637387053)
    }
    self := self
    polygon_a_ := polygon_a_
    polygon_b_ := polygon_b_
    args := []__bindgen_gde.TypePtr {
        &polygon_a_,
        &polygon_b_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_clip_polygons :: proc "contextless" (
    self: Geometry2d,
    polygon_a_: Packed_Vector2_Array,
    polygon_b_: Packed_Vector2_Array,
) -> (ret: Typed_Array(Packed_Vector2_Array)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clip_polygons", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3637387053)
    }
    self := self
    polygon_a_ := polygon_a_
    polygon_b_ := polygon_b_
    args := []__bindgen_gde.TypePtr {
        &polygon_a_,
        &polygon_b_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_intersect_polygons :: proc "contextless" (
    self: Geometry2d,
    polygon_a_: Packed_Vector2_Array,
    polygon_b_: Packed_Vector2_Array,
) -> (ret: Typed_Array(Packed_Vector2_Array)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersect_polygons", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3637387053)
    }
    self := self
    polygon_a_ := polygon_a_
    polygon_b_ := polygon_b_
    args := []__bindgen_gde.TypePtr {
        &polygon_a_,
        &polygon_b_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_exclude_polygons :: proc "contextless" (
    self: Geometry2d,
    polygon_a_: Packed_Vector2_Array,
    polygon_b_: Packed_Vector2_Array,
) -> (ret: Typed_Array(Packed_Vector2_Array)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("exclude_polygons", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3637387053)
    }
    self := self
    polygon_a_ := polygon_a_
    polygon_b_ := polygon_b_
    args := []__bindgen_gde.TypePtr {
        &polygon_a_,
        &polygon_b_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_clip_polyline_with_polygon :: proc "contextless" (
    self: Geometry2d,
    polyline_: Packed_Vector2_Array,
    polygon_: Packed_Vector2_Array,
) -> (ret: Typed_Array(Packed_Vector2_Array)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clip_polyline_with_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3637387053)
    }
    self := self
    polyline_ := polyline_
    polygon_ := polygon_
    args := []__bindgen_gde.TypePtr {
        &polyline_,
        &polygon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_intersect_polyline_with_polygon :: proc "contextless" (
    self: Geometry2d,
    polyline_: Packed_Vector2_Array,
    polygon_: Packed_Vector2_Array,
) -> (ret: Typed_Array(Packed_Vector2_Array)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersect_polyline_with_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3637387053)
    }
    self := self
    polyline_ := polyline_
    polygon_ := polygon_
    args := []__bindgen_gde.TypePtr {
        &polyline_,
        &polygon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_offset_polygon :: proc "contextless" (
    self: Geometry2d,
    polygon_: Packed_Vector2_Array,
    delta_: f64,
    join_type_: Geometry2d_Poly_Join_Type,
) -> (ret: Typed_Array(Packed_Vector2_Array)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("offset_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1275354010)
    }
    self := self
    polygon_ := polygon_
    delta_ := delta_
    join_type_ := join_type_
    args := []__bindgen_gde.TypePtr {
        &polygon_,
        &delta_,
        &join_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_offset_polyline :: proc "contextless" (
    self: Geometry2d,
    polyline_: Packed_Vector2_Array,
    delta_: f64,
    join_type_: Geometry2d_Poly_Join_Type,
    end_type_: Geometry2d_Poly_End_Type,
) -> (ret: Typed_Array(Packed_Vector2_Array)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("offset_polyline", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2328231778)
    }
    self := self
    polyline_ := polyline_
    delta_ := delta_
    join_type_ := join_type_
    end_type_ := end_type_
    args := []__bindgen_gde.TypePtr {
        &polyline_,
        &delta_,
        &join_type_,
        &end_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_make_atlas :: proc "contextless" (
    self: Geometry2d,
    sizes_: Packed_Vector2_Array,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_atlas", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1337682371)
    }
    self := self
    sizes_ := sizes_
    args := []__bindgen_gde.TypePtr {
        &sizes_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

geometry2d_bresenham_line :: proc "contextless" (
    self: Geometry2d,
    from_: Vector2i,
    to_: Vector2i,
) -> (ret: Typed_Array(Vector2i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("bresenham_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1989391000)
    }
    self := self
    from_ := from_
    to_ := to_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &to_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
geometry2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Geometry2D", true)
}

@(private = "file")
__class_name: String_Name