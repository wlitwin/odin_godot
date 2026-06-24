package godot

import __bindgen_gde "godot:gdext"

Sprite_Base3d_Constants :: enum {
}
Sprite_Base3d_Draw_Flags :: enum int {
    Flag_Transparent = 0,
    Flag_Shaded = 1,
    Flag_Double_Sided = 2,
    Flag_Disable_Depth_Test = 3,
    Flag_Fixed_Size = 4,
    Flag_Max = 5,
}
Sprite_Base3d_Alpha_Cut_Mode :: enum int {
    Alpha_Cut_Disabled = 0,
    Alpha_Cut_Discard = 1,
    Alpha_Cut_Opaque_Prepass = 2,
    Alpha_Cut_Hash = 3,
}



sprite_base3d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

sprite_base3d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_sprite_base3d :: proc "contextless" () -> Sprite_Base3d {
    return __bindgen_gde.classdb_construct_object(sprite_base3d_name_ref())
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

sprite_base3d_set_centered :: proc "contextless" (
    self: Sprite_Base3d,
    centered_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_centered", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    centered_ := centered_
    args := []__bindgen_gde.TypePtr {
        &centered_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_base3d_is_centered :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_centered", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_set_offset :: proc "contextless" (
    self: Sprite_Base3d,
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

sprite_base3d_get_offset :: proc "contextless" (
    self: Sprite_Base3d,
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

sprite_base3d_set_flip_h :: proc "contextless" (
    self: Sprite_Base3d,
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

sprite_base3d_is_flipped_h :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_flipped_h", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_set_flip_v :: proc "contextless" (
    self: Sprite_Base3d,
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

sprite_base3d_is_flipped_v :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_flipped_v", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_set_modulate :: proc "contextless" (
    self: Sprite_Base3d,
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

sprite_base3d_get_modulate :: proc "contextless" (
    self: Sprite_Base3d,
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

sprite_base3d_set_render_priority :: proc "contextless" (
    self: Sprite_Base3d,
    priority_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_render_priority", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    priority_ := priority_
    args := []__bindgen_gde.TypePtr {
        &priority_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_base3d_get_render_priority :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_render_priority", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_set_pixel_size :: proc "contextless" (
    self: Sprite_Base3d,
    pixel_size_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_pixel_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    pixel_size_ := pixel_size_
    args := []__bindgen_gde.TypePtr {
        &pixel_size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_base3d_get_pixel_size :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pixel_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_set_axis :: proc "contextless" (
    self: Sprite_Base3d,
    axis_: Vector3_Vector3_Axis,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1144690656)
    }
    self := self
    axis_ := axis_
    args := []__bindgen_gde.TypePtr {
        &axis_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_base3d_get_axis :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: Vector3_Vector3_Axis) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_axis", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3050976882)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_set_draw_flag :: proc "contextless" (
    self: Sprite_Base3d,
    flag_: Sprite_Base3d_Draw_Flags,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_draw_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1135633219)
    }
    self := self
    flag_ := flag_
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &flag_,
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_base3d_get_draw_flag :: proc "contextless" (
    self: Sprite_Base3d,
    flag_: Sprite_Base3d_Draw_Flags,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_draw_flag", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1733036628)
    }
    self := self
    flag_ := flag_
    args := []__bindgen_gde.TypePtr {
        &flag_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_set_alpha_cut_mode :: proc "contextless" (
    self: Sprite_Base3d,
    mode_: Sprite_Base3d_Alpha_Cut_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alpha_cut_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 227561226)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_base3d_get_alpha_cut_mode :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: Sprite_Base3d_Alpha_Cut_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alpha_cut_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 336003791)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_set_alpha_scissor_threshold :: proc "contextless" (
    self: Sprite_Base3d,
    threshold_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alpha_scissor_threshold", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    threshold_ := threshold_
    args := []__bindgen_gde.TypePtr {
        &threshold_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_base3d_get_alpha_scissor_threshold :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alpha_scissor_threshold", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_set_alpha_hash_scale :: proc "contextless" (
    self: Sprite_Base3d,
    threshold_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alpha_hash_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    threshold_ := threshold_
    args := []__bindgen_gde.TypePtr {
        &threshold_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_base3d_get_alpha_hash_scale :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alpha_hash_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_set_alpha_antialiasing :: proc "contextless" (
    self: Sprite_Base3d,
    alpha_aa_: Base_Material3d_Alpha_Anti_Aliasing,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alpha_antialiasing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3212649852)
    }
    self := self
    alpha_aa_ := alpha_aa_
    args := []__bindgen_gde.TypePtr {
        &alpha_aa_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_base3d_get_alpha_antialiasing :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: Base_Material3d_Alpha_Anti_Aliasing) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alpha_antialiasing", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2889939400)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_set_alpha_antialiasing_edge :: proc "contextless" (
    self: Sprite_Base3d,
    edge_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alpha_antialiasing_edge", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    edge_ := edge_
    args := []__bindgen_gde.TypePtr {
        &edge_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_base3d_get_alpha_antialiasing_edge :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alpha_antialiasing_edge", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_set_billboard_mode :: proc "contextless" (
    self: Sprite_Base3d,
    mode_: Base_Material3d_Billboard_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_billboard_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4202036497)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_base3d_get_billboard_mode :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: Base_Material3d_Billboard_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_billboard_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1283840139)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_set_texture_filter :: proc "contextless" (
    self: Sprite_Base3d,
    mode_: Base_Material3d_Texture_Filter,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_texture_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 22904437)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

sprite_base3d_get_texture_filter :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: Base_Material3d_Texture_Filter) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_texture_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3289213076)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_get_item_rect :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1639390495)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

sprite_base3d_generate_triangle_mesh :: proc "contextless" (
    self: Sprite_Base3d,
) -> (ret: Triangle_Mesh) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("generate_triangle_mesh", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3476533166)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
sprite_base3d_get_centered :: proc "contextless" (self: Sprite_Base3d) -> Bool {
    return sprite_base3d_is_centered(self)
}
sprite_base3d_get_flip_h :: proc "contextless" (self: Sprite_Base3d) -> Bool {
    return sprite_base3d_is_flipped_h(self)
}
sprite_base3d_get_flip_v :: proc "contextless" (self: Sprite_Base3d) -> Bool {
    return sprite_base3d_is_flipped_v(self)
}
sprite_base3d_get_billboard :: proc "contextless" (self: Sprite_Base3d) -> Base_Material3d_Billboard_Mode {
    return sprite_base3d_get_billboard_mode(self)
}
sprite_base3d_set_billboard :: proc "contextless" (self: Sprite_Base3d, value: Base_Material3d_Billboard_Mode) {
    sprite_base3d_set_billboard_mode(self, value)
}
sprite_base3d_get_transparent :: proc "contextless" (self: Sprite_Base3d) -> Bool {
    return sprite_base3d_get_draw_flag(self, Sprite_Base3d_Draw_Flags(0))
}
sprite_base3d_set_transparent :: proc "contextless" (self: Sprite_Base3d, value: Bool) {
    sprite_base3d_set_draw_flag(self, Sprite_Base3d_Draw_Flags(0), value)
}
sprite_base3d_get_shaded :: proc "contextless" (self: Sprite_Base3d) -> Bool {
    return sprite_base3d_get_draw_flag(self, Sprite_Base3d_Draw_Flags(1))
}
sprite_base3d_set_shaded :: proc "contextless" (self: Sprite_Base3d, value: Bool) {
    sprite_base3d_set_draw_flag(self, Sprite_Base3d_Draw_Flags(1), value)
}
sprite_base3d_get_double_sided :: proc "contextless" (self: Sprite_Base3d) -> Bool {
    return sprite_base3d_get_draw_flag(self, Sprite_Base3d_Draw_Flags(2))
}
sprite_base3d_set_double_sided :: proc "contextless" (self: Sprite_Base3d, value: Bool) {
    sprite_base3d_set_draw_flag(self, Sprite_Base3d_Draw_Flags(2), value)
}
sprite_base3d_get_no_depth_test :: proc "contextless" (self: Sprite_Base3d) -> Bool {
    return sprite_base3d_get_draw_flag(self, Sprite_Base3d_Draw_Flags(3))
}
sprite_base3d_set_no_depth_test :: proc "contextless" (self: Sprite_Base3d, value: Bool) {
    sprite_base3d_set_draw_flag(self, Sprite_Base3d_Draw_Flags(3), value)
}
sprite_base3d_get_fixed_size :: proc "contextless" (self: Sprite_Base3d) -> Bool {
    return sprite_base3d_get_draw_flag(self, Sprite_Base3d_Draw_Flags(4))
}
sprite_base3d_set_fixed_size :: proc "contextless" (self: Sprite_Base3d, value: Bool) {
    sprite_base3d_set_draw_flag(self, Sprite_Base3d_Draw_Flags(4), value)
}
sprite_base3d_get_alpha_cut :: proc "contextless" (self: Sprite_Base3d) -> Sprite_Base3d_Alpha_Cut_Mode {
    return sprite_base3d_get_alpha_cut_mode(self)
}
sprite_base3d_set_alpha_cut :: proc "contextless" (self: Sprite_Base3d, value: Sprite_Base3d_Alpha_Cut_Mode) {
    sprite_base3d_set_alpha_cut_mode(self, value)
}
sprite_base3d_get_alpha_antialiasing_mode :: proc "contextless" (self: Sprite_Base3d) -> Base_Material3d_Alpha_Anti_Aliasing {
    return sprite_base3d_get_alpha_antialiasing(self)
}
sprite_base3d_set_alpha_antialiasing_mode :: proc "contextless" (self: Sprite_Base3d, value: Base_Material3d_Alpha_Anti_Aliasing) {
    sprite_base3d_set_alpha_antialiasing(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
sprite_base3d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("SpriteBase3D", true)
}

@(private = "file")
__class_name: String_Name