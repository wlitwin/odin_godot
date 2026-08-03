package godot

import __bindgen_gde "godot:gdext"

Color_Picker_Constants :: enum {
}
Color_Picker_Color_Mode_Type :: enum int {
    Mode_Rgb = 0,
    Mode_Hsv = 1,
    Mode_Raw = 2,
    Mode_Linear = 2,
    Mode_Okhsl = 3,
}
Color_Picker_Picker_Shape_Type :: enum int {
    Shape_Hsv_Rectangle = 0,
    Shape_Hsv_Wheel = 1,
    Shape_Vhs_Circle = 2,
    Shape_Okhsl_Circle = 3,
    Shape_None = 4,
    Shape_Ok_Hs_Rectangle = 5,
    Shape_Ok_Hl_Rectangle = 6,
}



color_picker_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

color_picker_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_color_picker :: proc "contextless" () -> Color_Picker {
    return cast(Color_Picker)__bindgen_gde.classdb_construct_object(color_picker_name_ref())
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

color_picker_set_pick_color :: proc "contextless" (
    self: Color_Picker,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_pick_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_get_pick_color :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_pick_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

color_picker_set_deferred_mode :: proc "contextless" (
    self: Color_Picker,
    mode_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_deferred_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_is_deferred_mode :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_deferred_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

color_picker_set_color_mode :: proc "contextless" (
    self: Color_Picker,
    color_mode_: Color_Picker_Color_Mode_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_color_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1579114136)
    }
    self := self
    color_mode_ := color_mode_
    args := []__bindgen_gde.TypePtr {
        &color_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_get_color_mode :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Color_Picker_Color_Mode_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 392907674)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

color_picker_set_edit_alpha :: proc "contextless" (
    self: Color_Picker,
    show_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_edit_alpha", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    show_ := show_
    args := []__bindgen_gde.TypePtr {
        &show_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_is_editing_alpha :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_editing_alpha", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

color_picker_set_edit_intensity :: proc "contextless" (
    self: Color_Picker,
    show_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_edit_intensity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    show_ := show_
    args := []__bindgen_gde.TypePtr {
        &show_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_is_editing_intensity :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_editing_intensity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

color_picker_set_can_add_swatches :: proc "contextless" (
    self: Color_Picker,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_can_add_swatches", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_are_swatches_enabled :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("are_swatches_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

color_picker_set_presets_visible :: proc "contextless" (
    self: Color_Picker,
    visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_presets_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    visible_ := visible_
    args := []__bindgen_gde.TypePtr {
        &visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_are_presets_visible :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("are_presets_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

color_picker_set_modes_visible :: proc "contextless" (
    self: Color_Picker,
    visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_modes_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    visible_ := visible_
    args := []__bindgen_gde.TypePtr {
        &visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_are_modes_visible :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("are_modes_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

color_picker_set_sampler_visible :: proc "contextless" (
    self: Color_Picker,
    visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sampler_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    visible_ := visible_
    args := []__bindgen_gde.TypePtr {
        &visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_is_sampler_visible :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_sampler_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

color_picker_set_sliders_visible :: proc "contextless" (
    self: Color_Picker,
    visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sliders_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    visible_ := visible_
    args := []__bindgen_gde.TypePtr {
        &visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_are_sliders_visible :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("are_sliders_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

color_picker_set_hex_visible :: proc "contextless" (
    self: Color_Picker,
    visible_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_hex_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    visible_ := visible_
    args := []__bindgen_gde.TypePtr {
        &visible_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_is_hex_visible :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_hex_visible", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

color_picker_add_preset :: proc "contextless" (
    self: Color_Picker,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_preset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_erase_preset :: proc "contextless" (
    self: Color_Picker,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase_preset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_get_presets :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Packed_Color_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_presets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1392750486)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

color_picker_add_recent_preset :: proc "contextless" (
    self: Color_Picker,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_recent_preset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_erase_recent_preset :: proc "contextless" (
    self: Color_Picker,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("erase_recent_preset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_get_recent_presets :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Packed_Color_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_recent_presets", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1392750486)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

color_picker_set_picker_shape :: proc "contextless" (
    self: Color_Picker,
    shape_: Color_Picker_Picker_Shape_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_picker_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3981373861)
    }
    self := self
    shape_ := shape_
    args := []__bindgen_gde.TypePtr {
        &shape_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

color_picker_get_picker_shape :: proc "contextless" (
    self: Color_Picker,
) -> (ret: Color_Picker_Picker_Shape_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_picker_shape", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1143229889)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
color_picker_get_color :: proc "contextless" (self: Color_Picker) -> Color {
    return color_picker_get_pick_color(self)
}
color_picker_set_color :: proc "contextless" (self: Color_Picker, value: Color) {
    color_picker_set_pick_color(self, value)
}
color_picker_get_edit_alpha :: proc "contextless" (self: Color_Picker) -> Bool {
    return color_picker_is_editing_alpha(self)
}
color_picker_get_edit_intensity :: proc "contextless" (self: Color_Picker) -> Bool {
    return color_picker_is_editing_intensity(self)
}
color_picker_get_deferred_mode :: proc "contextless" (self: Color_Picker) -> Bool {
    return color_picker_is_deferred_mode(self)
}
color_picker_get_can_add_swatches :: proc "contextless" (self: Color_Picker) -> Bool {
    return color_picker_are_swatches_enabled(self)
}
color_picker_get_sampler_visible :: proc "contextless" (self: Color_Picker) -> Bool {
    return color_picker_is_sampler_visible(self)
}
color_picker_get_color_modes_visible :: proc "contextless" (self: Color_Picker) -> Bool {
    return color_picker_are_modes_visible(self)
}
color_picker_set_color_modes_visible :: proc "contextless" (self: Color_Picker, value: Bool) {
    color_picker_set_modes_visible(self, value)
}
color_picker_get_sliders_visible :: proc "contextless" (self: Color_Picker) -> Bool {
    return color_picker_are_sliders_visible(self)
}
color_picker_get_hex_visible :: proc "contextless" (self: Color_Picker) -> Bool {
    return color_picker_is_hex_visible(self)
}
color_picker_get_presets_visible :: proc "contextless" (self: Color_Picker) -> Bool {
    return color_picker_are_presets_visible(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
color_picker_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("ColorPicker", true)
}

@(private = "file")
__class_name: String_Name