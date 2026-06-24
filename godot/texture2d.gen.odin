package godot

import __bindgen_gde "godot:gdext"

Texture2d_Constants :: enum {
}



texture2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

texture2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_texture2d :: proc "contextless" () -> Texture2d {
    return cast(Texture2d)__bindgen_gde.classdb_construct_object(texture2d_name_ref())
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

texture2d__get_width :: proc "contextless" (
    self: Texture2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture2d__get_height :: proc "contextless" (
    self: Texture2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture2d__is_pixel_opaque :: proc "contextless" (
    self: Texture2d,
    x_: Int,
    y_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_is_pixel_opaque", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2522259332)
    }
    self := self
    x_ := x_
    y_ := y_
    args := []__bindgen_gde.TypePtr {
        &x_,
        &y_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture2d__has_alpha :: proc "contextless" (
    self: Texture2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_has_alpha", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture2d__draw :: proc "contextless" (
    self: Texture2d,
    to_canvas_item_: Rid,
    pos_: Vector2,
    modulate_: Color,
    transpose_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1384643611)
    }
    self := self
    to_canvas_item_ := to_canvas_item_
    pos_ := pos_
    modulate_ := modulate_
    transpose_ := transpose_
    args := []__bindgen_gde.TypePtr {
        &to_canvas_item_,
        &pos_,
        &modulate_,
        &transpose_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture2d__draw_rect :: proc "contextless" (
    self: Texture2d,
    to_canvas_item_: Rid,
    rect_: Rect2,
    tile_: Bool,
    modulate_: Color,
    transpose_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_draw_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3819628907)
    }
    self := self
    to_canvas_item_ := to_canvas_item_
    rect_ := rect_
    tile_ := tile_
    modulate_ := modulate_
    transpose_ := transpose_
    args := []__bindgen_gde.TypePtr {
        &to_canvas_item_,
        &rect_,
        &tile_,
        &modulate_,
        &transpose_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture2d__draw_rect_region :: proc "contextless" (
    self: Texture2d,
    to_canvas_item_: Rid,
    rect_: Rect2,
    src_rect_: Rect2,
    modulate_: Color,
    transpose_: Bool,
    clip_uv_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_draw_rect_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4094143664)
    }
    self := self
    to_canvas_item_ := to_canvas_item_
    rect_ := rect_
    src_rect_ := src_rect_
    modulate_ := modulate_
    transpose_ := transpose_
    clip_uv_ := clip_uv_
    args := []__bindgen_gde.TypePtr {
        &to_canvas_item_,
        &rect_,
        &src_rect_,
        &modulate_,
        &transpose_,
        &clip_uv_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture2d_get_width :: proc "contextless" (
    self: Texture2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture2d_get_height :: proc "contextless" (
    self: Texture2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture2d_get_size :: proc "contextless" (
    self: Texture2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture2d_has_alpha :: proc "contextless" (
    self: Texture2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("has_alpha", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture2d_draw :: proc "contextless" (
    self: Texture2d,
    canvas_item_: Rid,
    position_: Vector2,
    modulate_: Color,
    transpose_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2729649137)
    }
    self := self
    canvas_item_ := canvas_item_
    position_ := position_
    modulate_ := modulate_
    transpose_ := transpose_
    args := []__bindgen_gde.TypePtr {
        &canvas_item_,
        &position_,
        &modulate_,
        &transpose_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture2d_draw_rect :: proc "contextless" (
    self: Texture2d,
    canvas_item_: Rid,
    rect_: Rect2,
    tile_: Bool,
    modulate_: Color,
    transpose_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3499451691)
    }
    self := self
    canvas_item_ := canvas_item_
    rect_ := rect_
    tile_ := tile_
    modulate_ := modulate_
    transpose_ := transpose_
    args := []__bindgen_gde.TypePtr {
        &canvas_item_,
        &rect_,
        &tile_,
        &modulate_,
        &transpose_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture2d_draw_rect_region :: proc "contextless" (
    self: Texture2d,
    canvas_item_: Rid,
    rect_: Rect2,
    src_rect_: Rect2,
    modulate_: Color,
    transpose_: Bool,
    clip_uv_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw_rect_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2963678660)
    }
    self := self
    canvas_item_ := canvas_item_
    rect_ := rect_
    src_rect_ := src_rect_
    modulate_ := modulate_
    transpose_ := transpose_
    clip_uv_ := clip_uv_
    args := []__bindgen_gde.TypePtr {
        &canvas_item_,
        &rect_,
        &src_rect_,
        &modulate_,
        &transpose_,
        &clip_uv_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

texture2d_get_image :: proc "contextless" (
    self: Texture2d,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_image", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4190603485)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

texture2d_create_placeholder :: proc "contextless" (
    self: Texture2d,
) -> (ret: Resource) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("create_placeholder", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 121922552)
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
texture2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Texture2D", true)
}

@(private = "file")
__class_name: String_Name