package godot

import __bindgen_gde "godot:gdext"

Texture_Progress_Bar_Constants :: enum {
}
Texture_Progress_Bar_Fill_Mode :: enum int {
    Fill_Left_To_Right = 0,
    Fill_Right_To_Left = 1,
    Fill_Top_To_Bottom = 2,
    Fill_Bottom_To_Top = 3,
    Fill_Clockwise = 4,
    Fill_Counter_Clockwise = 5,
    Fill_Bilinear_Left_And_Right = 6,
    Fill_Bilinear_Top_And_Bottom = 7,
    Fill_Clockwise_And_Counter_Clockwise = 8,
}



texture_progress_bar_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

texture_progress_bar_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_texture_progress_bar :: proc "contextless" () -> Texture_Progress_Bar {
    return __bindgen_gde.classdb_construct_object(texture_progress_bar_name_ref())
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

texture_progress_bar_set_under_texture :: proc "contextless" (
    self: Texture_Progress_Bar,
    tex_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_under_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    tex_ := tex_
    args := []__bindgen_gde.TypePtr {
        &tex_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_progress_bar_get_under_texture :: proc "contextless" (
    self: Texture_Progress_Bar,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_under_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_progress_bar_set_progress_texture :: proc "contextless" (
    self: Texture_Progress_Bar,
    tex_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_progress_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    tex_ := tex_
    args := []__bindgen_gde.TypePtr {
        &tex_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_progress_bar_get_progress_texture :: proc "contextless" (
    self: Texture_Progress_Bar,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_progress_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_progress_bar_set_over_texture :: proc "contextless" (
    self: Texture_Progress_Bar,
    tex_: Texture2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_over_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4051416890)
    }
    self := self
    tex_ := tex_
    args := []__bindgen_gde.TypePtr {
        &tex_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_progress_bar_get_over_texture :: proc "contextless" (
    self: Texture_Progress_Bar,
) -> (ret: Texture2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_over_texture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3635182373)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_progress_bar_set_fill_mode :: proc "contextless" (
    self: Texture_Progress_Bar,
    mode_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fill_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_progress_bar_get_fill_mode :: proc "contextless" (
    self: Texture_Progress_Bar,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fill_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2455072627)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_progress_bar_set_tint_under :: proc "contextless" (
    self: Texture_Progress_Bar,
    tint_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tint_under", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    tint_ := tint_
    args := []__bindgen_gde.TypePtr {
        &tint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_progress_bar_get_tint_under :: proc "contextless" (
    self: Texture_Progress_Bar,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tint_under", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_progress_bar_set_tint_progress :: proc "contextless" (
    self: Texture_Progress_Bar,
    tint_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tint_progress", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    tint_ := tint_
    args := []__bindgen_gde.TypePtr {
        &tint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_progress_bar_get_tint_progress :: proc "contextless" (
    self: Texture_Progress_Bar,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tint_progress", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_progress_bar_set_tint_over :: proc "contextless" (
    self: Texture_Progress_Bar,
    tint_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_tint_over", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    tint_ := tint_
    args := []__bindgen_gde.TypePtr {
        &tint_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_progress_bar_get_tint_over :: proc "contextless" (
    self: Texture_Progress_Bar,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_tint_over", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_progress_bar_set_texture_progress_offset :: proc "contextless" (
    self: Texture_Progress_Bar,
    offset_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_progress_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_progress_bar_get_texture_progress_offset :: proc "contextless" (
    self: Texture_Progress_Bar,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_progress_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_progress_bar_set_radial_initial_angle :: proc "contextless" (
    self: Texture_Progress_Bar,
    mode_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_radial_initial_angle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_progress_bar_get_radial_initial_angle :: proc "contextless" (
    self: Texture_Progress_Bar,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_radial_initial_angle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_progress_bar_set_radial_center_offset :: proc "contextless" (
    self: Texture_Progress_Bar,
    mode_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_radial_center_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_progress_bar_get_radial_center_offset :: proc "contextless" (
    self: Texture_Progress_Bar,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_radial_center_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1497962370)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_progress_bar_set_fill_degrees :: proc "contextless" (
    self: Texture_Progress_Bar,
    mode_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fill_degrees", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_progress_bar_get_fill_degrees :: proc "contextless" (
    self: Texture_Progress_Bar,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fill_degrees", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 191475506)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture_progress_bar_set_stretch_margin :: proc "contextless" (
    self: Texture_Progress_Bar,
    margin_: Side,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stretch_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 437707142)
    }
    self := self
    margin_ := margin_
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &margin_,
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_progress_bar_get_stretch_margin :: proc "contextless" (
    self: Texture_Progress_Bar,
    margin_: Side,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stretch_margin", true)
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

texture_progress_bar_set_nine_patch_stretch :: proc "contextless" (
    self: Texture_Progress_Bar,
    stretch_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_nine_patch_stretch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    stretch_ := stretch_
    args := []__bindgen_gde.TypePtr {
        &stretch_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture_progress_bar_get_nine_patch_stretch :: proc "contextless" (
    self: Texture_Progress_Bar,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_nine_patch_stretch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
texture_progress_bar_get_radial_fill_degrees :: proc "contextless" (self: Texture_Progress_Bar) -> f64 {
    return texture_progress_bar_get_fill_degrees(self)
}
texture_progress_bar_set_radial_fill_degrees :: proc "contextless" (self: Texture_Progress_Bar, value: f64) {
    texture_progress_bar_set_fill_degrees(self, value)
}
texture_progress_bar_get_stretch_margin_left :: proc "contextless" (self: Texture_Progress_Bar) -> i32 {
    return texture_progress_bar_get_stretch_margin(self, Side(0))
}
texture_progress_bar_set_stretch_margin_left :: proc "contextless" (self: Texture_Progress_Bar, value: Int) {
    texture_progress_bar_set_stretch_margin(self, Side(0), value)
}
texture_progress_bar_get_stretch_margin_top :: proc "contextless" (self: Texture_Progress_Bar) -> i32 {
    return texture_progress_bar_get_stretch_margin(self, Side(1))
}
texture_progress_bar_set_stretch_margin_top :: proc "contextless" (self: Texture_Progress_Bar, value: Int) {
    texture_progress_bar_set_stretch_margin(self, Side(1), value)
}
texture_progress_bar_get_stretch_margin_right :: proc "contextless" (self: Texture_Progress_Bar) -> i32 {
    return texture_progress_bar_get_stretch_margin(self, Side(2))
}
texture_progress_bar_set_stretch_margin_right :: proc "contextless" (self: Texture_Progress_Bar, value: Int) {
    texture_progress_bar_set_stretch_margin(self, Side(2), value)
}
texture_progress_bar_get_stretch_margin_bottom :: proc "contextless" (self: Texture_Progress_Bar) -> i32 {
    return texture_progress_bar_get_stretch_margin(self, Side(3))
}
texture_progress_bar_set_stretch_margin_bottom :: proc "contextless" (self: Texture_Progress_Bar, value: Int) {
    texture_progress_bar_set_stretch_margin(self, Side(3), value)
}
texture_progress_bar_get_texture_under :: proc "contextless" (self: Texture_Progress_Bar) -> Texture2d {
    return texture_progress_bar_get_under_texture(self)
}
texture_progress_bar_set_texture_under :: proc "contextless" (self: Texture_Progress_Bar, value: Texture2d) {
    texture_progress_bar_set_under_texture(self, value)
}
texture_progress_bar_get_texture_over :: proc "contextless" (self: Texture_Progress_Bar) -> Texture2d {
    return texture_progress_bar_get_over_texture(self)
}
texture_progress_bar_set_texture_over :: proc "contextless" (self: Texture_Progress_Bar, value: Texture2d) {
    texture_progress_bar_set_over_texture(self, value)
}
texture_progress_bar_get_texture_progress :: proc "contextless" (self: Texture_Progress_Bar) -> Texture2d {
    return texture_progress_bar_get_progress_texture(self)
}
texture_progress_bar_set_texture_progress :: proc "contextless" (self: Texture_Progress_Bar, value: Texture2d) {
    texture_progress_bar_set_progress_texture(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
texture_progress_bar_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("TextureProgressBar", true)
}

@(private = "file")
__class_name: String_Name