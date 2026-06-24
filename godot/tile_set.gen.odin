package godot

import __bindgen_gde "godot:gdext"

Tile_Set_Constants :: enum {
}
Tile_Set_Tile_Shape :: enum int {
    Tile_Shape_Square = 0,
    Tile_Shape_Isometric = 1,
    Tile_Shape_Half_Offset_Square = 2,
    Tile_Shape_Hexagon = 3,
}
Tile_Set_Tile_Layout :: enum int {
    Tile_Layout_Stacked = 0,
    Tile_Layout_Stacked_Offset = 1,
    Tile_Layout_Stairs_Right = 2,
    Tile_Layout_Stairs_Down = 3,
    Tile_Layout_Diamond_Right = 4,
    Tile_Layout_Diamond_Down = 5,
}
Tile_Set_Tile_Offset_Axis :: enum int {
    Tile_Offset_Axis_Horizontal = 0,
    Tile_Offset_Axis_Vertical = 1,
}
Tile_Set_Cell_Neighbor :: enum int {
    Cell_Neighbor_Right_Side = 0,
    Cell_Neighbor_Right_Corner = 1,
    Cell_Neighbor_Bottom_Right_Side = 2,
    Cell_Neighbor_Bottom_Right_Corner = 3,
    Cell_Neighbor_Bottom_Side = 4,
    Cell_Neighbor_Bottom_Corner = 5,
    Cell_Neighbor_Bottom_Left_Side = 6,
    Cell_Neighbor_Bottom_Left_Corner = 7,
    Cell_Neighbor_Left_Side = 8,
    Cell_Neighbor_Left_Corner = 9,
    Cell_Neighbor_Top_Left_Side = 10,
    Cell_Neighbor_Top_Left_Corner = 11,
    Cell_Neighbor_Top_Side = 12,
    Cell_Neighbor_Top_Corner = 13,
    Cell_Neighbor_Top_Right_Side = 14,
    Cell_Neighbor_Top_Right_Corner = 15,
}
Tile_Set_Terrain_Mode :: enum int {
    Terrain_Mode_Match_Corners_And_Sides = 0,
    Terrain_Mode_Match_Corners = 1,
    Terrain_Mode_Match_Sides = 2,
}



tile_set_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

