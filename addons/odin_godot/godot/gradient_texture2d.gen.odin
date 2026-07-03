package godot

import __bindgen_gde "godot:gdext"

Gradient_Texture2d_Constants :: enum {
}
Gradient_Texture2d_Fill :: enum int {
    Fill_Linear = 0,
    Fill_Radial = 1,
    Fill_Square = 2,
}
Gradient_Texture2d_Repeat :: enum int {
    Repeat_None = 0,
    Repeat = 1,
    Repeat_Mirror = 2,
}



gradient_texture2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

gradient_texture2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_gradient_texture2d :: proc "contextless" () -> Gradient_Texture2d {
    return cast(Gradient_Texture2d)__bindgen_gde.classdb_construct_object(gradient_texture2d_name_ref())
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

gradient_texture2d_set_gradient :: proc "contextless" (
    self: Gradient_Texture2d,
    gradient_: Gradient,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_gradient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2756054477)
    }
    self := self
    gradient_ := gradient_
    args := []__bindgen_gde.TypePtr {
        &gradient_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gradient_texture2d_get_gradient :: proc "contextless" (
    self: Gradient_Texture2d,
) -> (ret: Gradient) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_gradient", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 132272999)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gradient_texture2d_set_width :: proc "contextless" (
    self: Gradient_Texture2d,
    width_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_width", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    width_ := width_
    args := []__bindgen_gde.TypePtr {
        &width_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gradient_texture2d_set_height :: proc "contextless" (
    self: Gradient_Texture2d,
    height_: Int,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_height", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1286410249)
    }
    self := self
    height_ := height_
    args := []__bindgen_gde.TypePtr {
        &height_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gradient_texture2d_set_use_hdr :: proc "contextless" (
    self: Gradient_Texture2d,
    enabled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_use_hdr", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    enabled_ := enabled_
    args := []__bindgen_gde.TypePtr {
        &enabled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gradient_texture2d_is_using_hdr :: proc "contextless" (
    self: Gradient_Texture2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_using_hdr", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gradient_texture2d_set_fill :: proc "contextless" (
    self: Gradient_Texture2d,
    fill_: Gradient_Texture2d_Fill,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fill", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3623927636)
    }
    self := self
    fill_ := fill_
    args := []__bindgen_gde.TypePtr {
        &fill_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gradient_texture2d_get_fill :: proc "contextless" (
    self: Gradient_Texture2d,
) -> (ret: Gradient_Texture2d_Fill) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fill", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1876227217)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gradient_texture2d_set_fill_from :: proc "contextless" (
    self: Gradient_Texture2d,
    fill_from_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fill_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    fill_from_ := fill_from_
    args := []__bindgen_gde.TypePtr {
        &fill_from_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gradient_texture2d_get_fill_from :: proc "contextless" (
    self: Gradient_Texture2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fill_from", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gradient_texture2d_set_fill_to :: proc "contextless" (
    self: Gradient_Texture2d,
    fill_to_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_fill_to", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    fill_to_ := fill_to_
    args := []__bindgen_gde.TypePtr {
        &fill_to_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gradient_texture2d_get_fill_to :: proc "contextless" (
    self: Gradient_Texture2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_fill_to", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

gradient_texture2d_set_repeat :: proc "contextless" (
    self: Gradient_Texture2d,
    repeat_: Gradient_Texture2d_Repeat,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_repeat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1357597002)
    }
    self := self
    repeat_ := repeat_
    args := []__bindgen_gde.TypePtr {
        &repeat_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

gradient_texture2d_get_repeat :: proc "contextless" (
    self: Gradient_Texture2d,
) -> (ret: Gradient_Texture2d_Repeat) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_repeat", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3351758665)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
gradient_texture2d_get_use_hdr :: proc "contextless" (self: Gradient_Texture2d) -> Bool {
    return gradient_texture2d_is_using_hdr(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
gradient_texture2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("GradientTexture2D", true)
}

@(private = "file")
__class_name: String_Name