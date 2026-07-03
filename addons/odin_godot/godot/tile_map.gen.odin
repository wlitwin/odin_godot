package godot

import __bindgen_gde "godot:gdext"

Tile_Map_Constants :: enum {
}
Tile_Map_Visibility_Mode :: enum int {
    Visibility_Mode_Default = 0,
    Visibility_Mode_Force_Hide = 2,
    Visibility_Mode_Force_Show = 1,
}



tile_map_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

tile_map_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_tile_map :: proc "contextless" () -> Tile_Map {
    return __bindgen_gde.classdb_construct_object(tile_map_name_ref())
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

tile_map__use_tile_data_runtime_update :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    coords_: Vector2i,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_use_tile_data_runtime_update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3957903770)
    }
    self := self
    layer_ := layer_
    coords_ := coords_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map__tile_data_runtime_update :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    coords_: Vector2i,
    tile_data_: Tile_Data,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_tile_data_runtime_update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4223434291)
    }
    self := self
    layer_ := layer_
    coords_ := coords_
    tile_data_ := tile_data_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &coords_,
        &tile_data_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_set_navigation_map :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    map_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_navigation_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4040184819)
    }
    self := self
    layer_ := layer_
    map_ := map_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &map_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_get_navigation_map :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_navigation_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 495598643)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_force_update :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("force_update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_set_tileset :: proc "contextless" (
    self: Tile_Map,
    tileset_: Tile_Set,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tileset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 774531446)
    }
    self := self
    tileset_ := tileset_
    args := []__bindgen_gde.TypePtr {
        &tileset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_get_tileset :: proc "contextless" (
    self: Tile_Map,
) -> (ret: Tile_Set) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tileset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2678226422)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_set_rendering_quadrant_size :: proc "contextless" (
    self: Tile_Map,
    size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rendering_quadrant_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_get_rendering_quadrant_size :: proc "contextless" (
    self: Tile_Map,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rendering_quadrant_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_get_layers_count :: proc "contextless" (
    self: Tile_Map,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_layers_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_add_layer :: proc "contextless" (
    self: Tile_Map,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_move_layer :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    to_position_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_ := layer_
    to_position_ := to_position_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &to_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_remove_layer :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_set_layer_name :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    name_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layer_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 501894301)
    }
    self := self
    layer_ := layer_
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_get_layer_name :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_layer_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 844755477)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_set_layer_enabled :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layer_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    layer_ := layer_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_is_layer_enabled :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_layer_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_set_layer_modulate :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    modulate_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layer_modulate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2878471219)
    }
    self := self
    layer_ := layer_
    modulate_ := modulate_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &modulate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_get_layer_modulate :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_layer_modulate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3457211756)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_set_layer_y_sort_enabled :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    y_sort_enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layer_y_sort_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    layer_ := layer_
    y_sort_enabled_ := y_sort_enabled_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &y_sort_enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_is_layer_y_sort_enabled :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_layer_y_sort_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_set_layer_y_sort_origin :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    y_sort_origin_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layer_y_sort_origin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_ := layer_
    y_sort_origin_ := y_sort_origin_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &y_sort_origin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_get_layer_y_sort_origin :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_layer_y_sort_origin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_set_layer_z_index :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    z_index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layer_z_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    layer_ := layer_
    z_index_ := z_index_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &z_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_get_layer_z_index :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_layer_z_index", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 923996154)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_set_layer_navigation_enabled :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layer_navigation_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 300928843)
    }
    self := self
    layer_ := layer_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_is_layer_navigation_enabled :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_layer_navigation_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_set_layer_navigation_map :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    map_: Rid,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layer_navigation_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4040184819)
    }
    self := self
    layer_ := layer_
    map_ := map_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &map_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_get_layer_navigation_map :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_layer_navigation_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 495598643)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_set_collision_animatable :: proc "contextless" (
    self: Tile_Map,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_animatable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_is_collision_animatable :: proc "contextless" (
    self: Tile_Map,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_collision_animatable", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_set_collision_visibility_mode :: proc "contextless" (
    self: Tile_Map,
    collision_visibility_mode_: Tile_Map_Visibility_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_collision_visibility_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3193440636)
    }
    self := self
    collision_visibility_mode_ := collision_visibility_mode_
    args := []__bindgen_gde.TypePtr {
        &collision_visibility_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_get_collision_visibility_mode :: proc "contextless" (
    self: Tile_Map,
) -> (ret: Tile_Map_Visibility_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_collision_visibility_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1697018252)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_set_navigation_visibility_mode :: proc "contextless" (
    self: Tile_Map,
    navigation_visibility_mode_: Tile_Map_Visibility_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_navigation_visibility_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3193440636)
    }
    self := self
    navigation_visibility_mode_ := navigation_visibility_mode_
    args := []__bindgen_gde.TypePtr {
        &navigation_visibility_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_get_navigation_visibility_mode :: proc "contextless" (
    self: Tile_Map,
) -> (ret: Tile_Map_Visibility_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_navigation_visibility_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1697018252)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_set_cell :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    coords_: Vector2i,
    source_id_: Int,
    atlas_coords_: Vector2i,
    alternative_tile_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cell", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 966713560)
    }
    self := self
    layer_ := layer_
    coords_ := coords_
    source_id_ := source_id_
    atlas_coords_ := atlas_coords_
    alternative_tile_ := alternative_tile_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &coords_,
        &source_id_,
        &atlas_coords_,
        &alternative_tile_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_erase_cell :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    coords_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase_cell", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2311374912)
    }
    self := self
    layer_ := layer_
    coords_ := coords_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_get_cell_source_id :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    coords_: Vector2i,
    use_proxies_: Bool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cell_source_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 551761942)
    }
    self := self
    layer_ := layer_
    coords_ := coords_
    use_proxies_ := use_proxies_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &coords_,
        &use_proxies_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_get_cell_atlas_coords :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    coords_: Vector2i,
    use_proxies_: Bool,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cell_atlas_coords", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1869815066)
    }
    self := self
    layer_ := layer_
    coords_ := coords_
    use_proxies_ := use_proxies_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &coords_,
        &use_proxies_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_get_cell_alternative_tile :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    coords_: Vector2i,
    use_proxies_: Bool,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cell_alternative_tile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 551761942)
    }
    self := self
    layer_ := layer_
    coords_ := coords_
    use_proxies_ := use_proxies_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &coords_,
        &use_proxies_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_get_cell_tile_data :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    coords_: Vector2i,
    use_proxies_: Bool,
) -> (ret: Tile_Data) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cell_tile_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2849631287)
    }
    self := self
    layer_ := layer_
    coords_ := coords_
    use_proxies_ := use_proxies_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &coords_,
        &use_proxies_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_is_cell_flipped_h :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    coords_: Vector2i,
    use_proxies_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_cell_flipped_h", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2908343862)
    }
    self := self
    layer_ := layer_
    coords_ := coords_
    use_proxies_ := use_proxies_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &coords_,
        &use_proxies_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_is_cell_flipped_v :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    coords_: Vector2i,
    use_proxies_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_cell_flipped_v", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2908343862)
    }
    self := self
    layer_ := layer_
    coords_ := coords_
    use_proxies_ := use_proxies_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &coords_,
        &use_proxies_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_is_cell_transposed :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    coords_: Vector2i,
    use_proxies_: Bool,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_cell_transposed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2908343862)
    }
    self := self
    layer_ := layer_
    coords_ := coords_
    use_proxies_ := use_proxies_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &coords_,
        &use_proxies_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_get_coords_for_body_rid :: proc "contextless" (
    self: Tile_Map,
    body_: Rid,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_coords_for_body_rid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 291584212)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_get_layer_for_body_rid :: proc "contextless" (
    self: Tile_Map,
    body_: Rid,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_layer_for_body_rid", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3917799429)
    }
    self := self
    body_ := body_
    args := []__bindgen_gde.TypePtr {
        &body_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_get_pattern :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    coords_array_: Typed_Array(Vector2i),
) -> (ret: Tile_Map_Pattern) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pattern", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2833570986)
    }
    self := self
    layer_ := layer_
    coords_array_ := coords_array_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &coords_array_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_map_pattern :: proc "contextless" (
    self: Tile_Map,
    position_in_tilemap_: Vector2i,
    coords_in_pattern_: Vector2i,
    pattern_: Tile_Map_Pattern,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("map_pattern", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1864516957)
    }
    self := self
    position_in_tilemap_ := position_in_tilemap_
    coords_in_pattern_ := coords_in_pattern_
    pattern_ := pattern_
    args := []__bindgen_gde.TypePtr {
        &position_in_tilemap_,
        &coords_in_pattern_,
        &pattern_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_set_pattern :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    position_: Vector2i,
    pattern_: Tile_Map_Pattern,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_pattern", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1195853946)
    }
    self := self
    layer_ := layer_
    position_ := position_
    pattern_ := pattern_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &position_,
        &pattern_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_set_cells_terrain_connect :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    cells_: Typed_Array(Vector2i),
    terrain_set_: Int,
    terrain_: Int,
    ignore_empty_terrains_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cells_terrain_connect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3578627656)
    }
    self := self
    layer_ := layer_
    cells_ := cells_
    terrain_set_ := terrain_set_
    terrain_ := terrain_
    ignore_empty_terrains_ := ignore_empty_terrains_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &cells_,
        &terrain_set_,
        &terrain_,
        &ignore_empty_terrains_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_set_cells_terrain_path :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    path_: Typed_Array(Vector2i),
    terrain_set_: Int,
    terrain_: Int,
    ignore_empty_terrains_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cells_terrain_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3578627656)
    }
    self := self
    layer_ := layer_
    path_ := path_
    terrain_set_ := terrain_set_
    terrain_ := terrain_
    ignore_empty_terrains_ := ignore_empty_terrains_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &path_,
        &terrain_set_,
        &terrain_,
        &ignore_empty_terrains_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_fix_invalid_tiles :: proc "contextless" (
    self: Tile_Map,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("fix_invalid_tiles", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_clear_layer :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_clear :: proc "contextless" (
    self: Tile_Map,
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

tile_map_update_internals :: proc "contextless" (
    self: Tile_Map,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("update_internals", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_notify_runtime_tile_data_update :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("notify_runtime_tile_data_update", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1025054187)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_map_get_surrounding_cells :: proc "contextless" (
    self: Tile_Map,
    coords_: Vector2i,
) -> (ret: Typed_Array(Vector2i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_surrounding_cells", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2673526557)
    }
    self := self
    coords_ := coords_
    args := []__bindgen_gde.TypePtr {
        &coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_get_used_cells :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
) -> (ret: Typed_Array(Vector2i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_used_cells", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 663333327)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_get_used_cells_by_id :: proc "contextless" (
    self: Tile_Map,
    layer_: Int,
    source_id_: Int,
    atlas_coords_: Vector2i,
    alternative_tile_: Int,
) -> (ret: Typed_Array(Vector2i)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_used_cells_by_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2931012785)
    }
    self := self
    layer_ := layer_
    source_id_ := source_id_
    atlas_coords_ := atlas_coords_
    alternative_tile_ := alternative_tile_
    args := []__bindgen_gde.TypePtr {
        &layer_,
        &source_id_,
        &atlas_coords_,
        &alternative_tile_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_get_used_rect :: proc "contextless" (
    self: Tile_Map,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_used_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 410525958)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_map_to_local :: proc "contextless" (
    self: Tile_Map,
    map_position_: Vector2i,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("map_to_local", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 108438297)
    }
    self := self
    map_position_ := map_position_
    args := []__bindgen_gde.TypePtr {
        &map_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_local_to_map :: proc "contextless" (
    self: Tile_Map,
    local_position_: Vector2,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("local_to_map", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 837806996)
    }
    self := self
    local_position_ := local_position_
    args := []__bindgen_gde.TypePtr {
        &local_position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_map_get_neighbor_cell :: proc "contextless" (
    self: Tile_Map,
    coords_: Vector2i,
    neighbor_: Tile_Set_Cell_Neighbor,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_neighbor_cell", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 986575103)
    }
    self := self
    coords_ := coords_
    neighbor_ := neighbor_
    args := []__bindgen_gde.TypePtr {
        &coords_,
        &neighbor_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
tile_map_get_tile_set :: proc "contextless" (self: Tile_Map) -> Tile_Set {
    return tile_map_get_tileset(self)
}
tile_map_set_tile_set :: proc "contextless" (self: Tile_Map, value: Tile_Set) {
    tile_map_set_tileset(self, value)
}
tile_map_get_collision_animatable :: proc "contextless" (self: Tile_Map) -> Bool {
    return tile_map_is_collision_animatable(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
tile_map_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("TileMap", true)
}

@(private = "file")
__class_name: String_Name