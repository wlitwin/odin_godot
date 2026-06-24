package godot

import __bindgen_gde "godot:gdext"

Open_Xr_Dpad_Binding_Modifier_Constants :: enum {
}



open_xr_dpad_binding_modifier_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

open_xr_dpad_binding_modifier_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_open_xr_dpad_binding_modifier :: proc "contextless" () -> Open_Xr_Dpad_Binding_Modifier {
    return cast(Open_Xr_Dpad_Binding_Modifier)__bindgen_gde.classdb_construct_object(open_xr_dpad_binding_modifier_name_ref())
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

open_xr_dpad_binding_modifier_set_action_set :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
    action_set_: Open_Xr_Action_Set,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_action_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2093310581)
    }
    self := self
    action_set_ := action_set_
    args := []__bindgen_gde.TypePtr {
        &action_set_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_dpad_binding_modifier_get_action_set :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
) -> (ret: Open_Xr_Action_Set) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_action_set", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 619941079)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_dpad_binding_modifier_set_input_path :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
    input_path_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_input_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    input_path_ := input_path_
    args := []__bindgen_gde.TypePtr {
        &input_path_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_dpad_binding_modifier_get_input_path :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_path", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_dpad_binding_modifier_set_threshold :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
    threshold_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_threshold", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    threshold_ := threshold_
    args := []__bindgen_gde.TypePtr {
        &threshold_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_dpad_binding_modifier_get_threshold :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_threshold", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_dpad_binding_modifier_set_threshold_released :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
    threshold_released_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_threshold_released", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    threshold_released_ := threshold_released_
    args := []__bindgen_gde.TypePtr {
        &threshold_released_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_dpad_binding_modifier_get_threshold_released :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_threshold_released", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_dpad_binding_modifier_set_center_region :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
    center_region_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_center_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    center_region_ := center_region_
    args := []__bindgen_gde.TypePtr {
        &center_region_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_dpad_binding_modifier_get_center_region :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_center_region", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_dpad_binding_modifier_set_wedge_angle :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
    wedge_angle_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_wedge_angle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    wedge_angle_ := wedge_angle_
    args := []__bindgen_gde.TypePtr {
        &wedge_angle_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_dpad_binding_modifier_get_wedge_angle :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_wedge_angle", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_dpad_binding_modifier_set_is_sticky :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
    is_sticky_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_is_sticky", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    is_sticky_ := is_sticky_
    args := []__bindgen_gde.TypePtr {
        &is_sticky_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_dpad_binding_modifier_get_is_sticky :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_is_sticky", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_dpad_binding_modifier_set_on_haptic :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
    haptic_: Open_Xr_Haptic_Base,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_on_haptic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2998020150)
    }
    self := self
    haptic_ := haptic_
    args := []__bindgen_gde.TypePtr {
        &haptic_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_dpad_binding_modifier_get_on_haptic :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
) -> (ret: Open_Xr_Haptic_Base) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_on_haptic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 922310751)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

open_xr_dpad_binding_modifier_set_off_haptic :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
    haptic_: Open_Xr_Haptic_Base,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_off_haptic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2998020150)
    }
    self := self
    haptic_ := haptic_
    args := []__bindgen_gde.TypePtr {
        &haptic_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

open_xr_dpad_binding_modifier_get_off_haptic :: proc "contextless" (
    self: Open_Xr_Dpad_Binding_Modifier,
) -> (ret: Open_Xr_Haptic_Base) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_off_haptic", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 922310751)
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
open_xr_dpad_binding_modifier_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OpenXRDpadBindingModifier", true)
}

@(private = "file")
__class_name: String_Name