package godot

import __bindgen_gde "godot:gdext"

Tile_Data_Constants :: enum {
}



tile_data_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

tile_data_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_tile_data :: proc "contextless" () -> Tile_Data {
    return __bindgen_gde.classdb_construct_object(tile_data_name_ref())
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

tile_data_set_flip_h :: proc "contextless" (
    self: Tile_Data,
    flip_h_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flip_h", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    flip_h_ := flip_h_
    args := []__bindgen_gde.TypePtr {
        &flip_h_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_flip_h :: proc "contextless" (
    self: Tile_Data,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_flip_h", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_flip_v :: proc "contextless" (
    self: Tile_Data,
    flip_v_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_flip_v", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    flip_v_ := flip_v_
    args := []__bindgen_gde.TypePtr {
        &flip_v_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_flip_v :: proc "contextless" (
    self: Tile_Data,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_flip_v", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_transpose :: proc "contextless" (
    self: Tile_Data,
    transpose_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transpose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    transpose_ := transpose_
    args := []__bindgen_gde.TypePtr {
        &transpose_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_transpose :: proc "contextless" (
    self: Tile_Data,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transpose", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_material :: proc "contextless" (
    self: Tile_Data,
    material_: Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2757459619)
    }
    self := self
    material_ := material_
    args := []__bindgen_gde.TypePtr {
        &material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_material :: proc "contextless" (
    self: Tile_Data,
) -> (ret: Material) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 5934680)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_texture_origin :: proc "contextless" (
    self: Tile_Data,
    texture_origin_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_origin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    texture_origin_ := texture_origin_
    args := []__bindgen_gde.TypePtr {
        &texture_origin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_texture_origin :: proc "contextless" (
    self: Tile_Data,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_origin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_modulate :: proc "contextless" (
    self: Tile_Data,
    modulate_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_modulate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    modulate_ := modulate_
    args := []__bindgen_gde.TypePtr {
        &modulate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_modulate :: proc "contextless" (
    self: Tile_Data,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_modulate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_z_index :: proc "contextless" (
    self: Tile_Data,
    z_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_z_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    z_index_ := z_index_
    args := []__bindgen_gde.TypePtr {
        &z_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_z_index :: proc "contextless" (
    self: Tile_Data,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_z_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_y_sort_origin :: proc "contextless" (
    self: Tile_Data,
    y_sort_origin_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_y_sort_origin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    y_sort_origin_ := y_sort_origin_
    args := []__bindgen_gde.TypePtr {
        &y_sort_origin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_y_sort_origin :: proc "contextless" (
    self: Tile_Data,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_y_sort_origin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_occluder_polygons_count :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    polygons_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_occluder_polygons_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_id_ := layer_id_
    polygons_count_ := polygons_count_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &polygons_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_occluder_polygons_count :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_occluder_polygons_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    layer_id_ := layer_id_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_add_occluder_polygon :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_occluder_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_id_ := layer_id_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_remove_occluder_polygon :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    polygon_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_occluder_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_id_ := layer_id_
    polygon_index_ := polygon_index_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &polygon_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_set_occluder_polygon :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    polygon_index_: Int,
    polygon_: Occluder_Polygon2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_occluder_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 164249167)
    }
    self := self
    layer_id_ := layer_id_
    polygon_index_ := polygon_index_
    polygon_ := polygon_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &polygon_index_,
        &polygon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_occluder_polygon :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    polygon_index_: Int,
    flip_h_: Bool,
    flip_v_: Bool,
    transpose_: Bool,
) -> (ret: Occluder_Polygon2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_occluder_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 971166743)
    }
    self := self
    layer_id_ := layer_id_
    polygon_index_ := polygon_index_
    flip_h_ := flip_h_
    flip_v_ := flip_v_
    transpose_ := transpose_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &polygon_index_,
        &flip_h_,
        &flip_v_,
        &transpose_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_occluder :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    occluder_polygon_: Occluder_Polygon2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_occluder", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 914399637)
    }
    self := self
    layer_id_ := layer_id_
    occluder_polygon_ := occluder_polygon_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &occluder_polygon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_occluder :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    flip_h_: Bool,
    flip_v_: Bool,
    transpose_: Bool,
) -> (ret: Occluder_Polygon2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_occluder", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2377324099)
    }
    self := self
    layer_id_ := layer_id_
    flip_h_ := flip_h_
    flip_v_ := flip_v_
    transpose_ := transpose_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &flip_h_,
        &flip_v_,
        &transpose_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_constant_linear_velocity :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    velocity_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_constant_linear_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 163021252)
    }
    self := self
    layer_id_ := layer_id_
    velocity_ := velocity_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &velocity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_constant_linear_velocity :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_constant_linear_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2299179447)
    }
    self := self
    layer_id_ := layer_id_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_constant_angular_velocity :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    velocity_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_constant_angular_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    layer_id_ := layer_id_
    velocity_ := velocity_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &velocity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_constant_angular_velocity :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_constant_angular_velocity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    layer_id_ := layer_id_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_collision_polygons_count :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    polygons_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_polygons_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_id_ := layer_id_
    polygons_count_ := polygons_count_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &polygons_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_collision_polygons_count :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_polygons_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    layer_id_ := layer_id_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_add_collision_polygon :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_collision_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_id_ := layer_id_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_remove_collision_polygon :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    polygon_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_collision_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_id_ := layer_id_
    polygon_index_ := polygon_index_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &polygon_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_set_collision_polygon_points :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    polygon_index_: Int,
    polygon_: Packed_Vector2_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_polygon_points", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3230546541)
    }
    self := self
    layer_id_ := layer_id_
    polygon_index_ := polygon_index_
    polygon_ := polygon_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &polygon_index_,
        &polygon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_collision_polygon_points :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    polygon_index_: Int,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_polygon_points", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 103942801)
    }
    self := self
    layer_id_ := layer_id_
    polygon_index_ := polygon_index_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &polygon_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_collision_polygon_one_way :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    polygon_index_: Int,
    one_way_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_polygon_one_way", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1383440665)
    }
    self := self
    layer_id_ := layer_id_
    polygon_index_ := polygon_index_
    one_way_ := one_way_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &polygon_index_,
        &one_way_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_is_collision_polygon_one_way :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    polygon_index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_collision_polygon_one_way", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2522259332)
    }
    self := self
    layer_id_ := layer_id_
    polygon_index_ := polygon_index_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &polygon_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_collision_polygon_one_way_margin :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    polygon_index_: Int,
    one_way_margin_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_polygon_one_way_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3506521499)
    }
    self := self
    layer_id_ := layer_id_
    polygon_index_ := polygon_index_
    one_way_margin_ := one_way_margin_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &polygon_index_,
        &one_way_margin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_collision_polygon_one_way_margin :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    polygon_index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_polygon_one_way_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3085491603)
    }
    self := self
    layer_id_ := layer_id_
    polygon_index_ := polygon_index_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &polygon_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_terrain_set :: proc "contextless" (
    self: Tile_Data,
    terrain_set_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_terrain_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    terrain_set_ := terrain_set_
    args := []__bindgen_gde.TypePtr {
        &terrain_set_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_terrain_set :: proc "contextless" (
    self: Tile_Data,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_terrain_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_terrain :: proc "contextless" (
    self: Tile_Data,
    terrain_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_terrain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    terrain_ := terrain_
    args := []__bindgen_gde.TypePtr {
        &terrain_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_terrain :: proc "contextless" (
    self: Tile_Data,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_terrain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_terrain_peering_bit :: proc "contextless" (
    self: Tile_Data,
    peering_bit_: Tile_Set_Cell_Neighbor,
    terrain_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_terrain_peering_bit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1084452308)
    }
    self := self
    peering_bit_ := peering_bit_
    terrain_ := terrain_
    args := []__bindgen_gde.TypePtr {
        &peering_bit_,
        &terrain_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_terrain_peering_bit :: proc "contextless" (
    self: Tile_Data,
    peering_bit_: Tile_Set_Cell_Neighbor,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_terrain_peering_bit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3831796792)
    }
    self := self
    peering_bit_ := peering_bit_
    args := []__bindgen_gde.TypePtr {
        &peering_bit_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_is_valid_terrain_peering_bit :: proc "contextless" (
    self: Tile_Data,
    peering_bit_: Tile_Set_Cell_Neighbor,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_valid_terrain_peering_bit", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 845723972)
    }
    self := self
    peering_bit_ := peering_bit_
    args := []__bindgen_gde.TypePtr {
        &peering_bit_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_navigation_polygon :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    navigation_polygon_: Navigation_Polygon,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_navigation_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2224691167)
    }
    self := self
    layer_id_ := layer_id_
    navigation_polygon_ := navigation_polygon_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &navigation_polygon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_navigation_polygon :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    flip_h_: Bool,
    flip_v_: Bool,
    transpose_: Bool,
) -> (ret: Navigation_Polygon) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_navigation_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2907127272)
    }
    self := self
    layer_id_ := layer_id_
    flip_h_ := flip_h_
    flip_v_ := flip_v_
    transpose_ := transpose_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &flip_h_,
        &flip_v_,
        &transpose_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_probability :: proc "contextless" (
    self: Tile_Data,
    probability_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_probability", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    probability_ := probability_
    args := []__bindgen_gde.TypePtr {
        &probability_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_probability :: proc "contextless" (
    self: Tile_Data,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_probability", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_custom_data :: proc "contextless" (
    self: Tile_Data,
    layer_name_: String,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 402577236)
    }
    self := self
    layer_name_ := layer_name_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &layer_name_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_custom_data :: proc "contextless" (
    self: Tile_Data,
    layer_name_: String,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1868160156)
    }
    self := self
    layer_name_ := layer_name_
    args := []__bindgen_gde.TypePtr {
        &layer_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_has_custom_data :: proc "contextless" (
    self: Tile_Data,
    layer_name_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_custom_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    layer_name_ := layer_name_
    args := []__bindgen_gde.TypePtr {
        &layer_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_data_set_custom_data_by_layer_id :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_data_by_layer_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2152698145)
    }
    self := self
    layer_id_ := layer_id_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_data_get_custom_data_by_layer_id :: proc "contextless" (
    self: Tile_Data,
    layer_id_: Int,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_data_by_layer_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4227898402)
    }
    self := self
    layer_id_ := layer_id_
    args := []__bindgen_gde.TypePtr {
        &layer_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
tile_data_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("TileData", true)
}

@(private = "file")
__class_name: String_Name