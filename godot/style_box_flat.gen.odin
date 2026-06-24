package godot

import __bindgen_gde "godot:gdext"

Style_Box_Flat_Constants :: enum {
}



style_box_flat_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

style_box_flat_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_style_box_flat :: proc "contextless" () -> Style_Box_Flat {
    return cast(Style_Box_Flat)__bindgen_gde.classdb_construct_object(style_box_flat_name_ref())
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

style_box_flat_set_bg_color :: proc "contextless" (
    self: Style_Box_Flat,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bg_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_get_bg_color :: proc "contextless" (
    self: Style_Box_Flat,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bg_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_border_color :: proc "contextless" (
    self: Style_Box_Flat,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_border_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_get_border_color :: proc "contextless" (
    self: Style_Box_Flat,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_border_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_border_width_all :: proc "contextless" (
    self: Style_Box_Flat,
    width_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_border_width_all", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    width_ := width_
    args := []__bindgen_gde.TypePtr {
        &width_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_get_border_width_min :: proc "contextless" (
    self: Style_Box_Flat,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_border_width_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_border_width :: proc "contextless" (
    self: Style_Box_Flat,
    margin_: Side,
    width_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_border_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 437707142)
    }
    self := self
    margin_ := margin_
    width_ := width_
    args := []__bindgen_gde.TypePtr {
        &margin_,
        &width_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_get_border_width :: proc "contextless" (
    self: Style_Box_Flat,
    margin_: Side,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_border_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1983885014)
    }
    self := self
    margin_ := margin_
    args := []__bindgen_gde.TypePtr {
        &margin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_border_blend :: proc "contextless" (
    self: Style_Box_Flat,
    blend_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_border_blend", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    blend_ := blend_
    args := []__bindgen_gde.TypePtr {
        &blend_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_get_border_blend :: proc "contextless" (
    self: Style_Box_Flat,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_border_blend", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_corner_radius_all :: proc "contextless" (
    self: Style_Box_Flat,
    radius_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_corner_radius_all", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    radius_ := radius_
    args := []__bindgen_gde.TypePtr {
        &radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_set_corner_radius :: proc "contextless" (
    self: Style_Box_Flat,
    corner_: Corner,
    radius_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_corner_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2696158768)
    }
    self := self
    corner_ := corner_
    radius_ := radius_
    args := []__bindgen_gde.TypePtr {
        &corner_,
        &radius_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_get_corner_radius :: proc "contextless" (
    self: Style_Box_Flat,
    corner_: Corner,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_corner_radius", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3982397690)
    }
    self := self
    corner_ := corner_
    args := []__bindgen_gde.TypePtr {
        &corner_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_expand_margin :: proc "contextless" (
    self: Style_Box_Flat,
    margin_: Side,
    size_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_expand_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4290182280)
    }
    self := self
    margin_ := margin_
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &margin_,
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_set_expand_margin_all :: proc "contextless" (
    self: Style_Box_Flat,
    size_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_expand_margin_all", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_get_expand_margin :: proc "contextless" (
    self: Style_Box_Flat,
    margin_: Side,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_expand_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2869120046)
    }
    self := self
    margin_ := margin_
    args := []__bindgen_gde.TypePtr {
        &margin_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_draw_center :: proc "contextless" (
    self: Style_Box_Flat,
    draw_center_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_center", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    draw_center_ := draw_center_
    args := []__bindgen_gde.TypePtr {
        &draw_center_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_is_draw_center_enabled :: proc "contextless" (
    self: Style_Box_Flat,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_draw_center_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_skew :: proc "contextless" (
    self: Style_Box_Flat,
    skew_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_skew", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    skew_ := skew_
    args := []__bindgen_gde.TypePtr {
        &skew_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_get_skew :: proc "contextless" (
    self: Style_Box_Flat,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skew", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_shadow_color :: proc "contextless" (
    self: Style_Box_Flat,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadow_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_get_shadow_color :: proc "contextless" (
    self: Style_Box_Flat,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shadow_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_shadow_size :: proc "contextless" (
    self: Style_Box_Flat,
    size_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadow_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_get_shadow_size :: proc "contextless" (
    self: Style_Box_Flat,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shadow_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_shadow_offset :: proc "contextless" (
    self: Style_Box_Flat,
    offset_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadow_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_get_shadow_offset :: proc "contextless" (
    self: Style_Box_Flat,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shadow_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_anti_aliased :: proc "contextless" (
    self: Style_Box_Flat,
    anti_aliased_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_anti_aliased", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    anti_aliased_ := anti_aliased_
    args := []__bindgen_gde.TypePtr {
        &anti_aliased_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_is_anti_aliased :: proc "contextless" (
    self: Style_Box_Flat,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_anti_aliased", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_aa_size :: proc "contextless" (
    self: Style_Box_Flat,
    size_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_aa_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_get_aa_size :: proc "contextless" (
    self: Style_Box_Flat,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_aa_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_flat_set_corner_detail :: proc "contextless" (
    self: Style_Box_Flat,
    detail_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_corner_detail", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    detail_ := detail_
    args := []__bindgen_gde.TypePtr {
        &detail_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_flat_get_corner_detail :: proc "contextless" (
    self: Style_Box_Flat,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_corner_detail", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
style_box_flat_get_draw_center :: proc "contextless" (self: Style_Box_Flat) -> Bool {
    return style_box_flat_is_draw_center_enabled(self)
}
style_box_flat_get_border_width_left :: proc "contextless" (self: Style_Box_Flat) -> i32 {
    return style_box_flat_get_border_width(self, Side(0))
}
style_box_flat_set_border_width_left :: proc "contextless" (self: Style_Box_Flat, value: Int) {
    style_box_flat_set_border_width(self, Side(0), value)
}
style_box_flat_get_border_width_top :: proc "contextless" (self: Style_Box_Flat) -> i32 {
    return style_box_flat_get_border_width(self, Side(1))
}
style_box_flat_set_border_width_top :: proc "contextless" (self: Style_Box_Flat, value: Int) {
    style_box_flat_set_border_width(self, Side(1), value)
}
style_box_flat_get_border_width_right :: proc "contextless" (self: Style_Box_Flat) -> i32 {
    return style_box_flat_get_border_width(self, Side(2))
}
style_box_flat_set_border_width_right :: proc "contextless" (self: Style_Box_Flat, value: Int) {
    style_box_flat_set_border_width(self, Side(2), value)
}
style_box_flat_get_border_width_bottom :: proc "contextless" (self: Style_Box_Flat) -> i32 {
    return style_box_flat_get_border_width(self, Side(3))
}
style_box_flat_set_border_width_bottom :: proc "contextless" (self: Style_Box_Flat, value: Int) {
    style_box_flat_set_border_width(self, Side(3), value)
}
style_box_flat_get_corner_radius_top_left :: proc "contextless" (self: Style_Box_Flat) -> i32 {
    return style_box_flat_get_corner_radius(self, Corner(0))
}
style_box_flat_set_corner_radius_top_left :: proc "contextless" (self: Style_Box_Flat, value: Int) {
    style_box_flat_set_corner_radius(self, Corner(0), value)
}
style_box_flat_get_corner_radius_top_right :: proc "contextless" (self: Style_Box_Flat) -> i32 {
    return style_box_flat_get_corner_radius(self, Corner(1))
}
style_box_flat_set_corner_radius_top_right :: proc "contextless" (self: Style_Box_Flat, value: Int) {
    style_box_flat_set_corner_radius(self, Corner(1), value)
}
style_box_flat_get_corner_radius_bottom_right :: proc "contextless" (self: Style_Box_Flat) -> i32 {
    return style_box_flat_get_corner_radius(self, Corner(2))
}
style_box_flat_set_corner_radius_bottom_right :: proc "contextless" (self: Style_Box_Flat, value: Int) {
    style_box_flat_set_corner_radius(self, Corner(2), value)
}
style_box_flat_get_corner_radius_bottom_left :: proc "contextless" (self: Style_Box_Flat) -> i32 {
    return style_box_flat_get_corner_radius(self, Corner(3))
}
style_box_flat_set_corner_radius_bottom_left :: proc "contextless" (self: Style_Box_Flat, value: Int) {
    style_box_flat_set_corner_radius(self, Corner(3), value)
}
style_box_flat_get_expand_margin_left :: proc "contextless" (self: Style_Box_Flat) -> f64 {
    return style_box_flat_get_expand_margin(self, Side(0))
}
style_box_flat_set_expand_margin_left :: proc "contextless" (self: Style_Box_Flat, value: f64) {
    style_box_flat_set_expand_margin(self, Side(0), value)
}
style_box_flat_get_expand_margin_top :: proc "contextless" (self: Style_Box_Flat) -> f64 {
    return style_box_flat_get_expand_margin(self, Side(1))
}
style_box_flat_set_expand_margin_top :: proc "contextless" (self: Style_Box_Flat, value: f64) {
    style_box_flat_set_expand_margin(self, Side(1), value)
}
style_box_flat_get_expand_margin_right :: proc "contextless" (self: Style_Box_Flat) -> f64 {
    return style_box_flat_get_expand_margin(self, Side(2))
}
style_box_flat_set_expand_margin_right :: proc "contextless" (self: Style_Box_Flat, value: f64) {
    style_box_flat_set_expand_margin(self, Side(2), value)
}
style_box_flat_get_expand_margin_bottom :: proc "contextless" (self: Style_Box_Flat) -> f64 {
    return style_box_flat_get_expand_margin(self, Side(3))
}
style_box_flat_set_expand_margin_bottom :: proc "contextless" (self: Style_Box_Flat, value: f64) {
    style_box_flat_set_expand_margin(self, Side(3), value)
}
style_box_flat_get_anti_aliasing :: proc "contextless" (self: Style_Box_Flat) -> Bool {
    return style_box_flat_is_anti_aliased(self)
}
style_box_flat_set_anti_aliasing :: proc "contextless" (self: Style_Box_Flat, value: Bool) {
    style_box_flat_set_anti_aliased(self, value)
}
style_box_flat_get_anti_aliasing_size :: proc "contextless" (self: Style_Box_Flat) -> f64 {
    return style_box_flat_get_aa_size(self)
}
style_box_flat_set_anti_aliasing_size :: proc "contextless" (self: Style_Box_Flat, value: f64) {
    style_box_flat_set_aa_size(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
style_box_flat_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("StyleBoxFlat", true)
}

@(private = "file")
__class_name: String_Name