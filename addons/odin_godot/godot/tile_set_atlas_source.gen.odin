package godot

import __bindgen_gde "godot:gdext"

Tile_Set_Atlas_Source_Constants :: enum {
    TRANSFORM_FLIP_H = 4096,
    TRANSFORM_FLIP_V = 8192,
    TRANSFORM_TRANSPOSE = 16384,
}
Tile_Set_Atlas_Source_Tile_Animation_Mode :: enum int {
    Tile_Animation_Mode_Default = 0,
    Tile_Animation_Mode_Random_Start_Times = 1,
    Tile_Animation_Mode_Max = 2,
}



tile_set_atlas_source_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

tile_set_atlas_source_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_tile_set_atlas_source :: proc "contextless" () -> Tile_Set_Atlas_Source {
    return cast(Tile_Set_Atlas_Source)__bindgen_gde.classdb_construct_object(tile_set_atlas_source_name_ref())
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

tile_set_atlas_source_set_texture :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_get_texture :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_set_margins :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    margins_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_margins", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    margins_ := margins_
    args := []__bindgen_gde.TypePtr {
        &margins_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_get_margins :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_margins", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_set_separation :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    separation_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_separation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    separation_ := separation_
    args := []__bindgen_gde.TypePtr {
        &separation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_get_separation :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_separation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_set_texture_region_size :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    texture_region_size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_region_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    texture_region_size_ := texture_region_size_
    args := []__bindgen_gde.TypePtr {
        &texture_region_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_get_texture_region_size :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_region_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_set_use_texture_padding :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    use_texture_padding_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_texture_padding", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    use_texture_padding_ := use_texture_padding_
    args := []__bindgen_gde.TypePtr {
        &use_texture_padding_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_get_use_texture_padding :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_use_texture_padding", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_create_tile :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_tile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 190528769)
    }
    self := self
    atlas_coords_ := atlas_coords_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_remove_tile :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_tile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    atlas_coords_ := atlas_coords_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_move_tile_in_atlas :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    new_atlas_coords_: Vector2i,
    new_size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_tile_in_atlas", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3870111920)
    }
    self := self
    atlas_coords_ := atlas_coords_
    new_atlas_coords_ := new_atlas_coords_
    new_size_ := new_size_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &new_atlas_coords_,
        &new_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_get_tile_size_in_atlas :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_size_in_atlas", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3050897911)
    }
    self := self
    atlas_coords_ := atlas_coords_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_has_room_for_tile :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    size_: Vector2i,
    animation_columns_: Int,
    animation_separation_: Vector2i,
    frames_count_: Int,
    ignored_tile_: Vector2i,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_room_for_tile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3018597268)
    }
    self := self
    atlas_coords_ := atlas_coords_
    size_ := size_
    animation_columns_ := animation_columns_
    animation_separation_ := animation_separation_
    frames_count_ := frames_count_
    ignored_tile_ := ignored_tile_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &size_,
        &animation_columns_,
        &animation_separation_,
        &frames_count_,
        &ignored_tile_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_get_tiles_to_be_removed_on_change :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    texture_: Texture2d,
    margins_: Vector2i,
    separation_: Vector2i,
    texture_region_size_: Vector2i,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tiles_to_be_removed_on_change", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1240378054)
    }
    self := self
    texture_ := texture_
    margins_ := margins_
    separation_ := separation_
    texture_region_size_ := texture_region_size_
    args := []__bindgen_gde.TypePtr {
        &texture_,
        &margins_,
        &separation_,
        &texture_region_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_get_tile_at_coords :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_at_coords", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3050897911)
    }
    self := self
    atlas_coords_ := atlas_coords_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_has_tiles_outside_texture :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_tiles_outside_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_clear_tiles_outside_texture :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_tiles_outside_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_set_tile_animation_columns :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    frame_columns_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tile_animation_columns", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3200960707)
    }
    self := self
    atlas_coords_ := atlas_coords_
    frame_columns_ := frame_columns_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &frame_columns_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_get_tile_animation_columns :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_animation_columns", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2485466453)
    }
    self := self
    atlas_coords_ := atlas_coords_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_set_tile_animation_separation :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    separation_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tile_animation_separation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1941061099)
    }
    self := self
    atlas_coords_ := atlas_coords_
    separation_ := separation_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &separation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_get_tile_animation_separation :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_animation_separation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3050897911)
    }
    self := self
    atlas_coords_ := atlas_coords_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_set_tile_animation_speed :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    speed_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tile_animation_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2262553149)
    }
    self := self
    atlas_coords_ := atlas_coords_
    speed_ := speed_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &speed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_get_tile_animation_speed :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_animation_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 719993801)
    }
    self := self
    atlas_coords_ := atlas_coords_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_set_tile_animation_mode :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    mode_: Tile_Set_Atlas_Source_Tile_Animation_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tile_animation_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3192753483)
    }
    self := self
    atlas_coords_ := atlas_coords_
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_get_tile_animation_mode :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
) -> (ret: Tile_Set_Atlas_Source_Tile_Animation_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_animation_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4025349959)
    }
    self := self
    atlas_coords_ := atlas_coords_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_set_tile_animation_frames_count :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    frames_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tile_animation_frames_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3200960707)
    }
    self := self
    atlas_coords_ := atlas_coords_
    frames_count_ := frames_count_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &frames_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_get_tile_animation_frames_count :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_animation_frames_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2485466453)
    }
    self := self
    atlas_coords_ := atlas_coords_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_set_tile_animation_frame_duration :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    frame_index_: Int,
    duration_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tile_animation_frame_duration", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2843487787)
    }
    self := self
    atlas_coords_ := atlas_coords_
    frame_index_ := frame_index_
    duration_ := duration_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &frame_index_,
        &duration_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_get_tile_animation_frame_duration :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    frame_index_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_animation_frame_duration", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1802448425)
    }
    self := self
    atlas_coords_ := atlas_coords_
    frame_index_ := frame_index_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &frame_index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_get_tile_animation_total_duration :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_animation_total_duration", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 719993801)
    }
    self := self
    atlas_coords_ := atlas_coords_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_create_alternative_tile :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    alternative_id_override_: Int,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_alternative_tile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2226298068)
    }
    self := self
    atlas_coords_ := atlas_coords_
    alternative_id_override_ := alternative_id_override_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &alternative_id_override_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_remove_alternative_tile :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    alternative_tile_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_alternative_tile", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3200960707)
    }
    self := self
    atlas_coords_ := atlas_coords_
    alternative_tile_ := alternative_tile_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &alternative_tile_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_set_alternative_tile_id :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    alternative_tile_: Int,
    new_id_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alternative_tile_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1499785778)
    }
    self := self
    atlas_coords_ := atlas_coords_
    alternative_tile_ := alternative_tile_
    new_id_ := new_id_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &alternative_tile_,
        &new_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

