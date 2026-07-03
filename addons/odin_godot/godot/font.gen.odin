package godot

import __bindgen_gde "godot:gdext"

Font_Constants :: enum {
}



font_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

font_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_font :: proc "contextless" () -> Font {
    return cast(Font)__bindgen_gde.classdb_construct_object(font_name_ref())
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

font_set_fallbacks :: proc "contextless" (
    self: Font,
    fallbacks_: Typed_Array(Font),
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fallbacks", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 381264803)
    }
    self := self
    fallbacks_ := fallbacks_
    args := []__bindgen_gde.TypePtr {
        &fallbacks_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_get_fallbacks :: proc "contextless" (
    self: Font,
) -> (ret: Typed_Array(Font)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fallbacks", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_find_variation :: proc "contextless" (
    self: Font,
    variation_coordinates_: Dictionary,
    face_index_: Int,
    strength_: f64,
    transform_: Transform2d,
    spacing_top_: Int,
    spacing_bottom_: Int,
    spacing_space_: Int,
    spacing_glyph_: Int,
    baseline_offset_: f64,
) -> (ret: Rid) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("find_variation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2553855095)
    }
    self := self
    variation_coordinates_ := variation_coordinates_
    face_index_ := face_index_
    strength_ := strength_
    transform_ := transform_
    spacing_top_ := spacing_top_
    spacing_bottom_ := spacing_bottom_
    spacing_space_ := spacing_space_
    spacing_glyph_ := spacing_glyph_
    baseline_offset_ := baseline_offset_
    args := []__bindgen_gde.TypePtr {
        &variation_coordinates_,
        &face_index_,
        &strength_,
        &transform_,
        &spacing_top_,
        &spacing_bottom_,
        &spacing_space_,
        &spacing_glyph_,
        &baseline_offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_rids :: proc "contextless" (
    self: Font,
) -> (ret: Typed_Array(Rid)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rids", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_height :: proc "contextless" (
    self: Font,
    font_size_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 378113874)
    }
    self := self
    font_size_ := font_size_
    args := []__bindgen_gde.TypePtr {
        &font_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_ascent :: proc "contextless" (
    self: Font,
    font_size_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_ascent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 378113874)
    }
    self := self
    font_size_ := font_size_
    args := []__bindgen_gde.TypePtr {
        &font_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_descent :: proc "contextless" (
    self: Font,
    font_size_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_descent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 378113874)
    }
    self := self
    font_size_ := font_size_
    args := []__bindgen_gde.TypePtr {
        &font_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_underline_position :: proc "contextless" (
    self: Font,
    font_size_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_underline_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 378113874)
    }
    self := self
    font_size_ := font_size_
    args := []__bindgen_gde.TypePtr {
        &font_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_underline_thickness :: proc "contextless" (
    self: Font,
    font_size_: Int,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_underline_thickness", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 378113874)
    }
    self := self
    font_size_ := font_size_
    args := []__bindgen_gde.TypePtr {
        &font_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_font_name :: proc "contextless" (
    self: Font,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_font_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_font_style_name :: proc "contextless" (
    self: Font,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_font_style_name", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_ot_name_strings :: proc "contextless" (
    self: Font,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_ot_name_strings", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_font_style :: proc "contextless" (
    self: Font,
) -> (ret: Text_Server_Font_Style) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_font_style", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2520224254)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_font_weight :: proc "contextless" (
    self: Font,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_font_weight", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_font_stretch :: proc "contextless" (
    self: Font,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_font_stretch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_spacing :: proc "contextless" (
    self: Font,
    spacing_: Text_Server_Spacing_Type,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_spacing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1310880908)
    }
    self := self
    spacing_ := spacing_
    args := []__bindgen_gde.TypePtr {
        &spacing_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_opentype_features :: proc "contextless" (
    self: Font,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_opentype_features", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_set_cache_capacity :: proc "contextless" (
    self: Font,
    single_line_: Int,
    multi_line_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cache_capacity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3937882851)
    }
    self := self
    single_line_ := single_line_
    multi_line_ := multi_line_
    args := []__bindgen_gde.TypePtr {
        &single_line_,
        &multi_line_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

font_get_string_size :: proc "contextless" (
    self: Font,
    text_: String,
    alignment_: Horizontal_Alignment,
    width_: f64,
    font_size_: Int,
    justification_flags_: Text_Server_Justification_Flag,
    direction_: Text_Server_Direction,
    orientation_: Text_Server_Orientation,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_string_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1868866121)
    }
    self := self
    text_ := text_
    alignment_ := alignment_
    width_ := width_
    font_size_ := font_size_
    justification_flags_ := justification_flags_
    direction_ := direction_
    orientation_ := orientation_
    args := []__bindgen_gde.TypePtr {
        &text_,
        &alignment_,
        &width_,
        &font_size_,
        &justification_flags_,
        &direction_,
        &orientation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_multiline_string_size :: proc "contextless" (
    self: Font,
    text_: String,
    alignment_: Horizontal_Alignment,
    width_: f64,
    font_size_: Int,
    max_lines_: Int,
    brk_flags_: Text_Server_Line_Break_Flag,
    justification_flags_: Text_Server_Justification_Flag,
    direction_: Text_Server_Direction,
    orientation_: Text_Server_Orientation,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_multiline_string_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 519636710)
    }
    self := self
    text_ := text_
    alignment_ := alignment_
    width_ := width_
    font_size_ := font_size_
    max_lines_ := max_lines_
    brk_flags_ := brk_flags_
    justification_flags_ := justification_flags_
    direction_ := direction_
    orientation_ := orientation_
    args := []__bindgen_gde.TypePtr {
        &text_,
        &alignment_,
        &width_,
        &font_size_,
        &max_lines_,
        &brk_flags_,
        &justification_flags_,
        &direction_,
        &orientation_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_draw_string :: proc "contextless" (
    self: Font,
    canvas_item_: Rid,
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
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1976686372)
    }
    self := self
    canvas_item_ := canvas_item_
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
        &canvas_item_,
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

font_draw_multiline_string :: proc "contextless" (
    self: Font,
    canvas_item_: Rid,
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
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2686601589)
    }
    self := self
    canvas_item_ := canvas_item_
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
        &canvas_item_,
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

font_draw_string_outline :: proc "contextless" (
    self: Font,
    canvas_item_: Rid,
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
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 701417663)
    }
    self := self
    canvas_item_ := canvas_item_
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
        &canvas_item_,
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

font_draw_multiline_string_outline :: proc "contextless" (
    self: Font,
    canvas_item_: Rid,
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
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4147839237)
    }
    self := self
    canvas_item_ := canvas_item_
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
        &canvas_item_,
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

font_get_char_size :: proc "contextless" (
    self: Font,
    char_: Int,
    font_size_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_char_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3016396712)
    }
    self := self
    char_ := char_
    font_size_ := font_size_
    args := []__bindgen_gde.TypePtr {
        &char_,
        &font_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_draw_char :: proc "contextless" (
    self: Font,
    canvas_item_: Rid,
    pos_: Vector2,
    char_: Int,
    font_size_: Int,
    modulate_: Color,
    oversampling_: f64,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_char", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3500170256)
    }
    self := self
    canvas_item_ := canvas_item_
    pos_ := pos_
    char_ := char_
    font_size_ := font_size_
    modulate_ := modulate_
    oversampling_ := oversampling_
    args := []__bindgen_gde.TypePtr {
        &canvas_item_,
        &pos_,
        &char_,
        &font_size_,
        &modulate_,
        &oversampling_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_draw_char_outline :: proc "contextless" (
    self: Font,
    canvas_item_: Rid,
    pos_: Vector2,
    char_: Int,
    font_size_: Int,
    size_: Int,
    modulate_: Color,
    oversampling_: f64,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_char_outline", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1684114874)
    }
    self := self
    canvas_item_ := canvas_item_
    pos_ := pos_
    char_ := char_
    font_size_ := font_size_
    size_ := size_
    modulate_ := modulate_
    oversampling_ := oversampling_
    args := []__bindgen_gde.TypePtr {
        &canvas_item_,
        &pos_,
        &char_,
        &font_size_,
        &size_,
        &modulate_,
        &oversampling_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_has_char :: proc "contextless" (
    self: Font,
    char_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_char", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    char_ := char_
    args := []__bindgen_gde.TypePtr {
        &char_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_supported_chars :: proc "contextless" (
    self: Font,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_supported_chars", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_is_language_supported :: proc "contextless" (
    self: Font,
    language_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_language_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    language_ := language_
    args := []__bindgen_gde.TypePtr {
        &language_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_is_script_supported :: proc "contextless" (
    self: Font,
    script_: String,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_script_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3927539163)
    }
    self := self
    script_ := script_
    args := []__bindgen_gde.TypePtr {
        &script_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_supported_feature_list :: proc "contextless" (
    self: Font,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_supported_feature_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_supported_variation_list :: proc "contextless" (
    self: Font,
) -> (ret: Dictionary) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_supported_variation_list", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3102165223)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

font_get_face_count :: proc "contextless" (
    self: Font,
) -> (ret: i64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_face_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
font_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Font", true)
}

@(private = "file")
__class_name: String_Name