tile_set_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_tile_set :: proc "contextless" () -> Tile_Set {
    return cast(Tile_Set)__bindgen_gde.classdb_construct_object(tile_set_name_ref())
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

tile_set_get_next_source_id :: proc "contextless" (
    self: Tile_Set,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_next_source_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_add_source :: proc "contextless" (
    self: Tile_Set,
    source_: Tile_Set_Source,
    atlas_source_id_override_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1059186179)
    }
    self := self
    source_ := source_
    atlas_source_id_override_ := atlas_source_id_override_
    args := []__bindgen_gde.TypePtr {
        &source_,
        &atlas_source_id_override_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_remove_source :: proc "contextless" (
    self: Tile_Set,
    source_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    source_id_ := source_id_
    args := []__bindgen_gde.TypePtr {
        &source_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_set_source_id :: proc "contextless" (
    self: Tile_Set,
    source_id_: Int,
    new_source_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_source_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    source_id_ := source_id_
    new_source_id_ := new_source_id_
    args := []__bindgen_gde.TypePtr {
        &source_id_,
        &new_source_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_source_count :: proc "contextless" (
    self: Tile_Set,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_source_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_get_source_id :: proc "contextless" (
    self: Tile_Set,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_source_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_has_source :: proc "contextless" (
    self: Tile_Set,
    source_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    source_id_ := source_id_
    args := []__bindgen_gde.TypePtr {
        &source_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_get_source :: proc "contextless" (
    self: Tile_Set,
    source_id_: Int,
) -> (ret: Tile_Set_Source) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_source", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1763540252)
    }
    self := self
    source_id_ := source_id_
    args := []__bindgen_gde.TypePtr {
        &source_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_tile_shape :: proc "contextless" (
    self: Tile_Set,
    shape_: Tile_Set_Tile_Shape,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tile_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2131427112)
    }
    self := self
    shape_ := shape_
    args := []__bindgen_gde.TypePtr {
        &shape_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_tile_shape :: proc "contextless" (
    self: Tile_Set,
) -> (ret: Tile_Set_Tile_Shape) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 716918169)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_tile_layout :: proc "contextless" (
    self: Tile_Set,
    layout_: Tile_Set_Tile_Layout,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tile_layout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1071216679)
    }
    self := self
    layout_ := layout_
    args := []__bindgen_gde.TypePtr {
        &layout_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_tile_layout :: proc "contextless" (
    self: Tile_Set,
) -> (ret: Tile_Set_Tile_Layout) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_layout", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 194628839)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_tile_offset_axis :: proc "contextless" (
    self: Tile_Set,
    alignment_: Tile_Set_Tile_Offset_Axis,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tile_offset_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3300198521)
    }
    self := self
    alignment_ := alignment_
    args := []__bindgen_gde.TypePtr {
        &alignment_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_tile_offset_axis :: proc "contextless" (
    self: Tile_Set,
) -> (ret: Tile_Set_Tile_Offset_Axis) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_offset_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 762494114)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_tile_size :: proc "contextless" (
    self: Tile_Set,
    size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tile_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_tile_size :: proc "contextless" (
    self: Tile_Set,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_uv_clipping :: proc "contextless" (
    self: Tile_Set,
    uv_clipping_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_uv_clipping", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    uv_clipping_ := uv_clipping_
    args := []__bindgen_gde.TypePtr {
        &uv_clipping_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_is_uv_clipping :: proc "contextless" (
    self: Tile_Set,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_uv_clipping", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_get_occlusion_layers_count :: proc "contextless" (
    self: Tile_Set,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_occlusion_layers_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_add_occlusion_layer :: proc "contextless" (
    self: Tile_Set,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_occlusion_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_move_occlusion_layer :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_occlusion_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_index_ := layer_index_
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_remove_occlusion_layer :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_occlusion_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_index_ := layer_index_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_set_occlusion_layer_light_mask :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    light_mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_occlusion_layer_light_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_index_ := layer_index_
    light_mask_ := light_mask_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &light_mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_occlusion_layer_light_mask :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_occlusion_layer_light_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    layer_index_ := layer_index_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_occlusion_layer_sdf_collision :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    sdf_collision_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_occlusion_layer_sdf_collision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    layer_index_ := layer_index_
    sdf_collision_ := sdf_collision_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &sdf_collision_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_occlusion_layer_sdf_collision :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_occlusion_layer_sdf_collision", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    layer_index_ := layer_index_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_get_physics_layers_count :: proc "contextless" (
    self: Tile_Set,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_physics_layers_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_add_physics_layer :: proc "contextless" (
    self: Tile_Set,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_physics_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_move_physics_layer :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_physics_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_index_ := layer_index_
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_remove_physics_layer :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_physics_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_index_ := layer_index_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_set_physics_layer_collision_layer :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_physics_layer_collision_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_index_ := layer_index_
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_physics_layer_collision_layer :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_physics_layer_collision_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    layer_index_ := layer_index_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_physics_layer_collision_mask :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_physics_layer_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_index_ := layer_index_
    mask_ := mask_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_physics_layer_collision_mask :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_physics_layer_collision_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    layer_index_ := layer_index_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_physics_layer_collision_priority :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    priority_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_physics_layer_collision_priority", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1602489585)
    }
    self := self
    layer_index_ := layer_index_
    priority_ := priority_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &priority_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_physics_layer_collision_priority :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_physics_layer_collision_priority", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339986948)
    }
    self := self
    layer_index_ := layer_index_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_physics_layer_physics_material :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    physics_material_: Physics_Material,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_physics_layer_physics_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1018687357)
    }
    self := self
    layer_index_ := layer_index_
    physics_material_ := physics_material_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &physics_material_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_physics_layer_physics_material :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
) -> (ret: Physics_Material) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_physics_layer_physics_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 788318639)
    }
    self := self
    layer_index_ := layer_index_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_get_terrain_sets_count :: proc "contextless" (
    self: Tile_Set,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_terrain_sets_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_add_terrain_set :: proc "contextless" (
    self: Tile_Set,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_terrain_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_move_terrain_set :: proc "contextless" (
    self: Tile_Set,
    terrain_set_: Int,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_terrain_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    terrain_set_ := terrain_set_
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &terrain_set_,
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_remove_terrain_set :: proc "contextless" (
    self: Tile_Set,
    terrain_set_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_terrain_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    terrain_set_ := terrain_set_
    args := []__bindgen_gde.TypePtr {
        &terrain_set_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_set_terrain_set_mode :: proc "contextless" (
    self: Tile_Set,
    terrain_set_: Int,
    mode_: Tile_Set_Terrain_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_terrain_set_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3943003916)
    }
    self := self
    terrain_set_ := terrain_set_
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &terrain_set_,
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_terrain_set_mode :: proc "contextless" (
    self: Tile_Set,
    terrain_set_: Int,
) -> (ret: Tile_Set_Terrain_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_terrain_set_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2084469411)
    }
    self := self
    terrain_set_ := terrain_set_
    args := []__bindgen_gde.TypePtr {
        &terrain_set_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_get_terrains_count :: proc "contextless" (
    self: Tile_Set,
    terrain_set_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_terrains_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    terrain_set_ := terrain_set_
    args := []__bindgen_gde.TypePtr {
        &terrain_set_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_add_terrain :: proc "contextless" (
    self: Tile_Set,
    terrain_set_: Int,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_terrain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1230568737)
    }
    self := self
    terrain_set_ := terrain_set_
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &terrain_set_,
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_move_terrain :: proc "contextless" (
    self: Tile_Set,
    terrain_set_: Int,
    terrain_index_: Int,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_terrain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1649997291)
    }
    self := self
    terrain_set_ := terrain_set_
    terrain_index_ := terrain_index_
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &terrain_set_,
        &terrain_index_,
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_remove_terrain :: proc "contextless" (
    self: Tile_Set,
    terrain_set_: Int,
    terrain_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_terrain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    terrain_set_ := terrain_set_
    terrain_index_ := terrain_index_
    args := []__bindgen_gde.TypePtr {
        &terrain_set_,
        &terrain_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_set_terrain_name :: proc "contextless" (
    self: Tile_Set,
    terrain_set_: Int,
    terrain_index_: Int,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_terrain_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2285447957)
    }
    self := self
    terrain_set_ := terrain_set_
    terrain_index_ := terrain_index_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &terrain_set_,
        &terrain_index_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_terrain_name :: proc "contextless" (
    self: Tile_Set,
    terrain_set_: Int,
    terrain_index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_terrain_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1391810591)
    }
    self := self
    terrain_set_ := terrain_set_
    terrain_index_ := terrain_index_
    args := []__bindgen_gde.TypePtr {
        &terrain_set_,
        &terrain_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_terrain_color :: proc "contextless" (
    self: Tile_Set,
    terrain_set_: Int,
    terrain_index_: Int,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_terrain_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3733378741)
    }
    self := self
    terrain_set_ := terrain_set_
    terrain_index_ := terrain_index_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &terrain_set_,
        &terrain_index_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_terrain_color :: proc "contextless" (
    self: Tile_Set,
    terrain_set_: Int,
    terrain_index_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_terrain_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2165839948)
    }
    self := self
    terrain_set_ := terrain_set_
    terrain_index_ := terrain_index_
    args := []__bindgen_gde.TypePtr {
        &terrain_set_,
        &terrain_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_get_navigation_layers_count :: proc "contextless" (
    self: Tile_Set,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_navigation_layers_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_add_navigation_layer :: proc "contextless" (
    self: Tile_Set,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_navigation_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_move_navigation_layer :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_navigation_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_index_ := layer_index_
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_remove_navigation_layer :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_navigation_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_index_ := layer_index_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_set_navigation_layer_layers :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    layers_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_navigation_layer_layers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_index_ := layer_index_
    layers_ := layers_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &layers_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_navigation_layer_layers :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_navigation_layer_layers", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    layer_index_ := layer_index_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_navigation_layer_layer_value :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    layer_number_: Int,
    value_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_navigation_layer_layer_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1383440665)
    }
    self := self
    layer_index_ := layer_index_
    layer_number_ := layer_number_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &layer_number_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_navigation_layer_layer_value :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    layer_number_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_navigation_layer_layer_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2522259332)
    }
    self := self
    layer_index_ := layer_index_
    layer_number_ := layer_number_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &layer_number_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_get_custom_data_layers_count :: proc "contextless" (
    self: Tile_Set,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_data_layers_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_add_custom_data_layer :: proc "contextless" (
    self: Tile_Set,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_custom_data_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_move_custom_data_layer :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_custom_data_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_index_ := layer_index_
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_remove_custom_data_layer :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_custom_data_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_index_ := layer_index_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_custom_data_layer_by_name :: proc "contextless" (
    self: Tile_Set,
    layer_name_: String,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_data_layer_by_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1321353865)
    }
    self := self
    layer_name_ := layer_name_
    args := []__bindgen_gde.TypePtr {
        &layer_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_custom_data_layer_name :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    layer_name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_data_layer_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    layer_index_ := layer_index_
    layer_name_ := layer_name_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &layer_name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_has_custom_data_layer_by_name :: proc "contextless" (
    self: Tile_Set,
    layer_name_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_custom_data_layer_by_name", true)
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

tile_set_get_custom_data_layer_name :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_data_layer_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    layer_index_ := layer_index_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_custom_data_layer_type :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
    layer_type_: __bindgen_gde.Variant_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_data_layer_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3492912874)
    }
    self := self
    layer_index_ := layer_index_
    layer_type_ := layer_type_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
        &layer_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_custom_data_layer_type :: proc "contextless" (
    self: Tile_Set,
    layer_index_: Int,
) -> (ret: __bindgen_gde.Variant_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_data_layer_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2990820875)
    }
    self := self
    layer_index_ := layer_index_
    args := []__bindgen_gde.TypePtr {
        &layer_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_set_source_level_tile_proxy :: proc "contextless" (
    self: Tile_Set,
    source_from_: Int,
    source_to_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_source_level_tile_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    source_from_ := source_from_
    source_to_ := source_to_
    args := []__bindgen_gde.TypePtr {
        &source_from_,
        &source_to_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_source_level_tile_proxy :: proc "contextless" (
    self: Tile_Set,
    source_from_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_source_level_tile_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3744713108)
    }
    self := self
    source_from_ := source_from_
    args := []__bindgen_gde.TypePtr {
        &source_from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_has_source_level_tile_proxy :: proc "contextless" (
    self: Tile_Set,
    source_from_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_source_level_tile_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3067735520)
    }
    self := self
    source_from_ := source_from_
    args := []__bindgen_gde.TypePtr {
        &source_from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_remove_source_level_tile_proxy :: proc "contextless" (
    self: Tile_Set,
    source_from_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_source_level_tile_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    source_from_ := source_from_
    args := []__bindgen_gde.TypePtr {
        &source_from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_set_coords_level_tile_proxy :: proc "contextless" (
    self: Tile_Set,
    p_source_from_: Int,
    coords_from_: Vector2i,
    source_to_: Int,
    coords_to_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_coords_level_tile_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1769939278)
    }
    self := self
    p_source_from_ := p_source_from_
    coords_from_ := coords_from_
    source_to_ := source_to_
    coords_to_ := coords_to_
    args := []__bindgen_gde.TypePtr {
        &p_source_from_,
        &coords_from_,
        &source_to_,
        &coords_to_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_coords_level_tile_proxy :: proc "contextless" (
    self: Tile_Set,
    source_from_: Int,
    coords_from_: Vector2i,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_coords_level_tile_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2856536371)
    }
    self := self
    source_from_ := source_from_
    coords_from_ := coords_from_
    args := []__bindgen_gde.TypePtr {
        &source_from_,
        &coords_from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_has_coords_level_tile_proxy :: proc "contextless" (
    self: Tile_Set,
    source_from_: Int,
    coords_from_: Vector2i,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_coords_level_tile_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3957903770)
    }
    self := self
    source_from_ := source_from_
    coords_from_ := coords_from_
    args := []__bindgen_gde.TypePtr {
        &source_from_,
        &coords_from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_remove_coords_level_tile_proxy :: proc "contextless" (
    self: Tile_Set,
    source_from_: Int,
    coords_from_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_coords_level_tile_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2311374912)
    }
    self := self
    source_from_ := source_from_
    coords_from_ := coords_from_
    args := []__bindgen_gde.TypePtr {
        &source_from_,
        &coords_from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_set_alternative_level_tile_proxy :: proc "contextless" (
    self: Tile_Set,
    source_from_: Int,
    coords_from_: Vector2i,
    alternative_from_: Int,
    source_to_: Int,
    coords_to_: Vector2i,
    alternative_to_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alternative_level_tile_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3862385460)
    }
    self := self
    source_from_ := source_from_
    coords_from_ := coords_from_
    alternative_from_ := alternative_from_
    source_to_ := source_to_
    coords_to_ := coords_to_
    alternative_to_ := alternative_to_
    args := []__bindgen_gde.TypePtr {
        &source_from_,
        &coords_from_,
        &alternative_from_,
        &source_to_,
        &coords_to_,
        &alternative_to_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_alternative_level_tile_proxy :: proc "contextless" (
    self: Tile_Set,
    source_from_: Int,
    coords_from_: Vector2i,
    alternative_from_: Int,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alternative_level_tile_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2303761075)
    }
    self := self
    source_from_ := source_from_
    coords_from_ := coords_from_
    alternative_from_ := alternative_from_
    args := []__bindgen_gde.TypePtr {
        &source_from_,
        &coords_from_,
        &alternative_from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_has_alternative_level_tile_proxy :: proc "contextless" (
    self: Tile_Set,
    source_from_: Int,
    coords_from_: Vector2i,
    alternative_from_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_alternative_level_tile_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 180086755)
    }
    self := self
    source_from_ := source_from_
    coords_from_ := coords_from_
    alternative_from_ := alternative_from_
    args := []__bindgen_gde.TypePtr {
        &source_from_,
        &coords_from_,
        &alternative_from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_remove_alternative_level_tile_proxy :: proc "contextless" (
    self: Tile_Set,
    source_from_: Int,
    coords_from_: Vector2i,
    alternative_from_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_alternative_level_tile_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2328951467)
    }
    self := self
    source_from_ := source_from_
    coords_from_ := coords_from_
    alternative_from_ := alternative_from_
    args := []__bindgen_gde.TypePtr {
        &source_from_,
        &coords_from_,
        &alternative_from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_map_tile_proxy :: proc "contextless" (
    self: Tile_Set,
    source_from_: Int,
    coords_from_: Vector2i,
    alternative_from_: Int,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("map_tile_proxy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4267935328)
    }
    self := self
    source_from_ := source_from_
    coords_from_ := coords_from_
    alternative_from_ := alternative_from_
    args := []__bindgen_gde.TypePtr {
        &source_from_,
        &coords_from_,
        &alternative_from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_cleanup_invalid_tile_proxies :: proc "contextless" (
    self: Tile_Set,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("cleanup_invalid_tile_proxies", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_clear_tile_proxies :: proc "contextless" (
    self: Tile_Set,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_tile_proxies", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_add_pattern :: proc "contextless" (
    self: Tile_Set,
    pattern_: Tile_Map_Pattern,
    index_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_pattern", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 763712015)
    }
    self := self
    pattern_ := pattern_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &pattern_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_get_pattern :: proc "contextless" (
    self: Tile_Set,
    index_: Int,
) -> (ret: Tile_Map_Pattern) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pattern", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4207737510)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_remove_pattern :: proc "contextless" (
    self: Tile_Set,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_pattern", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_get_patterns_count :: proc "contextless" (
    self: Tile_Set,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_patterns_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
tile_set_get_uv_clipping :: proc "contextless" (self: Tile_Set) -> Bool {
    return tile_set_is_uv_clipping(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
tile_set_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("TileSet", true)
}

@(private = "file")
__class_name: String_Name