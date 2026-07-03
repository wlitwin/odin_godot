package godot

import __bindgen_gde "godot:gdext"

Style_Box_Constants :: enum {
}



style_box_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

style_box_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_style_box :: proc "contextless" () -> Style_Box {
    return cast(Style_Box)__bindgen_gde.classdb_construct_object(style_box_name_ref())
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

style_box__draw :: proc "contextless" (
    self: Style_Box,
    to_canvas_item_: Rid,
    rect_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2275962004)
    }
    self := self
    to_canvas_item_ := to_canvas_item_
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &to_canvas_item_,
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box__get_draw_rect :: proc "contextless" (
    self: Style_Box,
    rect_: Rect2,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_draw_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 408950903)
    }
    self := self
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box__get_minimum_size :: proc "contextless" (
    self: Style_Box,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_get_minimum_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box__test_mask :: proc "contextless" (
    self: Style_Box,
    point_: Vector2,
    rect_: Rect2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("_test_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3735564539)
    }
    self := self
    point_ := point_
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &point_,
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_get_minimum_size :: proc "contextless" (
    self: Style_Box,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_minimum_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_set_content_margin :: proc "contextless" (
    self: Style_Box,
    margin_: Side,
    offset_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_content_margin", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4290182280)
    }
    self := self
    margin_ := margin_
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &margin_,
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_set_content_margin_all :: proc "contextless" (
    self: Style_Box,
    offset_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_content_margin_all", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_get_content_margin :: proc "contextless" (
    self: Style_Box,
    margin_: Side,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_content_margin", true)
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

style_box_get_margin :: proc "contextless" (
    self: Style_Box,
    margin_: Side,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_margin", true)
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

style_box_get_offset :: proc "contextless" (
    self: Style_Box,
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

style_box_draw :: proc "contextless" (
    self: Style_Box,
    canvas_item_: Rid,
    rect_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2275962004)
    }
    self := self
    canvas_item_ := canvas_item_
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &canvas_item_,
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

style_box_get_current_item_drawn :: proc "contextless" (
    self: Style_Box,
) -> (ret: Canvas_Item) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_current_item_drawn", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3213695180)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

style_box_test_mask :: proc "contextless" (
    self: Style_Box,
    point_: Vector2,
    rect_: Rect2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("test_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3735564539)
    }
    self := self
    point_ := point_
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &point_,
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
style_box_get_content_margin_left :: proc "contextless" (self: Style_Box) -> f64 {
    return style_box_get_content_margin(self, Side(0))
}
style_box_set_content_margin_left :: proc "contextless" (self: Style_Box, value: f64) {
    style_box_set_content_margin(self, Side(0), value)
}
style_box_get_content_margin_top :: proc "contextless" (self: Style_Box) -> f64 {
    return style_box_get_content_margin(self, Side(1))
}
style_box_set_content_margin_top :: proc "contextless" (self: Style_Box, value: f64) {
    style_box_set_content_margin(self, Side(1), value)
}
style_box_get_content_margin_right :: proc "contextless" (self: Style_Box) -> f64 {
    return style_box_get_content_margin(self, Side(2))
}
style_box_set_content_margin_right :: proc "contextless" (self: Style_Box, value: f64) {
    style_box_set_content_margin(self, Side(2), value)
}
style_box_get_content_margin_bottom :: proc "contextless" (self: Style_Box) -> f64 {
    return style_box_get_content_margin(self, Side(3))
}
style_box_set_content_margin_bottom :: proc "contextless" (self: Style_Box, value: f64) {
    style_box_set_content_margin(self, Side(3), value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
style_box_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("StyleBox", true)
}

@(private = "file")
__class_name: String_Name