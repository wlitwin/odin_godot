package godot

import __bindgen_gde "godot:gdext"

Web_Xr_Interface_Constants :: enum {
}
Web_Xr_Interface_Target_Ray_Mode :: enum int {
    Target_Ray_Mode_Unknown = 0,
    Target_Ray_Mode_Gaze = 1,
    Target_Ray_Mode_Tracked_Pointer = 2,
    Target_Ray_Mode_Screen = 3,
}



web_xr_interface_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

web_xr_interface_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_web_xr_interface :: proc "contextless" () -> Web_Xr_Interface {
    return cast(Web_Xr_Interface)__bindgen_gde.classdb_construct_object(web_xr_interface_name_ref())
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

web_xr_interface_is_session_supported :: proc "contextless" (
    self: Web_Xr_Interface,
    session_mode_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_session_supported", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    session_mode_ := session_mode_
    args := []__bindgen_gde.TypePtr {
        &session_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_xr_interface_set_session_mode :: proc "contextless" (
    self: Web_Xr_Interface,
    session_mode_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_session_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    session_mode_ := session_mode_
    args := []__bindgen_gde.TypePtr {
        &session_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_xr_interface_get_session_mode :: proc "contextless" (
    self: Web_Xr_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_session_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_xr_interface_set_required_features :: proc "contextless" (
    self: Web_Xr_Interface,
    required_features_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_required_features", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    required_features_ := required_features_
    args := []__bindgen_gde.TypePtr {
        &required_features_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_xr_interface_get_required_features :: proc "contextless" (
    self: Web_Xr_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_required_features", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_xr_interface_set_optional_features :: proc "contextless" (
    self: Web_Xr_Interface,
    optional_features_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_optional_features", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    optional_features_ := optional_features_
    args := []__bindgen_gde.TypePtr {
        &optional_features_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_xr_interface_get_optional_features :: proc "contextless" (
    self: Web_Xr_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_optional_features", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_xr_interface_get_reference_space_type :: proc "contextless" (
    self: Web_Xr_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_reference_space_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_xr_interface_get_enabled_features :: proc "contextless" (
    self: Web_Xr_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_enabled_features", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_xr_interface_set_requested_reference_space_types :: proc "contextless" (
    self: Web_Xr_Interface,
    requested_reference_space_types_: String,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_requested_reference_space_types", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 83702148)
    }
    self := self
    requested_reference_space_types_ := requested_reference_space_types_
    args := []__bindgen_gde.TypePtr {
        &requested_reference_space_types_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_xr_interface_get_requested_reference_space_types :: proc "contextless" (
    self: Web_Xr_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_requested_reference_space_types", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_xr_interface_is_input_source_active :: proc "contextless" (
    self: Web_Xr_Interface,
    input_source_id_: Int,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_input_source_active", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1116898809)
    }
    self := self
    input_source_id_ := input_source_id_
    args := []__bindgen_gde.TypePtr {
        &input_source_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_xr_interface_get_input_source_tracker :: proc "contextless" (
    self: Web_Xr_Interface,
    input_source_id_: Int,
) -> (ret: Xr_Controller_Tracker) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_source_tracker", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 399776966)
    }
    self := self
    input_source_id_ := input_source_id_
    args := []__bindgen_gde.TypePtr {
        &input_source_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_xr_interface_get_input_source_target_ray_mode :: proc "contextless" (
    self: Web_Xr_Interface,
    input_source_id_: Int,
) -> (ret: Web_Xr_Interface_Target_Ray_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_input_source_target_ray_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2852387453)
    }
    self := self
    input_source_id_ := input_source_id_
    args := []__bindgen_gde.TypePtr {
        &input_source_id_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_xr_interface_get_visibility_state :: proc "contextless" (
    self: Web_Xr_Interface,
) -> (ret: String) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_visibility_state", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 201670096)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_xr_interface_get_display_refresh_rate :: proc "contextless" (
    self: Web_Xr_Interface,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_display_refresh_rate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

web_xr_interface_set_display_refresh_rate :: proc "contextless" (
    self: Web_Xr_Interface,
    refresh_rate_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_display_refresh_rate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    refresh_rate_ := refresh_rate_
    args := []__bindgen_gde.TypePtr {
        &refresh_rate_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

web_xr_interface_get_available_display_refresh_rates :: proc "contextless" (
    self: Web_Xr_Interface,
) -> (ret: Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_available_display_refresh_rates", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3995934104)
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
web_xr_interface_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("WebXRInterface", true)
}

@(private = "file")
__class_name: String_Name