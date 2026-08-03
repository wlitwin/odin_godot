package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Composition_Layer_Constants :: enum {
}
Open_Xr_Composition_Layer_Filter :: enum int {
    Filter_Nearest = 0,
    Filter_Linear = 1,
    Filter_Cubic = 2,
}
Open_Xr_Composition_Layer_Mipmap_Mode :: enum int {
    Mipmap_Mode_Disabled = 0,
    Mipmap_Mode_Nearest = 1,
    Mipmap_Mode_Linear = 2,
}
Open_Xr_Composition_Layer_Wrap :: enum int {
    Wrap_Clamp_To_Border = 0,
    Wrap_Clamp_To_Edge = 1,
    Wrap_Repeat = 2,
    Wrap_Mirrored_Repeat = 3,
    Wrap_Mirror_Clamp_To_Edge = 4,
}
Open_Xr_Composition_Layer_Swizzle :: enum int {
    Swizzle_Red = 0,
    Swizzle_Green = 1,
    Swizzle_Blue = 2,
    Swizzle_Alpha = 3,
    Swizzle_Zero = 4,
    Swizzle_One = 5,
}
Open_Xr_Composition_Layer_Eye_Visibility :: enum int {
    Eye_Visibility_Both = 0,
    Eye_Visibility_Left = 1,
    Eye_Visibility_Right = 2,
}



