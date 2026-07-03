package godot

import __bindgen_gde "godot:gdext"

Style_Box_Texture_Constants :: enum {
}
Style_Box_Texture_Axis_Stretch_Mode :: enum int {
    Axis_Stretch_Mode_Stretch = 0,
    Axis_Stretch_Mode_Tile = 1,
    Axis_Stretch_Mode_Tile_Fit = 2,
}



style_box_texture_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

style_box_texture_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_style_box_texture :: proc "contextless" () -> Style_Box_Texture {
    return cast(Style_Box_Texture)__bindgen_gde.classdb_construct_object(style_box_texture_name_ref())
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

style_box_texture_set_texture :: proc "contextless" (
    self: Style_Box_Texture,
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

style_box_texture_get_texture :: proc "contextless" (
    self: Style_Box_Texture,
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

style_box_texture_set_texture_margin :: proc "contextless" (
    self: Style_Box_Texture,
    margin_: Side,
    size_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_margin", true)
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

style_box_texture_set_texture_margin_all :: proc "contextless" (
    self: Style_Box_Texture,
    size_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_margin_all", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_texture_get_texture_margin :: proc "contextless" (
    self: Style_Box_Texture,
    margin_: Side,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_margin", true)
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

style_box_texture_set_expand_margin :: proc "contextless" (
    self: Style_Box_Texture,
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

style_box_texture_set_expand_margin_all :: proc "contextless" (
    self: Style_Box_Texture,
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

style_box_texture_get_expand_margin :: proc "contextless" (
    self: Style_Box_Texture,
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

style_box_texture_set_region_rect :: proc "contextless" (
    self: Style_Box_Texture,
    region_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_region_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2046264180)
    }
    self := self
    region_ := region_
    args := []__bindgen_gde.TypePtr {
        &region_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_texture_get_region_rect :: proc "contextless" (
    self: Style_Box_Texture,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_region_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1639390495)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_texture_set_draw_center :: proc "contextless" (
    self: Style_Box_Texture,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_center", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_texture_is_draw_center_enabled :: proc "contextless" (
    self: Style_Box_Texture,
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

style_box_texture_set_modulate :: proc "contextless" (
    self: Style_Box_Texture,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_modulate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_texture_get_modulate :: proc "contextless" (
    self: Style_Box_Texture,
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

style_box_texture_set_h_axis_stretch_mode :: proc "contextless" (
    self: Style_Box_Texture,
    mode_: Style_Box_Texture_Axis_Stretch_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_h_axis_stretch_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2965538783)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_texture_get_h_axis_stretch_mode :: proc "contextless" (
    self: Style_Box_Texture,
) -> (ret: Style_Box_Texture_Axis_Stretch_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_h_axis_stretch_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3807744063)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_texture_set_v_axis_stretch_mode :: proc "contextless" (
    self: Style_Box_Texture,
    mode_: Style_Box_Texture_Axis_Stretch_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_v_axis_stretch_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2965538783)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_texture_get_v_axis_stretch_mode :: proc "contextless" (
    self: Style_Box_Texture,
) -> (ret: Style_Box_Texture_Axis_Stretch_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_v_axis_stretch_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3807744063)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
style_box_texture_get_texture_margin_left :: proc "contextless" (self: Style_Box_Texture) -> f64 {
    return style_box_texture_get_texture_margin(self, Side(0))
}
style_box_texture_set_texture_margin_left :: proc "contextless" (self: Style_Box_Texture, value: f64) {
    style_box_texture_set_texture_margin(self, Side(0), value)
}
style_box_texture_get_texture_margin_top :: proc "contextless" (self: Style_Box_Texture) -> f64 {
    return style_box_texture_get_texture_margin(self, Side(1))
}
style_box_texture_set_texture_margin_top :: proc "contextless" (self: Style_Box_Texture, value: f64) {
    style_box_texture_set_texture_margin(self, Side(1), value)
}
style_box_texture_get_texture_margin_right :: proc "contextless" (self: Style_Box_Texture) -> f64 {
    return style_box_texture_get_texture_margin(self, Side(2))
}
style_box_texture_set_texture_margin_right :: proc "contextless" (self: Style_Box_Texture, value: f64) {
    style_box_texture_set_texture_margin(self, Side(2), value)
}
style_box_texture_get_texture_margin_bottom :: proc "contextless" (self: Style_Box_Texture) -> f64 {
    return style_box_texture_get_texture_margin(self, Side(3))
}
style_box_texture_set_texture_margin_bottom :: proc "contextless" (self: Style_Box_Texture, value: f64) {
    style_box_texture_set_texture_margin(self, Side(3), value)
}
style_box_texture_get_expand_margin_left :: proc "contextless" (self: Style_Box_Texture) -> f64 {
    return style_box_texture_get_expand_margin(self, Side(0))
}
style_box_texture_set_expand_margin_left :: proc "contextless" (self: Style_Box_Texture, value: f64) {
    style_box_texture_set_expand_margin(self, Side(0), value)
}
style_box_texture_get_expand_margin_top :: proc "contextless" (self: Style_Box_Texture) -> f64 {
    return style_box_texture_get_expand_margin(self, Side(1))
}
style_box_texture_set_expand_margin_top :: proc "contextless" (self: Style_Box_Texture, value: f64) {
    style_box_texture_set_expand_margin(self, Side(1), value)
}
style_box_texture_get_expand_margin_right :: proc "contextless" (self: Style_Box_Texture) -> f64 {
    return style_box_texture_get_expand_margin(self, Side(2))
}
style_box_texture_set_expand_margin_right :: proc "contextless" (self: Style_Box_Texture, value: f64) {
    style_box_texture_set_expand_margin(self, Side(2), value)
}
style_box_texture_get_expand_margin_bottom :: proc "contextless" (self: Style_Box_Texture) -> f64 {
    return style_box_texture_get_expand_margin(self, Side(3))
}
style_box_texture_set_expand_margin_bottom :: proc "contextless" (self: Style_Box_Texture, value: f64) {
    style_box_texture_set_expand_margin(self, Side(3), value)
}
style_box_texture_get_axis_stretch_horizontal :: proc "contextless" (self: Style_Box_Texture) -> Style_Box_Texture_Axis_Stretch_Mode {
    return style_box_texture_get_h_axis_stretch_mode(self)
}
style_box_texture_set_axis_stretch_horizontal :: proc "contextless" (self: Style_Box_Texture, value: Style_Box_Texture_Axis_Stretch_Mode) {
    style_box_texture_set_h_axis_stretch_mode(self, value)
}
style_box_texture_get_axis_stretch_vertical :: proc "contextless" (self: Style_Box_Texture) -> Style_Box_Texture_Axis_Stretch_Mode {
    return style_box_texture_get_v_axis_stretch_mode(self)
}
style_box_texture_set_axis_stretch_vertical :: proc "contextless" (self: Style_Box_Texture, value: Style_Box_Texture_Axis_Stretch_Mode) {
    style_box_texture_set_v_axis_stretch_mode(self, value)
}
style_box_texture_get_modulate_color :: proc "contextless" (self: Style_Box_Texture) -> Color {
    return style_box_texture_get_modulate(self)
}
style_box_texture_set_modulate_color :: proc "contextless" (self: Style_Box_Texture, value: Color) {
    style_box_texture_set_modulate(self, value)
}
style_box_texture_get_draw_center :: proc "contextless" (self: Style_Box_Texture) -> Bool {
    return style_box_texture_is_draw_center_enabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
style_box_texture_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("StyleBoxTexture", true)
}

@(private = "file")
__class_name: String_Name