tile_set_atlas_source_get_next_alternative_tile_id :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_next_alternative_tile_id", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2485466453)
    }
    self := self
    atlas_coords_ := atlas_coords_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_get_tile_data :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    alternative_tile_: Int,
) -> (ret: Tile_Data) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_data", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3534028207)
    }
    self := self
    atlas_coords_ := atlas_coords_
    alternative_tile_ := alternative_tile_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &alternative_tile_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_get_atlas_grid_size :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_atlas_grid_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_get_tile_texture_region :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    frame_: Int,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tile_texture_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 241857547)
    }
    self := self
    atlas_coords_ := atlas_coords_
    frame_ := frame_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &frame_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_get_runtime_texture :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_runtime_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

tile_set_atlas_source_get_runtime_tile_texture_region :: proc "contextless" (
    self: Tile_Set_Atlas_Source,
    atlas_coords_: Vector2i,
    frame_: Int,
) -> (ret: Rect2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_runtime_tile_texture_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 104874263)
    }
    self := self
    atlas_coords_ := atlas_coords_
    frame_ := frame_
    args := []__bindgen_gde.TypePtr {
        &atlas_coords_,
        &frame_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
tile_set_atlas_source_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("TileSetAtlasSource", true)
}

@(private = "file")
__class_name: String_Name