open_xr_composition_layer_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_composition_layer_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_composition_layer :: proc "contextless" () -> Open_Xr_Composition_Layer {
    return cast(Open_Xr_Composition_Layer)__bindgen_gde.classdb_construct_object(open_xr_composition_layer_name_ref())
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

open_xr_composition_layer_set_layer_viewport :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    viewport_: Sub_Viewport,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_layer_viewport", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3888077664)
    }
    self := self
    viewport_ := viewport_
    args := []__bindgen_gde.TypePtr {
        &viewport_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_layer_viewport :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Sub_Viewport) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_layer_viewport", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3750751911)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_use_android_surface :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_android_surface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_use_android_surface :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_use_android_surface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_android_surface_size :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    size_: Vector2i,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_android_surface_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1130785943)
    }
    self := self
    size_ := size_
    args := []__bindgen_gde.TypePtr {
        &size_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_android_surface_size :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Vector2i) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_android_surface_size", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3690982128)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_enable_hole_punch :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    enable_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_enable_hole_punch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enable_ := enable_
    args := []__bindgen_gde.TypePtr {
        &enable_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_enable_hole_punch :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_enable_hole_punch", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_sort_order :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    order_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_sort_order", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    order_ := order_
    args := []__bindgen_gde.TypePtr {
        &order_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_sort_order :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_sort_order", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_alpha_blend :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alpha_blend", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_alpha_blend :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alpha_blend", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_get_android_surface :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Java_Object) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_android_surface", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3277089691)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_is_natively_supported :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_natively_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_is_protected_content :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_protected_content", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_protected_content :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    protected_content_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_protected_content", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    protected_content_ := protected_content_
    args := []__bindgen_gde.TypePtr {
        &protected_content_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_set_min_filter :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    mode_: Open_Xr_Composition_Layer_Filter,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_min_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3653437593)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_min_filter :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Open_Xr_Composition_Layer_Filter) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_min_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 845677307)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_mag_filter :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    mode_: Open_Xr_Composition_Layer_Filter,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mag_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3653437593)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_mag_filter :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Open_Xr_Composition_Layer_Filter) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mag_filter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 845677307)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_mipmap_mode :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    mode_: Open_Xr_Composition_Layer_Mipmap_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_mipmap_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3271133183)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_mipmap_mode :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Open_Xr_Composition_Layer_Mipmap_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_mipmap_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3962697095)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_horizontal_wrap :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    mode_: Open_Xr_Composition_Layer_Wrap,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_horizontal_wrap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 15634990)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_horizontal_wrap :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Open_Xr_Composition_Layer_Wrap) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_horizontal_wrap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2798816834)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_vertical_wrap :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    mode_: Open_Xr_Composition_Layer_Wrap,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_vertical_wrap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 15634990)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_vertical_wrap :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Open_Xr_Composition_Layer_Wrap) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_vertical_wrap", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2798816834)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_red_swizzle :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    mode_: Open_Xr_Composition_Layer_Swizzle,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_red_swizzle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 741598951)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_red_swizzle :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Open_Xr_Composition_Layer_Swizzle) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_red_swizzle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2334776767)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_green_swizzle :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    mode_: Open_Xr_Composition_Layer_Swizzle,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_green_swizzle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 741598951)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_green_swizzle :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Open_Xr_Composition_Layer_Swizzle) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_green_swizzle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2334776767)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_blue_swizzle :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    mode_: Open_Xr_Composition_Layer_Swizzle,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_blue_swizzle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 741598951)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_blue_swizzle :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Open_Xr_Composition_Layer_Swizzle) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_blue_swizzle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2334776767)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_alpha_swizzle :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    mode_: Open_Xr_Composition_Layer_Swizzle,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alpha_swizzle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 741598951)
    }
    self := self
    mode_ := mode_
    args := []__bindgen_gde.TypePtr {
        &mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_alpha_swizzle :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Open_Xr_Composition_Layer_Swizzle) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alpha_swizzle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2334776767)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_max_anisotropy :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    value_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_max_anisotropy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    value_ := value_
    args := []__bindgen_gde.TypePtr {
        &value_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_max_anisotropy :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_max_anisotropy", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_set_border_color :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
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

open_xr_composition_layer_get_border_color :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
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

open_xr_composition_layer_set_eye_visibility :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    eye_visibility_: Open_Xr_Composition_Layer_Eye_Visibility,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_eye_visibility", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 156391336)
    }
    self := self
    eye_visibility_ := eye_visibility_
    args := []__bindgen_gde.TypePtr {
        &eye_visibility_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_composition_layer_get_eye_visibility :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
) -> (ret: Open_Xr_Composition_Layer_Eye_Visibility) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_eye_visibility", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 467669000)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_composition_layer_intersects_ray :: proc "contextless" (
    self: Open_Xr_Composition_Layer,
    origin_: Vector3,
    direction_: Vector3,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("intersects_ray", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1091262597)
    }
    self := self
    origin_ := origin_
    direction_ := direction_
    args := []__bindgen_gde.TypePtr {
        &origin_,
        &direction_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
open_xr_composition_layer_get_protected_content :: proc "contextless" (self: Open_Xr_Composition_Layer) -> Bool {
    return open_xr_composition_layer_is_protected_content(self)
}
open_xr_composition_layer_get_swapchain_state_min_filter :: proc "contextless" (self: Open_Xr_Composition_Layer) -> Open_Xr_Composition_Layer_Filter {
    return open_xr_composition_layer_get_min_filter(self)
}
open_xr_composition_layer_set_swapchain_state_min_filter :: proc "contextless" (self: Open_Xr_Composition_Layer, value: Open_Xr_Composition_Layer_Filter) {
    open_xr_composition_layer_set_min_filter(self, value)
}
open_xr_composition_layer_get_swapchain_state_mag_filter :: proc "contextless" (self: Open_Xr_Composition_Layer) -> Open_Xr_Composition_Layer_Filter {
    return open_xr_composition_layer_get_mag_filter(self)
}
open_xr_composition_layer_set_swapchain_state_mag_filter :: proc "contextless" (self: Open_Xr_Composition_Layer, value: Open_Xr_Composition_Layer_Filter) {
    open_xr_composition_layer_set_mag_filter(self, value)
}
open_xr_composition_layer_get_swapchain_state_mipmap_mode :: proc "contextless" (self: Open_Xr_Composition_Layer) -> Open_Xr_Composition_Layer_Mipmap_Mode {
    return open_xr_composition_layer_get_mipmap_mode(self)
}
open_xr_composition_layer_set_swapchain_state_mipmap_mode :: proc "contextless" (self: Open_Xr_Composition_Layer, value: Open_Xr_Composition_Layer_Mipmap_Mode) {
    open_xr_composition_layer_set_mipmap_mode(self, value)
}
open_xr_composition_layer_get_swapchain_state_horizontal_wrap :: proc "contextless" (self: Open_Xr_Composition_Layer) -> Open_Xr_Composition_Layer_Wrap {
    return open_xr_composition_layer_get_horizontal_wrap(self)
}
open_xr_composition_layer_set_swapchain_state_horizontal_wrap :: proc "contextless" (self: Open_Xr_Composition_Layer, value: Open_Xr_Composition_Layer_Wrap) {
    open_xr_composition_layer_set_horizontal_wrap(self, value)
}
open_xr_composition_layer_get_swapchain_state_vertical_wrap :: proc "contextless" (self: Open_Xr_Composition_Layer) -> Open_Xr_Composition_Layer_Wrap {
    return open_xr_composition_layer_get_vertical_wrap(self)
}
open_xr_composition_layer_set_swapchain_state_vertical_wrap :: proc "contextless" (self: Open_Xr_Composition_Layer, value: Open_Xr_Composition_Layer_Wrap) {
    open_xr_composition_layer_set_vertical_wrap(self, value)
}
open_xr_composition_layer_get_swapchain_state_red_swizzle :: proc "contextless" (self: Open_Xr_Composition_Layer) -> Open_Xr_Composition_Layer_Swizzle {
    return open_xr_composition_layer_get_red_swizzle(self)
}
open_xr_composition_layer_set_swapchain_state_red_swizzle :: proc "contextless" (self: Open_Xr_Composition_Layer, value: Open_Xr_Composition_Layer_Swizzle) {
    open_xr_composition_layer_set_red_swizzle(self, value)
}
open_xr_composition_layer_get_swapchain_state_green_swizzle :: proc "contextless" (self: Open_Xr_Composition_Layer) -> Open_Xr_Composition_Layer_Swizzle {
    return open_xr_composition_layer_get_green_swizzle(self)
}
open_xr_composition_layer_set_swapchain_state_green_swizzle :: proc "contextless" (self: Open_Xr_Composition_Layer, value: Open_Xr_Composition_Layer_Swizzle) {
    open_xr_composition_layer_set_green_swizzle(self, value)
}
open_xr_composition_layer_get_swapchain_state_blue_swizzle :: proc "contextless" (self: Open_Xr_Composition_Layer) -> Open_Xr_Composition_Layer_Swizzle {
    return open_xr_composition_layer_get_blue_swizzle(self)
}
open_xr_composition_layer_set_swapchain_state_blue_swizzle :: proc "contextless" (self: Open_Xr_Composition_Layer, value: Open_Xr_Composition_Layer_Swizzle) {
    open_xr_composition_layer_set_blue_swizzle(self, value)
}
open_xr_composition_layer_get_swapchain_state_alpha_swizzle :: proc "contextless" (self: Open_Xr_Composition_Layer) -> Open_Xr_Composition_Layer_Swizzle {
    return open_xr_composition_layer_get_alpha_swizzle(self)
}
open_xr_composition_layer_set_swapchain_state_alpha_swizzle :: proc "contextless" (self: Open_Xr_Composition_Layer, value: Open_Xr_Composition_Layer_Swizzle) {
    open_xr_composition_layer_set_alpha_swizzle(self, value)
}
open_xr_composition_layer_get_swapchain_state_max_anisotropy :: proc "contextless" (self: Open_Xr_Composition_Layer) -> f64 {
    return open_xr_composition_layer_get_max_anisotropy(self)
}
open_xr_composition_layer_set_swapchain_state_max_anisotropy :: proc "contextless" (self: Open_Xr_Composition_Layer, value: f64) {
    open_xr_composition_layer_set_max_anisotropy(self, value)
}
open_xr_composition_layer_get_swapchain_state_border_color :: proc "contextless" (self: Open_Xr_Composition_Layer) -> Color {
    return open_xr_composition_layer_get_border_color(self)
}
open_xr_composition_layer_set_swapchain_state_border_color :: proc "contextless" (self: Open_Xr_Composition_Layer, value: Color) {
    open_xr_composition_layer_set_border_color(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
open_xr_composition_layer_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRCompositionLayer", true)
}

@(private = "file")
__class_name: String_Name