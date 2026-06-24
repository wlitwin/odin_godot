package godot

import __bindgen_gde "godot:gdext"

Fast_Noise_Lite_Constants :: enum {
}
Fast_Noise_Lite_Noise_Type :: enum int {
    Type_Value = 5,
    Type_Value_Cubic = 4,
    Type_Perlin = 3,
    Type_Cellular = 2,
    Type_Simplex = 0,
    Type_Simplex_Smooth = 1,
}
Fast_Noise_Lite_Fractal_Type :: enum int {
    Fractal_None = 0,
    Fractal_Fbm = 1,
    Fractal_Ridged = 2,
    Fractal_Ping_Pong = 3,
}
Fast_Noise_Lite_Cellular_Distance_Function :: enum int {
    Distance_Euclidean = 0,
    Distance_Euclidean_Squared = 1,
    Distance_Manhattan = 2,
    Distance_Hybrid = 3,
}
Fast_Noise_Lite_Cellular_Return_Type :: enum int {
    Return_Cell_Value = 0,
    Return_Distance = 1,
    Return_Distance2 = 2,
    Return_Distance2_Add = 3,
    Return_Distance2_Sub = 4,
    Return_Distance2_Mul = 5,
    Return_Distance2_Div = 6,
}
Fast_Noise_Lite_Domain_Warp_Type :: enum int {
    Domain_Warp_Simplex = 0,
    Domain_Warp_Simplex_Reduced = 1,
    Domain_Warp_Basic_Grid = 2,
}
Fast_Noise_Lite_Domain_Warp_Fractal_Type :: enum int {
    Domain_Warp_Fractal_None = 0,
    Domain_Warp_Fractal_Progressive = 1,
    Domain_Warp_Fractal_Independent = 2,
}



fast_noise_lite_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

