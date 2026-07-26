package godot

import __bindgen_gde "godot:gdext"

Canvas_Item_Constants :: enum {
    NOTIFICATION_TRANSFORM_CHANGED = 2000,
    NOTIFICATION_LOCAL_TRANSFORM_CHANGED = 35,
    NOTIFICATION_DRAW = 30,
    NOTIFICATION_VISIBILITY_CHANGED = 31,
    NOTIFICATION_ENTER_CANVAS = 32,
    NOTIFICATION_EXIT_CANVAS = 33,
    NOTIFICATION_WORLD_2D_CHANGED = 36,
}
Canvas_Item_Texture_Filter :: enum int {
    Texture_Filter_Parent_Node = 0,
    Texture_Filter_Nearest = 1,
    Texture_Filter_Linear = 2,
    Texture_Filter_Nearest_With_Mipmaps = 3,
    Texture_Filter_Linear_With_Mipmaps = 4,
    Texture_Filter_Nearest_With_Mipmaps_Anisotropic = 5,
    Texture_Filter_Linear_With_Mipmaps_Anisotropic = 6,
    Texture_Filter_Max = 7,
}
Canvas_Item_Texture_Repeat :: enum int {
    Texture_Repeat_Parent_Node = 0,
    Texture_Repeat_Disabled = 1,
    Texture_Repeat_Enabled = 2,
    Texture_Repeat_Mirror = 3,
    Texture_Repeat_Max = 4,
}
Canvas_Item_Clip_Children_Mode :: enum int {
    Clip_Children_Disabled = 0,
    Clip_Children_Only = 1,
    Clip_Children_And_Draw = 2,
    Clip_Children_Max = 3,
}
Canvas_Item_Oversampling_With_Scale :: enum int {
    Oversampling_With_Scale_Parent_Node = 0,
    Oversampling_With_Scale_Disabled = 1,
    Oversampling_With_Scale_Enabled = 2,
    Oversampling_With_Scale_Max = 3,
}



canvas_item_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

