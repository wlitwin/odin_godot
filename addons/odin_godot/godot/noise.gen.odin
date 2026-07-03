package godot

import __bindgen_gde "godot:gdext"

Noise_Constants :: enum {
}



noise_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

noise_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_noise :: proc "contextless" () -> Noise {
    return cast(Noise)__bindgen_gde.classdb_construct_object(noise_name_ref())
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

noise_get_noise_1d :: proc "contextless" (
    self: Noise,
    x_: f64,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_noise_1d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3919130443)
    }
    self := self
    x_ := x_
    args := []__bindgen_gde.TypePtr {
        &x_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

noise_get_noise_2d :: proc "contextless" (
    self: Noise,
    x_: f64,
    y_: f64,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_noise_2d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2753205203)
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

noise_get_noise_2dv :: proc "contextless" (
    self: Noise,
    v_: Vector2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_noise_2dv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2276447920)
    }
    self := self
    v_ := v_
    args := []__bindgen_gde.TypePtr {
        &v_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

noise_get_noise_3d :: proc "contextless" (
    self: Noise,
    x_: f64,
    y_: f64,
    z_: f64,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_noise_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 973811851)
    }
    self := self
    x_ := x_
    y_ := y_
    z_ := z_
    args := []__bindgen_gde.TypePtr {
        &x_,
        &y_,
        &z_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

noise_get_noise_3dv :: proc "contextless" (
    self: Noise,
    v_: Vector3,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_noise_3dv", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1109078154)
    }
    self := self
    v_ := v_
    args := []__bindgen_gde.TypePtr {
        &v_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

noise_get_image :: proc "contextless" (
    self: Noise,
    width_: Int,
    height_: Int,
    invert_: Bool,
    in_3d_space_: Bool,
    normalize_: Bool,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_image", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3180683109)
    }
    self := self
    width_ := width_
    height_ := height_
    invert_ := invert_
    in_3d_space_ := in_3d_space_
    normalize_ := normalize_
    args := []__bindgen_gde.TypePtr {
        &width_,
        &height_,
        &invert_,
        &in_3d_space_,
        &normalize_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

noise_get_seamless_image :: proc "contextless" (
    self: Noise,
    width_: Int,
    height_: Int,
    invert_: Bool,
    in_3d_space_: Bool,
    skirt_: f64,
    normalize_: Bool,
) -> (ret: Image) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_seamless_image", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2770743602)
    }
    self := self
    width_ := width_
    height_ := height_
    invert_ := invert_
    in_3d_space_ := in_3d_space_
    skirt_ := skirt_
    normalize_ := normalize_
    args := []__bindgen_gde.TypePtr {
        &width_,
        &height_,
        &invert_,
        &in_3d_space_,
        &skirt_,
        &normalize_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

noise_get_image_3d :: proc "contextless" (
    self: Noise,
    width_: Int,
    height_: Int,
    depth_: Int,
    invert_: Bool,
    normalize_: Bool,
) -> (ret: Typed_Array(Image)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_image_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3977814329)
    }
    self := self
    width_ := width_
    height_ := height_
    depth_ := depth_
    invert_ := invert_
    normalize_ := normalize_
    args := []__bindgen_gde.TypePtr {
        &width_,
        &height_,
        &depth_,
        &invert_,
        &normalize_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

noise_get_seamless_image_3d :: proc "contextless" (
    self: Noise,
    width_: Int,
    height_: Int,
    depth_: Int,
    invert_: Bool,
    skirt_: f64,
    normalize_: Bool,
) -> (ret: Typed_Array(Image)) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_seamless_image_3d", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 451006340)
    }
    self := self
    width_ := width_
    height_ := height_
    depth_ := depth_
    invert_ := invert_
    skirt_ := skirt_
    normalize_ := normalize_
    args := []__bindgen_gde.TypePtr {
        &width_,
        &height_,
        &depth_,
        &invert_,
        &skirt_,
        &normalize_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
noise_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Noise", true)
}

@(private = "file")
__class_name: String_Name