fast_noise_lite_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_fast_noise_lite :: proc "contextless" () -> Fast_Noise_Lite {
    return cast(Fast_Noise_Lite)__bindgen_gde.classdb_construct_object(fast_noise_lite_name_ref())
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

fast_noise_lite_set_noise_type :: proc "contextless" (
    self: Fast_Noise_Lite,
    type_: Fast_Noise_Lite_Noise_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_noise_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2624461392)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_noise_type :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: Fast_Noise_Lite_Noise_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_noise_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1458108610)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_seed :: proc "contextless" (
    self: Fast_Noise_Lite,
    seed_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_seed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    seed_ := seed_
    args := []__bindgen_gde.TypePtr {
        &seed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_seed :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_seed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_frequency :: proc "contextless" (
    self: Fast_Noise_Lite,
    freq_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_frequency", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    freq_ := freq_
    args := []__bindgen_gde.TypePtr {
        &freq_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_frequency :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_frequency", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_offset :: proc "contextless" (
    self: Fast_Noise_Lite,
    offset_: Vector3,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3460891852)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_offset :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: Vector3) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3360562783)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_fractal_type :: proc "contextless" (
    self: Fast_Noise_Lite,
    type_: Fast_Noise_Lite_Fractal_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fractal_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4132731174)
    }
    self := self
    type_ := type_
    args := []__bindgen_gde.TypePtr {
        &type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_fractal_type :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: Fast_Noise_Lite_Fractal_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fractal_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1036889279)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_fractal_octaves :: proc "contextless" (
    self: Fast_Noise_Lite,
    octave_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fractal_octaves", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    octave_count_ := octave_count_
    args := []__bindgen_gde.TypePtr {
        &octave_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_fractal_octaves :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fractal_octaves", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_fractal_lacunarity :: proc "contextless" (
    self: Fast_Noise_Lite,
    lacunarity_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fractal_lacunarity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    lacunarity_ := lacunarity_
    args := []__bindgen_gde.TypePtr {
        &lacunarity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_fractal_lacunarity :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fractal_lacunarity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_fractal_gain :: proc "contextless" (
    self: Fast_Noise_Lite,
    gain_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fractal_gain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    gain_ := gain_
    args := []__bindgen_gde.TypePtr {
        &gain_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_fractal_gain :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fractal_gain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_fractal_weighted_strength :: proc "contextless" (
    self: Fast_Noise_Lite,
    weighted_strength_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fractal_weighted_strength", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    weighted_strength_ := weighted_strength_
    args := []__bindgen_gde.TypePtr {
        &weighted_strength_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_fractal_weighted_strength :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fractal_weighted_strength", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_fractal_ping_pong_strength :: proc "contextless" (
    self: Fast_Noise_Lite,
    ping_pong_strength_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fractal_ping_pong_strength", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    ping_pong_strength_ := ping_pong_strength_
    args := []__bindgen_gde.TypePtr {
        &ping_pong_strength_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_fractal_ping_pong_strength :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fractal_ping_pong_strength", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_cellular_distance_function :: proc "contextless" (
    self: Fast_Noise_Lite,
    func_: Fast_Noise_Lite_Cellular_Distance_Function,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cellular_distance_function", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1006013267)
    }
    self := self
    func_ := func_
    args := []__bindgen_gde.TypePtr {
        &func_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_cellular_distance_function :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: Fast_Noise_Lite_Cellular_Distance_Function) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cellular_distance_function", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2021274088)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_cellular_jitter :: proc "contextless" (
    self: Fast_Noise_Lite,
    jitter_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cellular_jitter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    jitter_ := jitter_
    args := []__bindgen_gde.TypePtr {
        &jitter_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_cellular_jitter :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cellular_jitter", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_cellular_return_type :: proc "contextless" (
    self: Fast_Noise_Lite,
    ret_: Fast_Noise_Lite_Cellular_Return_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cellular_return_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2654169698)
    }
    self := self
    ret_ := ret_
    args := []__bindgen_gde.TypePtr {
        &ret_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_cellular_return_type :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: Fast_Noise_Lite_Cellular_Return_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cellular_return_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3699796343)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_domain_warp_enabled :: proc "contextless" (
    self: Fast_Noise_Lite,
    domain_warp_enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_domain_warp_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    domain_warp_enabled_ := domain_warp_enabled_
    args := []__bindgen_gde.TypePtr {
        &domain_warp_enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_is_domain_warp_enabled :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_domain_warp_enabled", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_domain_warp_type :: proc "contextless" (
    self: Fast_Noise_Lite,
    domain_warp_type_: Fast_Noise_Lite_Domain_Warp_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_domain_warp_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3629692980)
    }
    self := self
    domain_warp_type_ := domain_warp_type_
    args := []__bindgen_gde.TypePtr {
        &domain_warp_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_domain_warp_type :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: Fast_Noise_Lite_Domain_Warp_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_domain_warp_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2980162020)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_domain_warp_amplitude :: proc "contextless" (
    self: Fast_Noise_Lite,
    domain_warp_amplitude_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_domain_warp_amplitude", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    domain_warp_amplitude_ := domain_warp_amplitude_
    args := []__bindgen_gde.TypePtr {
        &domain_warp_amplitude_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_domain_warp_amplitude :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_domain_warp_amplitude", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_domain_warp_frequency :: proc "contextless" (
    self: Fast_Noise_Lite,
    domain_warp_frequency_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_domain_warp_frequency", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    domain_warp_frequency_ := domain_warp_frequency_
    args := []__bindgen_gde.TypePtr {
        &domain_warp_frequency_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_domain_warp_frequency :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_domain_warp_frequency", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_domain_warp_fractal_type :: proc "contextless" (
    self: Fast_Noise_Lite,
    domain_warp_fractal_type_: Fast_Noise_Lite_Domain_Warp_Fractal_Type,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_domain_warp_fractal_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3999408287)
    }
    self := self
    domain_warp_fractal_type_ := domain_warp_fractal_type_
    args := []__bindgen_gde.TypePtr {
        &domain_warp_fractal_type_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_domain_warp_fractal_type :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: Fast_Noise_Lite_Domain_Warp_Fractal_Type) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_domain_warp_fractal_type", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 407716934)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_domain_warp_fractal_octaves :: proc "contextless" (
    self: Fast_Noise_Lite,
    domain_warp_octave_count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_domain_warp_fractal_octaves", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    domain_warp_octave_count_ := domain_warp_octave_count_
    args := []__bindgen_gde.TypePtr {
        &domain_warp_octave_count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_domain_warp_fractal_octaves :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_domain_warp_fractal_octaves", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_domain_warp_fractal_lacunarity :: proc "contextless" (
    self: Fast_Noise_Lite,
    domain_warp_lacunarity_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_domain_warp_fractal_lacunarity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    domain_warp_lacunarity_ := domain_warp_lacunarity_
    args := []__bindgen_gde.TypePtr {
        &domain_warp_lacunarity_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_domain_warp_fractal_lacunarity :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_domain_warp_fractal_lacunarity", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

fast_noise_lite_set_domain_warp_fractal_gain :: proc "contextless" (
    self: Fast_Noise_Lite,
    domain_warp_gain_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_domain_warp_fractal_gain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    domain_warp_gain_ := domain_warp_gain_
    args := []__bindgen_gde.TypePtr {
        &domain_warp_gain_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

fast_noise_lite_get_domain_warp_fractal_gain :: proc "contextless" (
    self: Fast_Noise_Lite,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_domain_warp_fractal_gain", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
fast_noise_lite_get_domain_warp_enabled :: proc "contextless" (self: Fast_Noise_Lite) -> Bool {
    return fast_noise_lite_is_domain_warp_enabled(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
fast_noise_lite_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("FastNoiseLite", true)
}

@(private = "file")
__class_name: String_Name