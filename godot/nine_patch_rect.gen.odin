package godot

import __bindgen_gde "godot:gdext"

Nine_Patch_Rect_Constants :: enum {
}
Nine_Patch_Rect_Axis_Stretch_Mode :: enum int {
    Axis_Stretch_Mode_Stretch = 0,
    Axis_Stretch_Mode_Tile = 1,
    Axis_Stretch_Mode_Tile_Fit = 2,
}



nine_patch_rect_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

nine_patch_rect_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_nine_patch_rect :: proc "contextless" () -> Nine_Patch_Rect {
    return cast(Nine_Patch_Rect)__bindgen_gde.classdb_construct_object(nine_patch_rect_name_ref())
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

nine_patch_rect_set_texture :: proc "contextless" (
    self: Nine_Patch_Rect,
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

nine_patch_rect_get_texture :: proc "contextless" (
    self: Nine_Patch_Rect,
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

nine_patch_rect_set_patch_margin :: proc "contextless" (
    self: Nine_Patch_Rect,
    margin_: Side,
    value_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_patch_margin", true)
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

nine_patch_rect_get_patch_margin :: proc "contextless" (
    self: Nine_Patch_Rect,
    margin_: Side,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_patch_margin", true)
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

nine_patch_rect_set_region_rect :: proc "contextless" (
    self: Nine_Patch_Rect,
    rect_: Rect2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_region_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2046264180)
    }
    self := self
    rect_ := rect_
    args := []__bindgen_gde.TypePtr {
        &rect_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

nine_patch_rect_get_region_rect :: proc "contextless" (
    self: Nine_Patch_Rect,
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

nine_patch_rect_set_draw_center :: proc "contextless" (
    self: Nine_Patch_Rect,
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

nine_patch_rect_is_draw_center_enabled :: proc "contextless" (
    self: Nine_Patch_Rect,
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

nine_patch_rect_set_h_axis_stretch_mode :: proc "contextless" (
    self: Nine_Patch_Rect,
    mode_: Nine_Patch_Rect_Axis_Stretch_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_h_axis_stretch_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3219608417)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

nine_patch_rect_get_h_axis_stretch_mode :: proc "contextless" (
    self: Nine_Patch_Rect,
) -> (ret: Nine_Patch_Rect_Axis_Stretch_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_h_axis_stretch_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3317113799)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

nine_patch_rect_set_v_axis_stretch_mode :: proc "contextless" (
    self: Nine_Patch_Rect,
    mode_: Nine_Patch_Rect_Axis_Stretch_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_v_axis_stretch_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3219608417)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

nine_patch_rect_get_v_axis_stretch_mode :: proc "contextless" (
    self: Nine_Patch_Rect,
) -> (ret: Nine_Patch_Rect_Axis_Stretch_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_v_axis_stretch_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3317113799)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
nine_patch_rect_get_draw_center :: proc "contextless" (self: Nine_Patch_Rect) -> Bool {
    return nine_patch_rect_is_draw_center_enabled(self)
}
nine_patch_rect_get_patch_margin_left :: proc "contextless" (self: Nine_Patch_Rect) -> i32 {
    return nine_patch_rect_get_patch_margin(self, Side(0))
}
nine_patch_rect_set_patch_margin_left :: proc "contextless" (self: Nine_Patch_Rect, value: Int) {
    nine_patch_rect_set_patch_margin(self, Side(0), value)
}
nine_patch_rect_get_patch_margin_top :: proc "contextless" (self: Nine_Patch_Rect) -> i32 {
    return nine_patch_rect_get_patch_margin(self, Side(1))
}
nine_patch_rect_set_patch_margin_top :: proc "contextless" (self: Nine_Patch_Rect, value: Int) {
    nine_patch_rect_set_patch_margin(self, Side(1), value)
}
nine_patch_rect_get_patch_margin_right :: proc "contextless" (self: Nine_Patch_Rect) -> i32 {
    return nine_patch_rect_get_patch_margin(self, Side(2))
}
nine_patch_rect_set_patch_margin_right :: proc "contextless" (self: Nine_Patch_Rect, value: Int) {
    nine_patch_rect_set_patch_margin(self, Side(2), value)
}
nine_patch_rect_get_patch_margin_bottom :: proc "contextless" (self: Nine_Patch_Rect) -> i32 {
    return nine_patch_rect_get_patch_margin(self, Side(3))
}
nine_patch_rect_set_patch_margin_bottom :: proc "contextless" (self: Nine_Patch_Rect, value: Int) {
    nine_patch_rect_set_patch_margin(self, Side(3), value)
}
nine_patch_rect_get_axis_stretch_horizontal :: proc "contextless" (self: Nine_Patch_Rect) -> Nine_Patch_Rect_Axis_Stretch_Mode {
    return nine_patch_rect_get_h_axis_stretch_mode(self)
}
nine_patch_rect_set_axis_stretch_horizontal :: proc "contextless" (self: Nine_Patch_Rect, value: Nine_Patch_Rect_Axis_Stretch_Mode) {
    nine_patch_rect_set_h_axis_stretch_mode(self, value)
}
nine_patch_rect_get_axis_stretch_vertical :: proc "contextless" (self: Nine_Patch_Rect) -> Nine_Patch_Rect_Axis_Stretch_Mode {
    return nine_patch_rect_get_v_axis_stretch_mode(self)
}
nine_patch_rect_set_axis_stretch_vertical :: proc "contextless" (self: Nine_Patch_Rect, value: Nine_Patch_Rect_Axis_Stretch_Mode) {
    nine_patch_rect_set_v_axis_stretch_mode(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
nine_patch_rect_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("NinePatchRect", true)
}

@(private = "file")
__class_name: String_Name