canvas_item_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_canvas_item :: proc "contextless" () -> Canvas_Item {
    return __bindgen_gde.classdb_construct_object(canvas_item_name_ref())
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

canvas_item__draw :: proc "contextless" (
    self: Canvas_Item,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_get_canvas_item :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_canvas_item", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2944877500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_visible :: proc "contextless" (
    self: Canvas_Item,
    visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    visible_ := visible_
    args := []__bindgen_gde.TypePtr {
        &visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_is_visible :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_is_visible_in_tree :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_visible_in_tree", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_show :: proc "contextless" (
    self: Canvas_Item,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("show", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_hide :: proc "contextless" (
    self: Canvas_Item,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("hide", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_queue_redraw :: proc "contextless" (
    self: Canvas_Item,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("queue_redraw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_move_to_front :: proc "contextless" (
    self: Canvas_Item,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_to_front", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_set_as_top_level :: proc "contextless" (
    self: Canvas_Item,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_as_top_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_is_set_as_top_level :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_set_as_top_level", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_light_mask :: proc "contextless" (
    self: Canvas_Item,
    light_mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_light_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    light_mask_ := light_mask_
    args := []__bindgen_gde.TypePtr {
        &light_mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_get_light_mask :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_light_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_modulate :: proc "contextless" (
    self: Canvas_Item,
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

canvas_item_get_modulate :: proc "contextless" (
    self: Canvas_Item,
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

canvas_item_set_self_modulate :: proc "contextless" (
    self: Canvas_Item,
    self_modulate_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_self_modulate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    self_modulate_ := self_modulate_
    args := []__bindgen_gde.TypePtr {
        &self_modulate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_get_self_modulate :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_self_modulate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_z_index :: proc "contextless" (
    self: Canvas_Item,
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

canvas_item_get_z_index :: proc "contextless" (
    self: Canvas_Item,
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

canvas_item_set_z_as_relative :: proc "contextless" (
    self: Canvas_Item,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_z_as_relative", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_is_z_relative :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_z_relative", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_y_sort_enabled :: proc "contextless" (
    self: Canvas_Item,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_y_sort_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_is_y_sort_enabled :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_y_sort_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_draw_behind_parent :: proc "contextless" (
    self: Canvas_Item,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_behind_parent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_is_draw_behind_parent_enabled :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_draw_behind_parent_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_draw_line :: proc "contextless" (
    self: Canvas_Item,
    from_: Vector2,
    to_: Vector2,
    color_: Color,
    width_: f64,
    antialiased_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1562330099)
    }
    self := self
    from_ := from_
    to_ := to_
    color_ := color_
    width_ := width_
    antialiased_ := antialiased_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &to_,
        &color_,
        &width_,
        &antialiased_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_dashed_line :: proc "contextless" (
    self: Canvas_Item,
    from_: Vector2,
    to_: Vector2,
    color_: Color,
    width_: f64,
    dash_: f64,
    aligned_: Bool,
    antialiased_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_dashed_line", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3653831622)
    }
    self := self
    from_ := from_
    to_ := to_
    color_ := color_
    width_ := width_
    dash_ := dash_
    aligned_ := aligned_
    antialiased_ := antialiased_
    args := []__bindgen_gde.TypePtr {
        &from_,
        &to_,
        &color_,
        &width_,
        &dash_,
        &aligned_,
        &antialiased_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_polyline :: proc "contextless" (
    self: Canvas_Item,
    points_: Packed_Vector2_Array,
    color_: Color,
    width_: f64,
    antialiased_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_polyline", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3797364428)
    }
    self := self
    points_ := points_
    color_ := color_
    width_ := width_
    antialiased_ := antialiased_
    args := []__bindgen_gde.TypePtr {
        &points_,
        &color_,
        &width_,
        &antialiased_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_polyline_colors :: proc "contextless" (
    self: Canvas_Item,
    points_: Packed_Vector2_Array,
    colors_: Packed_Color_Array,
    width_: f64,
    antialiased_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_polyline_colors", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2311979562)
    }
    self := self
    points_ := points_
    colors_ := colors_
    width_ := width_
    antialiased_ := antialiased_
    args := []__bindgen_gde.TypePtr {
        &points_,
        &colors_,
        &width_,
        &antialiased_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_ellipse_arc :: proc "contextless" (
    self: Canvas_Item,
    center_: Vector2,
    major_: f64,
    minor_: f64,
    start_angle_: f64,
    end_angle_: f64,
    point_count_: Int,
    color_: Color,
    width_: f64,
    antialiased_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_ellipse_arc", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 936174114)
    }
    self := self
    center_ := center_
    major_ := major_
    minor_ := minor_
    start_angle_ := start_angle_
    end_angle_ := end_angle_
    point_count_ := point_count_
    color_ := color_
    width_ := width_
    antialiased_ := antialiased_
    args := []__bindgen_gde.TypePtr {
        &center_,
        &major_,
        &minor_,
        &start_angle_,
        &end_angle_,
        &point_count_,
        &color_,
        &width_,
        &antialiased_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_arc :: proc "contextless" (
    self: Canvas_Item,
    center_: Vector2,
    radius_: f64,
    start_angle_: f64,
    end_angle_: f64,
    point_count_: Int,
    color_: Color,
    width_: f64,
    antialiased_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_arc", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4140652635)
    }
    self := self
    center_ := center_
    radius_ := radius_
    start_angle_ := start_angle_
    end_angle_ := end_angle_
    point_count_ := point_count_
    color_ := color_
    width_ := width_
    antialiased_ := antialiased_
    args := []__bindgen_gde.TypePtr {
        &center_,
        &radius_,
        &start_angle_,
        &end_angle_,
        &point_count_,
        &color_,
        &width_,
        &antialiased_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_multiline :: proc "contextless" (
    self: Canvas_Item,
    points_: Packed_Vector2_Array,
    color_: Color,
    width_: f64,
    antialiased_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_multiline", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3797364428)
    }
    self := self
    points_ := points_
    color_ := color_
    width_ := width_
    antialiased_ := antialiased_
    args := []__bindgen_gde.TypePtr {
        &points_,
        &color_,
        &width_,
        &antialiased_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_multiline_colors :: proc "contextless" (
    self: Canvas_Item,
    points_: Packed_Vector2_Array,
    colors_: Packed_Color_Array,
    width_: f64,
    antialiased_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_multiline_colors", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2311979562)
    }
    self := self
    points_ := points_
    colors_ := colors_
    width_ := width_
    antialiased_ := antialiased_
    args := []__bindgen_gde.TypePtr {
        &points_,
        &colors_,
        &width_,
        &antialiased_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_rect :: proc "contextless" (
    self: Canvas_Item,
    rect_: Rect2,
    color_: Color,
    filled_: Bool,
    width_: f64,
    antialiased_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2773573813)
    }
    self := self
    rect_ := rect_
    color_ := color_
    filled_ := filled_
    width_ := width_
    antialiased_ := antialiased_
    args := []__bindgen_gde.TypePtr {
        &rect_,
        &color_,
        &filled_,
        &width_,
        &antialiased_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_circle :: proc "contextless" (
    self: Canvas_Item,
    position_: Vector2,
    radius_: f64,
    color_: Color,
    filled_: Bool,
    width_: f64,
    antialiased_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_circle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3153026596)
    }
    self := self
    position_ := position_
    radius_ := radius_
    color_ := color_
    filled_ := filled_
    width_ := width_
    antialiased_ := antialiased_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &radius_,
        &color_,
        &filled_,
        &width_,
        &antialiased_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_ellipse :: proc "contextless" (
    self: Canvas_Item,
    position_: Vector2,
    major_: f64,
    minor_: f64,
    color_: Color,
    filled_: Bool,
    width_: f64,
    antialiased_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_ellipse", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3790774806)
    }
    self := self
    position_ := position_
    major_ := major_
    minor_ := minor_
    color_ := color_
    filled_ := filled_
    width_ := width_
    antialiased_ := antialiased_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &major_,
        &minor_,
        &color_,
        &filled_,
        &width_,
        &antialiased_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_texture :: proc "contextless" (
    self: Canvas_Item,
    texture_: Texture2d,
    position_: Vector2,
    modulate_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 520200117)
    }
    self := self
    texture_ := texture_
    position_ := position_
    modulate_ := modulate_
    args := []__bindgen_gde.TypePtr {
        &texture_,
        &position_,
        &modulate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_texture_rect :: proc "contextless" (
    self: Canvas_Item,
    texture_: Texture2d,
    rect_: Rect2,
    tile_: Bool,
    modulate_: Color,
    transpose_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_texture_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3832805018)
    }
    self := self
    texture_ := texture_
    rect_ := rect_
    tile_ := tile_
    modulate_ := modulate_
    transpose_ := transpose_
    args := []__bindgen_gde.TypePtr {
        &texture_,
        &rect_,
        &tile_,
        &modulate_,
        &transpose_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_texture_rect_region :: proc "contextless" (
    self: Canvas_Item,
    texture_: Texture2d,
    rect_: Rect2,
    src_rect_: Rect2,
    modulate_: Color,
    transpose_: Bool,
    clip_uv_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_texture_rect_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3883821411)
    }
    self := self
    texture_ := texture_
    rect_ := rect_
    src_rect_ := src_rect_
    modulate_ := modulate_
    transpose_ := transpose_
    clip_uv_ := clip_uv_
    args := []__bindgen_gde.TypePtr {
        &texture_,
        &rect_,
        &src_rect_,
        &modulate_,
        &transpose_,
        &clip_uv_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_msdf_texture_rect_region :: proc "contextless" (
    self: Canvas_Item,
    texture_: Texture2d,
    rect_: Rect2,
    src_rect_: Rect2,
    modulate_: Color,
    outline_: f64,
    pixel_range_: f64,
    scale_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_msdf_texture_rect_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4219163252)
    }
    self := self
    texture_ := texture_
    rect_ := rect_
    src_rect_ := src_rect_
    modulate_ := modulate_
    outline_ := outline_
    pixel_range_ := pixel_range_
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &texture_,
        &rect_,
        &src_rect_,
        &modulate_,
        &outline_,
        &pixel_range_,
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_lcd_texture_rect_region :: proc "contextless" (
    self: Canvas_Item,
    texture_: Texture2d,
    rect_: Rect2,
    src_rect_: Rect2,
    modulate_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_lcd_texture_rect_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3212350954)
    }
    self := self
    texture_ := texture_
    rect_ := rect_
    src_rect_ := src_rect_
    modulate_ := modulate_
    args := []__bindgen_gde.TypePtr {
        &texture_,
        &rect_,
        &src_rect_,
        &modulate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_style_box :: proc "contextless" (
    self: Canvas_Item,
    style_box_: Style_Box,
    rect_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_style_box", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 388176283)
    }
    self := self
    style_box_ := style_box_
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &style_box_,
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_primitive :: proc "contextless" (
    self: Canvas_Item,
    points_: Packed_Vector2_Array,
    colors_: Packed_Color_Array,
    uvs_: Packed_Vector2_Array,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_primitive", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3288481815)
    }
    self := self
    points_ := points_
    colors_ := colors_
    uvs_ := uvs_
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &points_,
        &colors_,
        &uvs_,
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_polygon :: proc "contextless" (
    self: Canvas_Item,
    points_: Packed_Vector2_Array,
    colors_: Packed_Color_Array,
    uvs_: Packed_Vector2_Array,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 974537912)
    }
    self := self
    points_ := points_
    colors_ := colors_
    uvs_ := uvs_
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &points_,
        &colors_,
        &uvs_,
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_colored_polygon :: proc "contextless" (
    self: Canvas_Item,
    points_: Packed_Vector2_Array,
    color_: Color,
    uvs_: Packed_Vector2_Array,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_colored_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 15245644)
    }
    self := self
    points_ := points_
    color_ := color_
    uvs_ := uvs_
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &points_,
        &color_,
        &uvs_,
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_string :: proc "contextless" (
    self: Canvas_Item,
    font_: Font,
    pos_: Vector2,
    text_: String,
    alignment_: Horizontal_Alignment,
    width_: f64,
    font_size_: Int,
    modulate_: Color,
    justification_flags_: Text_Server_Justification_Flag,
    direction_: Text_Server_Direction,
    orientation_: Text_Server_Orientation,
    oversampling_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 719605945)
    }
    self := self
    font_ := font_
    pos_ := pos_
    text_ := text_
    alignment_ := alignment_
    width_ := width_
    font_size_ := font_size_
    modulate_ := modulate_
    justification_flags_ := justification_flags_
    direction_ := direction_
    orientation_ := orientation_
    oversampling_ := oversampling_
    args := []__bindgen_gde.TypePtr {
        &font_,
        &pos_,
        &text_,
        &alignment_,
        &width_,
        &font_size_,
        &modulate_,
        &justification_flags_,
        &direction_,
        &orientation_,
        &oversampling_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_multiline_string :: proc "contextless" (
    self: Canvas_Item,
    font_: Font,
    pos_: Vector2,
    text_: String,
    alignment_: Horizontal_Alignment,
    width_: f64,
    font_size_: Int,
    max_lines_: Int,
    modulate_: Color,
    brk_flags_: Text_Server_Line_Break_Flag,
    justification_flags_: Text_Server_Justification_Flag,
    direction_: Text_Server_Direction,
    orientation_: Text_Server_Orientation,
    oversampling_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_multiline_string", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2341488182)
    }
    self := self
    font_ := font_
    pos_ := pos_
    text_ := text_
    alignment_ := alignment_
    width_ := width_
    font_size_ := font_size_
    max_lines_ := max_lines_
    modulate_ := modulate_
    brk_flags_ := brk_flags_
    justification_flags_ := justification_flags_
    direction_ := direction_
    orientation_ := orientation_
    oversampling_ := oversampling_
    args := []__bindgen_gde.TypePtr {
        &font_,
        &pos_,
        &text_,
        &alignment_,
        &width_,
        &font_size_,
        &max_lines_,
        &modulate_,
        &brk_flags_,
        &justification_flags_,
        &direction_,
        &orientation_,
        &oversampling_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_string_outline :: proc "contextless" (
    self: Canvas_Item,
    font_: Font,
    pos_: Vector2,
    text_: String,
    alignment_: Horizontal_Alignment,
    width_: f64,
    font_size_: Int,
    size_: Int,
    modulate_: Color,
    justification_flags_: Text_Server_Justification_Flag,
    direction_: Text_Server_Direction,
    orientation_: Text_Server_Orientation,
    oversampling_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_string_outline", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 707403449)
    }
    self := self
    font_ := font_
    pos_ := pos_
    text_ := text_
    alignment_ := alignment_
    width_ := width_
    font_size_ := font_size_
    size_ := size_
    modulate_ := modulate_
    justification_flags_ := justification_flags_
    direction_ := direction_
    orientation_ := orientation_
    oversampling_ := oversampling_
    args := []__bindgen_gde.TypePtr {
        &font_,
        &pos_,
        &text_,
        &alignment_,
        &width_,
        &font_size_,
        &size_,
        &modulate_,
        &justification_flags_,
        &direction_,
        &orientation_,
        &oversampling_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_multiline_string_outline :: proc "contextless" (
    self: Canvas_Item,
    font_: Font,
    pos_: Vector2,
    text_: String,
    alignment_: Horizontal_Alignment,
    width_: f64,
    font_size_: Int,
    max_lines_: Int,
    size_: Int,
    modulate_: Color,
    brk_flags_: Text_Server_Line_Break_Flag,
    justification_flags_: Text_Server_Justification_Flag,
    direction_: Text_Server_Direction,
    orientation_: Text_Server_Orientation,
    oversampling_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_multiline_string_outline", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3050414441)
    }
    self := self
    font_ := font_
    pos_ := pos_
    text_ := text_
    alignment_ := alignment_
    width_ := width_
    font_size_ := font_size_
    max_lines_ := max_lines_
    size_ := size_
    modulate_ := modulate_
    brk_flags_ := brk_flags_
    justification_flags_ := justification_flags_
    direction_ := direction_
    orientation_ := orientation_
    oversampling_ := oversampling_
    args := []__bindgen_gde.TypePtr {
        &font_,
        &pos_,
        &text_,
        &alignment_,
        &width_,
        &font_size_,
        &max_lines_,
        &size_,
        &modulate_,
        &brk_flags_,
        &justification_flags_,
        &direction_,
        &orientation_,
        &oversampling_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_char :: proc "contextless" (
    self: Canvas_Item,
    font_: Font,
    pos_: Vector2,
    char_: String,
    font_size_: Int,
    modulate_: Color,
    oversampling_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_char", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1336210142)
    }
    self := self
    font_ := font_
    pos_ := pos_
    char_ := char_
    font_size_ := font_size_
    modulate_ := modulate_
    oversampling_ := oversampling_
    args := []__bindgen_gde.TypePtr {
        &font_,
        &pos_,
        &char_,
        &font_size_,
        &modulate_,
        &oversampling_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_char_outline :: proc "contextless" (
    self: Canvas_Item,
    font_: Font,
    pos_: Vector2,
    char_: String,
    font_size_: Int,
    size_: Int,
    modulate_: Color,
    oversampling_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_char_outline", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1846384149)
    }
    self := self
    font_ := font_
    pos_ := pos_
    char_ := char_
    font_size_ := font_size_
    size_ := size_
    modulate_ := modulate_
    oversampling_ := oversampling_
    args := []__bindgen_gde.TypePtr {
        &font_,
        &pos_,
        &char_,
        &font_size_,
        &size_,
        &modulate_,
        &oversampling_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_mesh :: proc "contextless" (
    self: Canvas_Item,
    mesh_: Mesh,
    texture_: Texture2d,
    transform_: Transform2d,
    modulate_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 153818295)
    }
    self := self
    mesh_ := mesh_
    texture_ := texture_
    transform_ := transform_
    modulate_ := modulate_
    args := []__bindgen_gde.TypePtr {
        &mesh_,
        &texture_,
        &transform_,
        &modulate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_multimesh :: proc "contextless" (
    self: Canvas_Item,
    multimesh_: Multi_Mesh,
    texture_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_multimesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 937992368)
    }
    self := self
    multimesh_ := multimesh_
    texture_ := texture_
    args := []__bindgen_gde.TypePtr {
        &multimesh_,
        &texture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_set_transform :: proc "contextless" (
    self: Canvas_Item,
    position_: Vector2,
    rotation_: f64,
    scale_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_set_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 288975085)
    }
    self := self
    position_ := position_
    rotation_ := rotation_
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &rotation_,
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_set_transform_matrix :: proc "contextless" (
    self: Canvas_Item,
    xform_: Transform2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_set_transform_matrix", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2761652528)
    }
    self := self
    xform_ := xform_
    args := []__bindgen_gde.TypePtr {
        &xform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_animation_slice :: proc "contextless" (
    self: Canvas_Item,
    animation_length_: f64,
    slice_begin_: f64,
    slice_end_: f64,
    offset_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_animation_slice", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3112831842)
    }
    self := self
    animation_length_ := animation_length_
    slice_begin_ := slice_begin_
    slice_end_ := slice_end_
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &animation_length_,
        &slice_begin_,
        &slice_end_,
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_draw_end_animation :: proc "contextless" (
    self: Canvas_Item,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_end_animation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_get_transform :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814499831)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_get_global_transform :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814499831)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_get_global_transform_with_canvas :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_transform_with_canvas", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814499831)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_get_viewport_transform :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_viewport_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814499831)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_get_viewport_rect :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_viewport_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1639390495)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_get_canvas_transform :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_canvas_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814499831)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_get_screen_transform :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_screen_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3814499831)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_get_local_mouse_position :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_local_mouse_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_get_global_mouse_position :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_mouse_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_get_canvas :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_canvas", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2944877500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_get_canvas_layer_node :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Canvas_Layer) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_canvas_layer_node", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2602762519)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_get_world_2d :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: World2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_world_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2339128592)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_material :: proc "contextless" (
    self: Canvas_Item,
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

canvas_item_get_material :: proc "contextless" (
    self: Canvas_Item,
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

canvas_item_set_instance_shader_parameter :: proc "contextless" (
    self: Canvas_Item,
    name_: String_Name,
    value_: Variant,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_instance_shader_parameter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3776071444)
    }
    self := self
    name_ := name_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &name_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_get_instance_shader_parameter :: proc "contextless" (
    self: Canvas_Item,
    name_: String_Name,
) -> (ret: Variant) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_instance_shader_parameter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2760726917)
    }
    self := self
    name_ := name_
    args := []__bindgen_gde.TypePtr {
        &name_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_use_parent_material :: proc "contextless" (
    self: Canvas_Item,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_parent_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_get_use_parent_material :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_use_parent_material", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_notify_local_transform :: proc "contextless" (
    self: Canvas_Item,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_notify_local_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_is_local_transform_notification_enabled :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_local_transform_notification_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_notify_transform :: proc "contextless" (
    self: Canvas_Item,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_notify_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_is_transform_notification_enabled :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_transform_notification_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_force_update_transform :: proc "contextless" (
    self: Canvas_Item,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("force_update_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_make_canvas_position_local :: proc "contextless" (
    self: Canvas_Item,
    viewport_point_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_canvas_position_local", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2656412154)
    }
    self := self
    viewport_point_ := viewport_point_
    args := []__bindgen_gde.TypePtr {
        &viewport_point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_make_input_local :: proc "contextless" (
    self: Canvas_Item,
    event_: Input_Event,
) -> (ret: Input_Event) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("make_input_local", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 811130057)
    }
    self := self
    event_ := event_
    args := []__bindgen_gde.TypePtr {
        &event_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_visibility_layer :: proc "contextless" (
    self: Canvas_Item,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_get_visibility_layer :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: u32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_layer", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_visibility_layer_bit :: proc "contextless" (
    self: Canvas_Item,
    layer_: Int,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_visibility_layer_bit", true)
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

canvas_item_get_visibility_layer_bit :: proc "contextless" (
    self: Canvas_Item,
    layer_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_layer_bit", true)
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

canvas_item_set_texture_filter :: proc "contextless" (
    self: Canvas_Item,
    mode_: Canvas_Item_Texture_Filter,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1037999706)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_get_texture_filter :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Canvas_Item_Texture_Filter) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 121960042)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_texture_repeat :: proc "contextless" (
    self: Canvas_Item,
    mode_: Canvas_Item_Texture_Repeat,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_repeat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1716472974)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_get_texture_repeat :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Canvas_Item_Texture_Repeat) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_repeat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2667158319)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_clip_children_mode :: proc "contextless" (
    self: Canvas_Item,
    mode_: Canvas_Item_Clip_Children_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_clip_children_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1319393776)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_get_clip_children_mode :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Canvas_Item_Clip_Children_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_clip_children_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3581808349)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

canvas_item_set_oversampling_with_scale :: proc "contextless" (
    self: Canvas_Item,
    enabled_: Canvas_Item_Oversampling_With_Scale,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_oversampling_with_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 872218804)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

canvas_item_get_oversampling_with_scale :: proc "contextless" (
    self: Canvas_Item,
) -> (ret: Canvas_Item_Oversampling_With_Scale) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_oversampling_with_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2026097197)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
canvas_item_get_visible :: proc "contextless" (self: Canvas_Item) -> Bool {
    return canvas_item_is_visible(self)
}
canvas_item_get_show_behind_parent :: proc "contextless" (self: Canvas_Item) -> Bool {
    return canvas_item_is_draw_behind_parent_enabled(self)
}
canvas_item_set_show_behind_parent :: proc "contextless" (self: Canvas_Item, value: Bool) {
    canvas_item_set_draw_behind_parent(self, value)
}
canvas_item_get_top_level :: proc "contextless" (self: Canvas_Item) -> Bool {
    return canvas_item_is_set_as_top_level(self)
}
canvas_item_set_top_level :: proc "contextless" (self: Canvas_Item, value: Bool) {
    canvas_item_set_as_top_level(self, value)
}
canvas_item_get_clip_children :: proc "contextless" (self: Canvas_Item) -> Canvas_Item_Clip_Children_Mode {
    return canvas_item_get_clip_children_mode(self)
}
canvas_item_set_clip_children :: proc "contextless" (self: Canvas_Item, value: Canvas_Item_Clip_Children_Mode) {
    canvas_item_set_clip_children_mode(self, value)
}
canvas_item_get_z_as_relative :: proc "contextless" (self: Canvas_Item) -> Bool {
    return canvas_item_is_z_relative(self)
}
canvas_item_get_y_sort_enabled :: proc "contextless" (self: Canvas_Item) -> Bool {
    return canvas_item_is_y_sort_enabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
canvas_item_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("CanvasItem", true)
}

@(private = "file")
__class_name: String_Name