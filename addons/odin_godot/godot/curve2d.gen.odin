package godot

import __bindgen_gde "godot:gdext"

Curve2d_Constants :: enum {
}



curve2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

curve2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_curve2d :: proc "contextless" () -> Curve2d {
    return cast(Curve2d)__bindgen_gde.classdb_construct_object(curve2d_name_ref())
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

curve2d_get_point_count :: proc "contextless" (
    self: Curve2d,
) -> (ret: i32) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3905245786)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_set_point_count :: proc "contextless" (
    self: Curve2d,
    count_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_point_count", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    count_ := count_
    args := []__bindgen_gde.TypePtr {
        &count_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

curve2d_add_point :: proc "contextless" (
    self: Curve2d,
    position_: Vector2,
    in_: Vector2,
    out_: Vector2,
    index_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("add_point", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 4175465202)
    }
    self := self
    position_ := position_
    in_ := in_
    out_ := out_
    index_ := index_
    args := []__bindgen_gde.TypePtr {
        &position_,
        &in_,
        &out_,
        &index_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

curve2d_set_point_position :: proc "contextless" (
    self: Curve2d,
    idx_: Int,
    position_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_point_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 163021252)
    }
    self := self
    idx_ := idx_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

curve2d_get_point_position :: proc "contextless" (
    self: Curve2d,
    idx_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2299179447)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_set_point_in :: proc "contextless" (
    self: Curve2d,
    idx_: Int,
    position_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_point_in", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 163021252)
    }
    self := self
    idx_ := idx_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

curve2d_get_point_in :: proc "contextless" (
    self: Curve2d,
    idx_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_in", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2299179447)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_set_point_out :: proc "contextless" (
    self: Curve2d,
    idx_: Int,
    position_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_point_out", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 163021252)
    }
    self := self
    idx_ := idx_
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

curve2d_get_point_out :: proc "contextless" (
    self: Curve2d,
    idx_: Int,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_point_out", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2299179447)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_remove_point :: proc "contextless" (
    self: Curve2d,
    idx_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("remove_point", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    idx_ := idx_
    args := []__bindgen_gde.TypePtr {
        &idx_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

curve2d_clear_points :: proc "contextless" (
    self: Curve2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("clear_points", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3218959716)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

curve2d_sample :: proc "contextless" (
    self: Curve2d,
    idx_: Int,
    t_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sample", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 26514310)
    }
    self := self
    idx_ := idx_
    t_ := t_
    args := []__bindgen_gde.TypePtr {
        &idx_,
        &t_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_samplef :: proc "contextless" (
    self: Curve2d,
    fofs_: f64,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("samplef", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3588506812)
    }
    self := self
    fofs_ := fofs_
    args := []__bindgen_gde.TypePtr {
        &fofs_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_set_bake_interval :: proc "contextless" (
    self: Curve2d,
    distance_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_bake_interval", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    distance_ := distance_
    args := []__bindgen_gde.TypePtr {
        &distance_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

curve2d_get_bake_interval :: proc "contextless" (
    self: Curve2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_bake_interval", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_get_baked_length :: proc "contextless" (
    self: Curve2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_baked_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_sample_baked :: proc "contextless" (
    self: Curve2d,
    offset_: f64,
    cubic_: Bool,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sample_baked", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3464257706)
    }
    self := self
    offset_ := offset_
    cubic_ := cubic_
    args := []__bindgen_gde.TypePtr {
        &offset_,
        &cubic_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_sample_baked_with_rotation :: proc "contextless" (
    self: Curve2d,
    offset_: f64,
    cubic_: Bool,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("sample_baked_with_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3296056341)
    }
    self := self
    offset_ := offset_
    cubic_ := cubic_
    args := []__bindgen_gde.TypePtr {
        &offset_,
        &cubic_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_get_baked_points :: proc "contextless" (
    self: Curve2d,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_baked_points", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2961356807)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_get_closest_point :: proc "contextless" (
    self: Curve2d,
    to_point_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_closest_point", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2656412154)
    }
    self := self
    to_point_ := to_point_
    args := []__bindgen_gde.TypePtr {
        &to_point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_get_closest_offset :: proc "contextless" (
    self: Curve2d,
    to_point_: Vector2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_closest_offset", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2276447920)
    }
    self := self
    to_point_ := to_point_
    args := []__bindgen_gde.TypePtr {
        &to_point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_tessellate :: proc "contextless" (
    self: Curve2d,
    max_stages_: Int,
    tolerance_degrees_: f64,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tessellate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 958145977)
    }
    self := self
    max_stages_ := max_stages_
    tolerance_degrees_ := tolerance_degrees_
    args := []__bindgen_gde.TypePtr {
        &max_stages_,
        &tolerance_degrees_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

curve2d_tessellate_even_length :: proc "contextless" (
    self: Curve2d,
    max_stages_: Int,
    tolerance_length_: f64,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("tessellate_even_length", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2319761637)
    }
    self := self
    max_stages_ := max_stages_
    tolerance_length_ := tolerance_length_
    args := []__bindgen_gde.TypePtr {
        &max_stages_,
        &tolerance_length_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
curve2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Curve2D", true)
}

@(private = "file")
__class_name: String_Name