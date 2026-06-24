package godot

import __bindgen_gde "godot:gdext"

Camera_Attributes_Physical_Constants :: enum {
}



camera_attributes_physical_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

camera_attributes_physical_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_camera_attributes_physical :: proc "contextless" () -> Camera_Attributes_Physical {
    return cast(Camera_Attributes_Physical)__bindgen_gde.classdb_construct_object(camera_attributes_physical_name_ref())
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

camera_attributes_physical_set_aperture :: proc "contextless" (
    self: Camera_Attributes_Physical,
    aperture_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_aperture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    aperture_ := aperture_
    args := []__bindgen_gde.TypePtr {
        &aperture_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera_attributes_physical_get_aperture :: proc "contextless" (
    self: Camera_Attributes_Physical,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_aperture", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_attributes_physical_set_shutter_speed :: proc "contextless" (
    self: Camera_Attributes_Physical,
    shutter_speed_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_shutter_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    shutter_speed_ := shutter_speed_
    args := []__bindgen_gde.TypePtr {
        &shutter_speed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera_attributes_physical_get_shutter_speed :: proc "contextless" (
    self: Camera_Attributes_Physical,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_shutter_speed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_attributes_physical_set_focal_length :: proc "contextless" (
    self: Camera_Attributes_Physical,
    focal_length_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_focal_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    focal_length_ := focal_length_
    args := []__bindgen_gde.TypePtr {
        &focal_length_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera_attributes_physical_get_focal_length :: proc "contextless" (
    self: Camera_Attributes_Physical,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_focal_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_attributes_physical_set_focus_distance :: proc "contextless" (
    self: Camera_Attributes_Physical,
    focus_distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_focus_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    focus_distance_ := focus_distance_
    args := []__bindgen_gde.TypePtr {
        &focus_distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera_attributes_physical_get_focus_distance :: proc "contextless" (
    self: Camera_Attributes_Physical,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_focus_distance", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_attributes_physical_set_near :: proc "contextless" (
    self: Camera_Attributes_Physical,
    near_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_near", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    near_ := near_
    args := []__bindgen_gde.TypePtr {
        &near_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera_attributes_physical_get_near :: proc "contextless" (
    self: Camera_Attributes_Physical,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_near", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_attributes_physical_set_far :: proc "contextless" (
    self: Camera_Attributes_Physical,
    far_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_far", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    far_ := far_
    args := []__bindgen_gde.TypePtr {
        &far_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera_attributes_physical_get_far :: proc "contextless" (
    self: Camera_Attributes_Physical,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_far", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_attributes_physical_get_fov :: proc "contextless" (
    self: Camera_Attributes_Physical,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fov", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_attributes_physical_set_auto_exposure_max_exposure_value :: proc "contextless" (
    self: Camera_Attributes_Physical,
    exposure_value_max_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_exposure_max_exposure_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    exposure_value_max_ := exposure_value_max_
    args := []__bindgen_gde.TypePtr {
        &exposure_value_max_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera_attributes_physical_get_auto_exposure_max_exposure_value :: proc "contextless" (
    self: Camera_Attributes_Physical,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_auto_exposure_max_exposure_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

camera_attributes_physical_set_auto_exposure_min_exposure_value :: proc "contextless" (
    self: Camera_Attributes_Physical,
    exposure_value_min_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_auto_exposure_min_exposure_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    exposure_value_min_ := exposure_value_min_
    args := []__bindgen_gde.TypePtr {
        &exposure_value_min_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

camera_attributes_physical_get_auto_exposure_min_exposure_value :: proc "contextless" (
    self: Camera_Attributes_Physical,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_auto_exposure_min_exposure_value", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
camera_attributes_physical_get_frustum_focus_distance :: proc "contextless" (self: Camera_Attributes_Physical) -> f64 {
    return camera_attributes_physical_get_focus_distance(self)
}
camera_attributes_physical_set_frustum_focus_distance :: proc "contextless" (self: Camera_Attributes_Physical, value: f64) {
    camera_attributes_physical_set_focus_distance(self, value)
}
camera_attributes_physical_get_frustum_focal_length :: proc "contextless" (self: Camera_Attributes_Physical) -> f64 {
    return camera_attributes_physical_get_focal_length(self)
}
camera_attributes_physical_set_frustum_focal_length :: proc "contextless" (self: Camera_Attributes_Physical, value: f64) {
    camera_attributes_physical_set_focal_length(self, value)
}
camera_attributes_physical_get_frustum_near :: proc "contextless" (self: Camera_Attributes_Physical) -> f64 {
    return camera_attributes_physical_get_near(self)
}
camera_attributes_physical_set_frustum_near :: proc "contextless" (self: Camera_Attributes_Physical, value: f64) {
    camera_attributes_physical_set_near(self, value)
}
camera_attributes_physical_get_frustum_far :: proc "contextless" (self: Camera_Attributes_Physical) -> f64 {
    return camera_attributes_physical_get_far(self)
}
camera_attributes_physical_set_frustum_far :: proc "contextless" (self: Camera_Attributes_Physical, value: f64) {
    camera_attributes_physical_set_far(self, value)
}
camera_attributes_physical_get_exposure_aperture :: proc "contextless" (self: Camera_Attributes_Physical) -> f64 {
    return camera_attributes_physical_get_aperture(self)
}
camera_attributes_physical_set_exposure_aperture :: proc "contextless" (self: Camera_Attributes_Physical, value: f64) {
    camera_attributes_physical_set_aperture(self, value)
}
camera_attributes_physical_get_exposure_shutter_speed :: proc "contextless" (self: Camera_Attributes_Physical) -> f64 {
    return camera_attributes_physical_get_shutter_speed(self)
}
camera_attributes_physical_set_exposure_shutter_speed :: proc "contextless" (self: Camera_Attributes_Physical, value: f64) {
    camera_attributes_physical_set_shutter_speed(self, value)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
camera_attributes_physical_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("CameraAttributesPhysical", true)
}

@(private = "file")
__class_name: String_Name