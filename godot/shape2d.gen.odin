package godot

import __bindgen_gde "godot:gdext"

Shape2d_Constants :: enum {
}



shape2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

shape2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_shape2d :: proc "contextless" () -> Shape2d {
    return cast(Shape2d)__bindgen_gde.classdb_construct_object(shape2d_name_ref())
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

shape2d_set_custom_solver_bias :: proc "contextless" (
    self: Shape2d,
    bias_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_custom_solver_bias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    bias_ := bias_
    args := []__bindgen_gde.TypePtr {
        &bias_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

shape2d_get_custom_solver_bias :: proc "contextless" (
    self: Shape2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_custom_solver_bias", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

shape2d_collide :: proc "contextless" (
    self: Shape2d,
    local_xform_: Transform2d,
    with_shape_: Shape2d,
    shape_xform_: Transform2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("collide", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3709843132)
    }
    self := self
    local_xform_ := local_xform_
    with_shape_ := with_shape_
    shape_xform_ := shape_xform_
    args := []__bindgen_gde.TypePtr {
        &local_xform_,
        &with_shape_,
        &shape_xform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

shape2d_collide_with_motion :: proc "contextless" (
    self: Shape2d,
    local_xform_: Transform2d,
    local_motion_: Vector2,
    with_shape_: Shape2d,
    shape_xform_: Transform2d,
    shape_motion_: Vector2,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("collide_with_motion", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2869556801)
    }
    self := self
    local_xform_ := local_xform_
    local_motion_ := local_motion_
    with_shape_ := with_shape_
    shape_xform_ := shape_xform_
    shape_motion_ := shape_motion_
    args := []__bindgen_gde.TypePtr {
        &local_xform_,
        &local_motion_,
        &with_shape_,
        &shape_xform_,
        &shape_motion_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

shape2d_collide_and_get_contacts :: proc "contextless" (
    self: Shape2d,
    local_xform_: Transform2d,
    with_shape_: Shape2d,
    shape_xform_: Transform2d,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("collide_and_get_contacts", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3056932662)
    }
    self := self
    local_xform_ := local_xform_
    with_shape_ := with_shape_
    shape_xform_ := shape_xform_
    args := []__bindgen_gde.TypePtr {
        &local_xform_,
        &with_shape_,
        &shape_xform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

shape2d_collide_with_motion_and_get_contacts :: proc "contextless" (
    self: Shape2d,
    local_xform_: Transform2d,
    local_motion_: Vector2,
    with_shape_: Shape2d,
    shape_xform_: Transform2d,
    shape_motion_: Vector2,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("collide_with_motion_and_get_contacts", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3620351573)
    }
    self := self
    local_xform_ := local_xform_
    local_motion_ := local_motion_
    with_shape_ := with_shape_
    shape_xform_ := shape_xform_
    shape_motion_ := shape_motion_
    args := []__bindgen_gde.TypePtr {
        &local_xform_,
        &local_motion_,
        &with_shape_,
        &shape_xform_,
        &shape_motion_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

shape2d_draw :: proc "contextless" (
    self: Shape2d,
    canvas_item_: Rid,
    color_: Color,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("draw", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2948539648)
    }
    self := self
    canvas_item_ := canvas_item_
    color_ := color_
    args := []__bindgen_gde.TypePtr {
        &canvas_item_,
        &color_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

shape2d_get_rect :: proc "contextless" (
    self: Shape2d,
) -> (ret: Rect2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rect", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1639390495)
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
shape2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Shape2D", true)
}

@(private = "file")
__class_name: String_Name