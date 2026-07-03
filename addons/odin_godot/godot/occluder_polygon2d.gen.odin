package godot

import __bindgen_gde "godot:gdext"

Occluder_Polygon2d_Constants :: enum {
}
Occluder_Polygon2d_Cull_Mode :: enum int {
    Cull_Disabled = 0,
    Cull_Clockwise = 1,
    Cull_Counter_Clockwise = 2,
}



occluder_polygon2d_name_ref :: proc "contextless" () -> ^String_Name {
    return &__class_name
}

occluder_polygon2d_name :: proc "contextless" () -> String_Name {
    return __class_name
}

new_occluder_polygon2d :: proc "contextless" () -> Occluder_Polygon2d {
    return cast(Occluder_Polygon2d)__bindgen_gde.classdb_construct_object(occluder_polygon2d_name_ref())
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

occluder_polygon2d_set_closed :: proc "contextless" (
    self: Occluder_Polygon2d,
    closed_: Bool,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_closed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2586408642)
    }
    self := self
    closed_ := closed_
    args := []__bindgen_gde.TypePtr {
        &closed_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

occluder_polygon2d_is_closed :: proc "contextless" (
    self: Occluder_Polygon2d,
) -> (ret: Bool) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("is_closed", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 36873697)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

occluder_polygon2d_set_cull_mode :: proc "contextless" (
    self: Occluder_Polygon2d,
    cull_mode_: Occluder_Polygon2d_Cull_Mode,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_cull_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 3500863002)
    }
    self := self
    cull_mode_ := cull_mode_
    args := []__bindgen_gde.TypePtr {
        &cull_mode_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

occluder_polygon2d_get_cull_mode :: proc "contextless" (
    self: Occluder_Polygon2d,
) -> (ret: Occluder_Polygon2d_Cull_Mode) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_cull_mode", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 33931036)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}

occluder_polygon2d_set_polygon :: proc "contextless" (
    self: Occluder_Polygon2d,
    polygon_: Packed_Vector2_Array,
) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("set_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 1509147220)
    }
    self := self
    polygon_ := polygon_
    args := []__bindgen_gde.TypePtr {
        &polygon_,
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), nil)
}

occluder_polygon2d_get_polygon :: proc "contextless" (
    self: Occluder_Polygon2d,
) -> (ret: Packed_Vector2_Array) {
    @(static) __ptr: __bindgen_gde.MethodBindPtr
    if __ptr == nil {
        _gde_name := new_string_name_cstring("get_polygon", true)
        __ptr = __bindgen_gde.classdb_get_method_bind(&__class_name, &_gde_name, 2961356807)
    }
    self := self
    args := []__bindgen_gde.TypePtr {
    }
    __bindgen_gde.object_method_bind_ptrcall(__ptr, self, raw_data(args), &ret)
    return
}


// properties
occluder_polygon2d_get_closed :: proc "contextless" (self: Occluder_Polygon2d) -> Bool {
    return occluder_polygon2d_is_closed(self)
}

// Only interns the class StringName (used for object construction and as the
// class argument when methods lazily resolve their binds). Method binds are NOT
// fetched here -- see the note above the methods section.
occluder_polygon2d_init :: proc "contextless" () {
    __class_name = new_string_name_cstring("OccluderPolygon2D", true)
}

@(private = "file")
__class_name: String_Name