package godot

import __bindgen_gde "godot:gdext"

Light2d_Constants :: enum {
}
Light2d_Shadow_Filter :: enum int {
    Shadow_Filter_None = 0,
    Shadow_Filter_Pcf5 = 1,
    Shadow_Filter_Pcf13 = 2,
}
Light2d_Blend_Mode :: enum int {
    Blend_Mode_Add = 0,
    Blend_Mode_Sub = 1,
    Blend_Mode_Mix = 2,
}



light2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

light2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_light2d :: proc "contextless" () -> Light2d {
    return cast(Light2d)__bindgen_gde.classdb_construct_object(light2d_name_ref())
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

light2d_set_enabled :: proc "contextless" (
    self: Light2d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_is_enabled :: proc "contextless" (
    self: Light2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_editor_only :: proc "contextless" (
    self: Light2d,
    editor_only_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_editor_only", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    editor_only_ := editor_only_
    args := []__bindgen_gde.TypePtr {
        &editor_only_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_is_editor_only :: proc "contextless" (
    self: Light2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_editor_only", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_color :: proc "contextless" (
    self: Light2d,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_get_color :: proc "contextless" (
    self: Light2d,
) -> (ret: Color) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3444240500)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_energy :: proc "contextless" (
    self: Light2d,
    energy_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_energy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    energy_ := energy_
    args := []__bindgen_gde.TypePtr {
        &energy_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_get_energy :: proc "contextless" (
    self: Light2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_energy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_z_range_min :: proc "contextless" (
    self: Light2d,
    z_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_z_range_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    z_ := z_
    args := []__bindgen_gde.TypePtr {
        &z_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_get_z_range_min :: proc "contextless" (
    self: Light2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_z_range_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_z_range_max :: proc "contextless" (
    self: Light2d,
    z_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_z_range_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    z_ := z_
    args := []__bindgen_gde.TypePtr {
        &z_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_get_z_range_max :: proc "contextless" (
    self: Light2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_z_range_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_layer_range_min :: proc "contextless" (
    self: Light2d,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layer_range_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_get_layer_range_min :: proc "contextless" (
    self: Light2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_layer_range_min", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_layer_range_max :: proc "contextless" (
    self: Light2d,
    layer_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layer_range_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    layer_ := layer_
    args := []__bindgen_gde.TypePtr {
        &layer_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_get_layer_range_max :: proc "contextless" (
    self: Light2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_layer_range_max", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_item_cull_mask :: proc "contextless" (
    self: Light2d,
    item_cull_mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_cull_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    item_cull_mask_ := item_cull_mask_
    args := []__bindgen_gde.TypePtr {
        &item_cull_mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_get_item_cull_mask :: proc "contextless" (
    self: Light2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_cull_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_item_shadow_cull_mask :: proc "contextless" (
    self: Light2d,
    item_shadow_cull_mask_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_item_shadow_cull_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    item_shadow_cull_mask_ := item_shadow_cull_mask_
    args := []__bindgen_gde.TypePtr {
        &item_shadow_cull_mask_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_get_item_shadow_cull_mask :: proc "contextless" (
    self: Light2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_item_shadow_cull_mask", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_shadow_enabled :: proc "contextless" (
    self: Light2d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadow_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_is_shadow_enabled :: proc "contextless" (
    self: Light2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_shadow_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_shadow_smooth :: proc "contextless" (
    self: Light2d,
    smooth_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadow_smooth", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    smooth_ := smooth_
    args := []__bindgen_gde.TypePtr {
        &smooth_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_get_shadow_smooth :: proc "contextless" (
    self: Light2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shadow_smooth", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_shadow_filter :: proc "contextless" (
    self: Light2d,
    filter_: Light2d_Shadow_Filter,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadow_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3209356555)
    }
    self := self
    filter_ := filter_
    args := []__bindgen_gde.TypePtr {
        &filter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_get_shadow_filter :: proc "contextless" (
    self: Light2d,
) -> (ret: Light2d_Shadow_Filter) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shadow_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1973619177)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_shadow_color :: proc "contextless" (
    self: Light2d,
    shadow_color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shadow_color", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2920490490)
    }
    self := self
    shadow_color_ := shadow_color_
    args := []__bindgen_gde.TypePtr {
        &shadow_color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_get_shadow_color :: proc "contextless" (
    self: Light2d,
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

light2d_set_blend_mode :: proc "contextless" (
    self: Light2d,
    mode_: Light2d_Blend_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_blend_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2916638796)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_get_blend_mode :: proc "contextless" (
    self: Light2d,
) -> (ret: Light2d_Blend_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_blend_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 936255250)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

light2d_set_height :: proc "contextless" (
    self: Light2d,
    height_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    height_ := height_
    args := []__bindgen_gde.TypePtr {
        &height_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

light2d_get_height :: proc "contextless" (
    self: Light2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
light2d_get_enabled :: proc "contextless" (self: Light2d) -> Bool {
    return light2d_is_enabled(self)
}
light2d_get_editor_only :: proc "contextless" (self: Light2d) -> Bool {
    return light2d_is_editor_only(self)
}
light2d_get_range_z_min :: proc "contextless" (self: Light2d) -> i32 {
    return light2d_get_z_range_min(self)
}
light2d_set_range_z_min :: proc "contextless" (self: Light2d, value: Int) {
    light2d_set_z_range_min(self, value)
}
light2d_get_range_z_max :: proc "contextless" (self: Light2d) -> i32 {
    return light2d_get_z_range_max(self)
}
light2d_set_range_z_max :: proc "contextless" (self: Light2d, value: Int) {
    light2d_set_z_range_max(self, value)
}
light2d_get_range_layer_min :: proc "contextless" (self: Light2d) -> i32 {
    return light2d_get_layer_range_min(self)
}
light2d_set_range_layer_min :: proc "contextless" (self: Light2d, value: Int) {
    light2d_set_layer_range_min(self, value)
}
light2d_get_range_layer_max :: proc "contextless" (self: Light2d) -> i32 {
    return light2d_get_layer_range_max(self)
}
light2d_set_range_layer_max :: proc "contextless" (self: Light2d, value: Int) {
    light2d_set_layer_range_max(self, value)
}
light2d_get_range_item_cull_mask :: proc "contextless" (self: Light2d) -> i32 {
    return light2d_get_item_cull_mask(self)
}
light2d_set_range_item_cull_mask :: proc "contextless" (self: Light2d, value: Int) {
    light2d_set_item_cull_mask(self, value)
}
light2d_get_shadow_enabled :: proc "contextless" (self: Light2d) -> Bool {
    return light2d_is_shadow_enabled(self)
}
light2d_get_shadow_filter_smooth :: proc "contextless" (self: Light2d) -> f64 {
    return light2d_get_shadow_smooth(self)
}
light2d_set_shadow_filter_smooth :: proc "contextless" (self: Light2d, value: f64) {
    light2d_set_shadow_smooth(self, value)
}
light2d_get_shadow_item_cull_mask :: proc "contextless" (self: Light2d) -> i32 {
    return light2d_get_item_shadow_cull_mask(self)
}
light2d_set_shadow_item_cull_mask :: proc "contextless" (self: Light2d, value: Int) {
    light2d_set_item_shadow_cull_mask(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
light2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Light2D", true)
}

@(private = "file")
__class_name: String_Name