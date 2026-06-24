package godot

import __bindgen_gde "godot:gdext"

Aspect_Ratio_Container_Constants :: enum {
}
Aspect_Ratio_Container_Stretch_Mode :: enum int {
    Stretch_Width_Controls_Height = 0,
    Stretch_Height_Controls_Width = 1,
    Stretch_Fit = 2,
    Stretch_Cover = 3,
}
Aspect_Ratio_Container_Alignment_Mode :: enum int {
    Alignment_Begin = 0,
    Alignment_Center = 1,
    Alignment_End = 2,
}



aspect_ratio_container_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

aspect_ratio_container_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_aspect_ratio_container :: proc "contextless" () -> Aspect_Ratio_Container {
    return __bindgen_gde.classdb_construct_object(aspect_ratio_container_name_ref())
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

aspect_ratio_container_set_ratio :: proc "contextless" (
    self: Aspect_Ratio_Container,
    ratio_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    ratio_ := ratio_
    args := []__bindgen_gde.TypePtr {
        &ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

aspect_ratio_container_get_ratio :: proc "contextless" (
    self: Aspect_Ratio_Container,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_ratio", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

aspect_ratio_container_set_stretch_mode :: proc "contextless" (
    self: Aspect_Ratio_Container,
    stretch_mode_: Aspect_Ratio_Container_Stretch_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_stretch_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1876743467)
    }
    self := self
    stretch_mode_ := stretch_mode_
    args := []__bindgen_gde.TypePtr {
        &stretch_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

aspect_ratio_container_get_stretch_mode :: proc "contextless" (
    self: Aspect_Ratio_Container,
) -> (ret: Aspect_Ratio_Container_Stretch_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_stretch_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3416449033)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

aspect_ratio_container_set_alignment_horizontal :: proc "contextless" (
    self: Aspect_Ratio_Container,
    alignment_horizontal_: Aspect_Ratio_Container_Alignment_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alignment_horizontal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2147829016)
    }
    self := self
    alignment_horizontal_ := alignment_horizontal_
    args := []__bindgen_gde.TypePtr {
        &alignment_horizontal_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

aspect_ratio_container_get_alignment_horizontal :: proc "contextless" (
    self: Aspect_Ratio_Container,
) -> (ret: Aspect_Ratio_Container_Alignment_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alignment_horizontal", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3838875429)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

aspect_ratio_container_set_alignment_vertical :: proc "contextless" (
    self: Aspect_Ratio_Container,
    alignment_vertical_: Aspect_Ratio_Container_Alignment_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_alignment_vertical", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2147829016)
    }
    self := self
    alignment_vertical_ := alignment_vertical_
    args := []__bindgen_gde.TypePtr {
        &alignment_vertical_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

aspect_ratio_container_get_alignment_vertical :: proc "contextless" (
    self: Aspect_Ratio_Container,
) -> (ret: Aspect_Ratio_Container_Alignment_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_alignment_vertical", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3838875429)
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
aspect_ratio_container_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("AspectRatioContainer", true)
}

@(private = "file")
__class_name: String_Name