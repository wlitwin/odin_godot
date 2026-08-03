package godot

import __bindgen_gde "godot:gdext"

Node2d_Constants :: enum {
}



node2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

node2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_node2d :: proc "contextless" () -> Node2d {
    return cast(Node2d)__bindgen_gde.classdb_construct_object(node2d_name_ref())
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

node2d_set_position :: proc "contextless" (
    self: Node2d,
    position_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_set_rotation :: proc "contextless" (
    self: Node2d,
    radians_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    radians_ := radians_
    args := []__bindgen_gde.TypePtr {
        &radians_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_set_rotation_degrees :: proc "contextless" (
    self: Node2d,
    degrees_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_rotation_degrees", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    degrees_ := degrees_
    args := []__bindgen_gde.TypePtr {
        &degrees_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_set_skew :: proc "contextless" (
    self: Node2d,
    radians_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_skew", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    radians_ := radians_
    args := []__bindgen_gde.TypePtr {
        &radians_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_set_scale :: proc "contextless" (
    self: Node2d,
    scale_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_get_position :: proc "contextless" (
    self: Node2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node2d_get_rotation :: proc "contextless" (
    self: Node2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node2d_get_rotation_degrees :: proc "contextless" (
    self: Node2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_rotation_degrees", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node2d_get_skew :: proc "contextless" (
    self: Node2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_skew", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node2d_get_scale :: proc "contextless" (
    self: Node2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node2d_rotate :: proc "contextless" (
    self: Node2d,
    radians_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("rotate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    radians_ := radians_
    args := []__bindgen_gde.TypePtr {
        &radians_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_move_local_x :: proc "contextless" (
    self: Node2d,
    delta_: f64,
    scaled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_local_x", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2087892650)
    }
    self := self
    delta_ := delta_
    scaled_ := scaled_
    args := []__bindgen_gde.TypePtr {
        &delta_,
        &scaled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_move_local_y :: proc "contextless" (
    self: Node2d,
    delta_: f64,
    scaled_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("move_local_y", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2087892650)
    }
    self := self
    delta_ := delta_
    scaled_ := scaled_
    args := []__bindgen_gde.TypePtr {
        &delta_,
        &scaled_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_translate :: proc "contextless" (
    self: Node2d,
    offset_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("translate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_global_translate :: proc "contextless" (
    self: Node2d,
    offset_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("global_translate", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    offset_ := offset_
    args := []__bindgen_gde.TypePtr {
        &offset_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_apply_scale :: proc "contextless" (
    self: Node2d,
    ratio_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("apply_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    ratio_ := ratio_
    args := []__bindgen_gde.TypePtr {
        &ratio_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_set_global_position :: proc "contextless" (
    self: Node2d,
    position_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_global_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    position_ := position_
    args := []__bindgen_gde.TypePtr {
        &position_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_get_global_position :: proc "contextless" (
    self: Node2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_position", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node2d_set_global_rotation :: proc "contextless" (
    self: Node2d,
    radians_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_global_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    radians_ := radians_
    args := []__bindgen_gde.TypePtr {
        &radians_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_set_global_rotation_degrees :: proc "contextless" (
    self: Node2d,
    degrees_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_global_rotation_degrees", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    degrees_ := degrees_
    args := []__bindgen_gde.TypePtr {
        &degrees_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_get_global_rotation :: proc "contextless" (
    self: Node2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_rotation", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node2d_get_global_rotation_degrees :: proc "contextless" (
    self: Node2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_rotation_degrees", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node2d_set_global_skew :: proc "contextless" (
    self: Node2d,
    radians_: f64,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_global_skew", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 373806689)
    }
    self := self
    radians_ := radians_
    args := []__bindgen_gde.TypePtr {
        &radians_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_get_global_skew :: proc "contextless" (
    self: Node2d,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_skew", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1740695150)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node2d_set_global_scale :: proc "contextless" (
    self: Node2d,
    scale_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_global_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    scale_ := scale_
    args := []__bindgen_gde.TypePtr {
        &scale_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_get_global_scale :: proc "contextless" (
    self: Node2d,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_global_scale", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3341600327)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node2d_set_transform :: proc "contextless" (
    self: Node2d,
    xform_: Transform2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2761652528)
    }
    self := self
    xform_ := xform_
    args := []__bindgen_gde.TypePtr {
        &xform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_set_global_transform :: proc "contextless" (
    self: Node2d,
    xform_: Transform2d,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_global_transform", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2761652528)
    }
    self := self
    xform_ := xform_
    args := []__bindgen_gde.TypePtr {
        &xform_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_look_at :: proc "contextless" (
    self: Node2d,
    point_: Vector2,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("look_at", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 743155724)
    }
    self := self
    point_ := point_
    args := []__bindgen_gde.TypePtr {
        &point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

node2d_get_angle_to :: proc "contextless" (
    self: Node2d,
    point_: Vector2,
) -> (ret: f64) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_angle_to", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2276447920)
    }
    self := self
    point_ := point_
    args := []__bindgen_gde.TypePtr {
        &point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node2d_to_local :: proc "contextless" (
    self: Node2d,
    global_point_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_local", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2656412154)
    }
    self := self
    global_point_ := global_point_
    args := []__bindgen_gde.TypePtr {
        &global_point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node2d_to_global :: proc "contextless" (
    self: Node2d,
    local_point_: Vector2,
) -> (ret: Vector2) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("to_global", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2656412154)
    }
    self := self
    local_point_ := local_point_
    args := []__bindgen_gde.TypePtr {
        &local_point_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

node2d_get_relative_transform_to_parent :: proc "contextless" (
    self: Node2d,
    parent_: Node,
) -> (ret: Transform2d) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_relative_transform_to_parent", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 904556875)
    }
    self := self
    parent_ := parent_
    args := []__bindgen_gde.TypePtr {
        &parent_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
node2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("Node2D", true)
}

@(private = "file")
__class_name: String_Name