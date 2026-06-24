package godot

import __bindgen_gde "godot:gdext"

A_Star_Grid2d_Constants :: enum {
}
A_Star_Grid2d_Heuristic :: enum int {
    Heuristic_Euclidean = 0,
    Heuristic_Manhattan = 1,
    Heuristic_Octile = 2,
    Heuristic_Chebyshev = 3,
    Heuristic_Max = 4,
}
A_Star_Grid2d_Diagonal_Mode :: enum int {
    Diagonal_Mode_Always = 0,
    Diagonal_Mode_Never = 1,
    Diagonal_Mode_At_Least_One_Walkable = 2,
    Diagonal_Mode_Only_If_No_Obstacles = 3,
    Diagonal_Mode_Max = 4,
}
A_Star_Grid2d_Cell_Shape :: enum int {
    Cell_Shape_Square = 0,
    Cell_Shape_Isometric_Right = 1,
    Cell_Shape_Isometric_Down = 2,
    Cell_Shape_Max = 3,
}



a_star_grid2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

a_star_grid2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_a_star_grid2d :: proc "contextless" () -> A_Star_Grid2d {
    return cast(A_Star_Grid2d)__bindgen_gde.classdb_construct_object(a_star_grid2d_name_ref())
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

a_star_grid2d__estimate_cost :: proc "contextless" (
    self: A_Star_Grid2d,
    from_id_: Vector2i,
    end_id_: Vector2i,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_estimate_cost", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2153177966)
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

a_star_grid2d__compute_cost :: proc "contextless" (
    self: A_Star_Grid2d,
    from_id_: Vector2i,
    to_id_: Vector2i,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_compute_cost", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2153177966)
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

a_star_grid2d_set_region :: proc "contextless" (
    self: A_Star_Grid2d,
    region_: Rect2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1763793166)
    }
    self := self
    region_ := region_
    args := []__bindgen_gde.TypePtr {
        &region_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star_grid2d_get_region :: proc "contextless" (
    self: A_Star_Grid2d,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 410525958)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_set_size :: proc "contextless" (
    self: A_Star_Grid2d,
    size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star_grid2d_get_size :: proc "contextless" (
    self: A_Star_Grid2d,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_set_offset :: proc "contextless" (
    self: A_Star_Grid2d,
    offset_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star_grid2d_get_offset :: proc "contextless" (
    self: A_Star_Grid2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_set_cell_size :: proc "contextless" (
    self: A_Star_Grid2d,
    cell_size_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cell_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    cell_size_ := cell_size_
    args := []__bindgen_gde.TypePtr {
        &cell_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star_grid2d_get_cell_size :: proc "contextless" (
    self: A_Star_Grid2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cell_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_set_cell_shape :: proc "contextless" (
    self: A_Star_Grid2d,
    cell_shape_: A_Star_Grid2d_Cell_Shape,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cell_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4130591146)
    }
    self := self
    cell_shape_ := cell_shape_
    args := []__bindgen_gde.TypePtr {
        &cell_shape_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star_grid2d_get_cell_shape :: proc "contextless" (
    self: A_Star_Grid2d,
) -> (ret: A_Star_Grid2d_Cell_Shape) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cell_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3293463634)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_is_in_bounds :: proc "contextless" (
    self: A_Star_Grid2d,
    x_: Int,
    y_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_in_bounds", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2522259332)
    }
    self := self
    x_ := x_
    y_ := y_
    args := []__bindgen_gde.TypePtr {
        &x_,
        &y_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_is_in_boundsv :: proc "contextless" (
    self: A_Star_Grid2d,
    id_: Vector2i,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_in_boundsv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3900751641)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_is_dirty :: proc "contextless" (
    self: A_Star_Grid2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_dirty", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_update :: proc "contextless" (
    self: A_Star_Grid2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star_grid2d_set_jumping_enabled :: proc "contextless" (
    self: A_Star_Grid2d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_jumping_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star_grid2d_is_jumping_enabled :: proc "contextless" (
    self: A_Star_Grid2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_jumping_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_set_diagonal_mode :: proc "contextless" (
    self: A_Star_Grid2d,
    mode_: A_Star_Grid2d_Diagonal_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_diagonal_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1017829798)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star_grid2d_get_diagonal_mode :: proc "contextless" (
    self: A_Star_Grid2d,
) -> (ret: A_Star_Grid2d_Diagonal_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_diagonal_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3129282674)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_set_default_compute_heuristic :: proc "contextless" (
    self: A_Star_Grid2d,
    heuristic_: A_Star_Grid2d_Heuristic,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_default_compute_heuristic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1044375519)
    }
    self := self
    heuristic_ := heuristic_
    args := []__bindgen_gde.TypePtr {
        &heuristic_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star_grid2d_get_default_compute_heuristic :: proc "contextless" (
    self: A_Star_Grid2d,
) -> (ret: A_Star_Grid2d_Heuristic) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_default_compute_heuristic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2074731422)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_set_default_estimate_heuristic :: proc "contextless" (
    self: A_Star_Grid2d,
    heuristic_: A_Star_Grid2d_Heuristic,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_default_estimate_heuristic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1044375519)
    }
    self := self
    heuristic_ := heuristic_
    args := []__bindgen_gde.TypePtr {
        &heuristic_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star_grid2d_get_default_estimate_heuristic :: proc "contextless" (
    self: A_Star_Grid2d,
) -> (ret: A_Star_Grid2d_Heuristic) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_default_estimate_heuristic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2074731422)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_set_point_solid :: proc "contextless" (
    self: A_Star_Grid2d,
    id_: Vector2i,
    solid_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_point_solid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1765703753)
    }
    self := self
    id_ := id_
    solid_ := solid_
    args := []__bindgen_gde.TypePtr {
        &id_,
        &solid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star_grid2d_is_point_solid :: proc "contextless" (
    self: A_Star_Grid2d,
    id_: Vector2i,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_point_solid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3900751641)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_set_point_weight_scale :: proc "contextless" (
    self: A_Star_Grid2d,
    id_: Vector2i,
    weight_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_point_weight_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2262553149)
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

a_star_grid2d_get_point_weight_scale :: proc "contextless" (
    self: A_Star_Grid2d,
    id_: Vector2i,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_weight_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 719993801)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_fill_solid_region :: proc "contextless" (
    self: A_Star_Grid2d,
    region_: Rect2i,
    solid_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("fill_solid_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2261970063)
    }
    self := self
    region_ := region_
    solid_ := solid_
    args := []__bindgen_gde.TypePtr {
        &region_,
        &solid_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star_grid2d_fill_weight_scale_region :: proc "contextless" (
    self: A_Star_Grid2d,
    region_: Rect2i,
    weight_scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("fill_weight_scale_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2793244083)
    }
    self := self
    region_ := region_
    weight_scale_ := weight_scale_
    args := []__bindgen_gde.TypePtr {
        &region_,
        &weight_scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

a_star_grid2d_clear :: proc "contextless" (
    self: A_Star_Grid2d,
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

a_star_grid2d_get_point_position :: proc "contextless" (
    self: A_Star_Grid2d,
    id_: Vector2i,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 108438297)
    }
    self := self
    id_ := id_
    args := []__bindgen_gde.TypePtr {
        &id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_get_point_data_in_region :: proc "contextless" (
    self: A_Star_Grid2d,
    region_: Rect2i,
) -> (ret: Typed_Array(Dictionary)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_data_in_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3893818462)
    }
    self := self
    region_ := region_
    args := []__bindgen_gde.TypePtr {
        &region_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

a_star_grid2d_get_point_path :: proc "contextless" (
    self: A_Star_Grid2d,
    from_id_: Vector2i,
    to_id_: Vector2i,
    allow_partial_path_: Bool,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1641925693)
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

a_star_grid2d_get_id_path :: proc "contextless" (
    self: A_Star_Grid2d,
    from_id_: Vector2i,
    to_id_: Vector2i,
    allow_partial_path_: Bool,
) -> (ret: Typed_Array(Vector2i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_id_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1918132273)
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
a_star_grid2d_get_jumping_enabled :: proc "contextless" (self: A_Star_Grid2d) -> Bool {
    return a_star_grid2d_is_jumping_enabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
a_star_grid2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AStarGrid2D", true)
}

@(private = "file")
__class_name: String_Name